#==============================================================================
# Copyright (C) 2016 Stephen F. Norledge and Alces Software Ltd.
#
# This file/package is part of Alces Clusterware Dropbox.
#
# Alces Clusterware Dropbox is free software: you can redistribute it
# and/or modify it under the terms of the GNU Affero General Public
# License as published by the Free Software Foundation, either version
# 3 of the License, or (at your option) any later version.
#
# Alces Clusterware Dropbox is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied warranty
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this package.  If not, see <http://www.gnu.org/licenses/>.
#
# For more information on the Alces Clusterware Dropbox, please visit:
# https://github.com/alces-software/clusterware-dropbox
#==============================================================================
require 'time'
require 'pathname'

module Alces
  module ClusterwareDropbox
    class HandlerProxy
      def method_missing(s,*a,&b)
        if Handler.instance_methods.include?(s)
          Bundler.with_clean_env do
            Handler.new(*a, requires_token: s != :authorize).send(s)
          end
        else
          super
        end
      rescue DropboxApi::Errors::BasicError, Alces::ClusterwareDropbox::Error
        say "#{'ERROR'.underline.color(:red)}: #{$!.message}"
        exit(1)
      rescue Interrupt
        say "\n#{'WARNING'.underline.color(:yellow)}: Cancelled by user"
        exit(130)
      end
    end

    class Handler < Struct.new(:args, :options)
      def initialize(*a, requires_token: true)
        super(*a)
        assert_token if requires_token
      end

      def put
        if args.length < 1
          raise MissingArgument, "source must be specified"
        elsif File.directory?(args.first) && !options.recursive
          raise InvalidSource, "specified source was directory - try --recursive"
        elsif !File.exists?(args.first)
          raise SourceNotFound, "could not find source: #{args.first}"
        end
        target_name = args[1] || File.basename(args.first)
        target_name = "/#{target_name}" unless target_name[0] == "/"
        
        check_dropbox_file_conflict(target_name, args.first)
        dropbox_uploader(target_name, args.first)
      end

      def check_dropbox_file_conflict(tgt, src)
        if File.directory?(src)
          # pulls a complete list of target folders and files
          begin
            tgt_files_raw = ls_folder(tgt, true)
          rescue DropboxApi::Errors::NotFoundError
            tgt_files_raw = []
          end
          tgt_files = tgt_files_raw.map do |f| 
            f.to_hash["path_display"].gsub(/\A#{tgt}\/?/, "")
          end

          # Gets the list of source files and identifies conflicts
          src_files = Dir.glob("#{src}/**/*")
                         .map { |f| f.gsub(/\A#{src}\//, "") }
          conflict_set = tgt_files & src_files

          # Allows the conflict iff both the source and target are folders
          if conflict_set.length > 0
            tgt_folders = tgt_files_raw.delete_if do |f|
              !f.is_a? DropboxApi::Metadata::Folder
            end
            tgt_folders.map! do 
              |f| f.to_hash["path_display"].gsub(/\A#{tgt}\/?/, "")
            end

            # Ignores folder to folder conflicts
            conflict_set.delete_if do |c|
              ignore_conflict = true
              ignore_conflict = false unless tgt_folders.include?(c)
              ignore_conflict = false unless File.directory?(File.join(src, c))
              ignore_conflict
            end
          end
          if conflict_set.length > 0
            raise FileExists, "File(s) already in dropbox: #{conflict_set}"
          end
        else
          begin
            resolve_target(tgt, :all)
          rescue TargetNotFound
            nil
          else
            raise FileExists, "File already in dropbox: #{tgt}"
          end
        end
      end

      def dropbox_uploader(tgt, src)
        if File.directory?(src)
          src_root = Pathname.new(src)
          Dir.glob(File.join(src_root,'*')).each do |f|
            rel_src = Pathname.new(f).relative_path_from(src_root).to_s
            dropbox_uploader(File.join(tgt,rel_src), f)
          end
        else
          if File.size(src) == 0
            client.upload(tgt, File.read(src), mode: :overwrite)
            $stderr.puts "Uploading #{src}: 100%"
          else
            session_upload(tgt, src)
          end
          say "#{src} -> #{tgt}"
        end
      rescue DropboxApi::Errors::FileAncestorConflictError
        raise UploadFailed, "Part of the directory path conflicts with a file: #{tgt}"
      end

      MAX_BUFFER_SIZE = 150 * (1024 ** 2) - 1
      def session_upload(tgt, src)
        total_size = File.size(src)
        upload_size = total_size / 100
        if (total_size < 1024 ** 2) || (upload_size > MAX_BUFFER_SIZE)
          upload_size = MAX_BUFFER_SIZE
        end
        session = client.upload_session_start("").to_hash
        
        # Uploads the file
        upload_thr = Thread.new {
          File.open(src) do |f|
            while (buffer = f.read(upload_size)) do
              client.upload_session_append_v2(session, buffer)
              session["offset"] += buffer.size
            end
          end
          client.upload_session_finish(session, path: tgt, mode: :overwrite)
        }

        # Monitors the upload
        old_complete = nil
        $stderr.print "Uploading #{src}:  "
        while upload_thr.alive? do
          complete = (session["offset"].to_f / total_size * 100).round
          complete = 99 if complete > 99
          unless complete == old_complete
            $stderr.print "#{"\b" * (old_complete.to_s.length + 1)}#{complete}%"
          end 
          old_complete = complete
          sleep 0.1
        end
        $stderr.puts "#{"\b" * (old_complete.to_s.length + 1)}100%"
        upload_thr.join
      end

      def get
        target_name =
          if args[1]
            if File.directory?(args[1]) && !options.recursive
              File.join(args[1], File.basename(args.first))
            else
              args[1]
            end
          else
            File.basename(args.first)
          end

        if File.exists?(target_name)
          raise FileExists, "a local file already exists at: #{target_name}"
        end

        downloader = ->(name, tgt) do
          name = "/#{name}" unless name[0] == "/"
          remote = resolve_target(name, :link)
          if remote.file.to_hash["size"] == 0
            system("touch #{tgt}")
          elsif ! system("curl -L -s -o \"#{tgt}\" #{remote.link}")
            raise DownloadFailed, "failed to download: #{name}"
          end
          say "#{name} -> #{File.realpath(tgt)}"
        end
        
        if options.recursive
          resolve_target(args.first, :directory)
          ls_folder(args.first, true).each do |src_class|
            src = src_class.to_hash["path_display"]
            tgt = File.join(target_name, src.gsub(%r(^/#{args.first}),''))
            if src_class.is_a? DropboxApi::Metadata::Folder
              FileUtils.mkdir_p(tgt)
            else
              downloader.call(src, tgt)
            end
          end
        else
          downloader.call(args.first, target_name)
        end
      end

      def list
        files = ls_folder(args.length < 1 ? "" : args.first, false)
        files.each do |f|
          f = f.to_hash
          if f[".tag"] == "folder"
            puts sprintf("%16s %10s   %s",
                       '-',
                       'DIR',
                       f["path_display"].split('/').last)
          else
            time = DateTime.strptime(f["client_modified"],
                                     '%Y-%m-%dT%H:%M:%SZ')
            puts sprintf("%16s %10s   %s",
                       time.strftime('%Y-%m-%d %H:%M'),
                       f["size"],
                       f["path_display"].split('/').last)
          end
        end
      rescue DropboxApi::Errors::NotFoundError
        raise TargetNotFound, "Could not find folder: #{args.first}"
      end

      def ls_folder(dir, recursive_bool = false)
        dir = "/#{dir}" unless dir[0] == "/"
        dir = "" if dir == "/"
        lf = client.list_folder(dir, recursive: recursive_bool)
        list_raw = lf.entries
        while lf.has_more?
          lf = client.list_folder_continue(lf.cursor)
          list_raw.concat(lf.entries)
        end
        list_raw
      end

      def mkdir
        if args.length > 0
          folder = (args.first[0] == "/" ? args.first : "/#{args.first}")
          raise InvalidTarget.new "invalid input: root directory" if folder == "/"
          client.create_folder folder
        else
          raise MissingArgument, "no directory name supplied"
        end
        say "created bucket #{args[0]}"
      rescue DropboxApi::Errors::FolderConflictError
        raise FolderExists, "bucket already exists"
      rescue DropboxApi::Errors::FileConflictError, DropboxApi::Errors::FileAncestorConflictError
        raise InvalidTarget, "file exists with same name within bucket path"
      end

      def rmdir
        if args.length > 0
          resolve_target(args.first, :directory)
          delete_file_folder(args.first)
        else
          raise MissingArgument, "no bucket name supplied"
        end
        say "removed bucket #{args[0]}"
      rescue DropboxApi::Errors::NotFoundError
        raise TargetNotFound.new "bucket not found"
      end

      def rm
        if options.recursive
          resolve_target(args.first, :directory)
        else
          resolve_target(args.first, :file)
        end
        delete_file_folder(args.first)
        say "deleted #{args.first}"
      end

      def delete_file_folder(f)
        f = "/#{f}" unless f[0] == "/"
        raise InvalidTarget.new "Can not delete root folder" if f == "/"
        client.delete f
      end

      def authorize
        Dotenv.load(File.expand_path("#{__FILE__}/../../../../.env"))
        authenticator = DropboxApi::Authenticator.new(
                          ENV['cw_STORAGE_dropbox_appkey'],
                          ENV['cw_STORAGE_dropbox_appsecret'])
        puts "Please visit the following URL in your browser and click 'Allow':\n\n"
        puts "  #{authenticator.authorize_url}"
        print "\nEnter dropbox authorization code: "
        token = authenticator.get_token($stdin.gets.chomp).token
        if args.first
          File.write(args.first, "cw_STORAGE_dropbox_access_token=#{token}")
        else
          puts "  Your access token is: #{token}"
        end
      rescue OAuth2::Error => e
        raise Unauthorized, "account authorization failed"
      end

      def verify
        account = client.get_current_account
        puts "#{account.name.display_name} <#{account.email}> verified."
      rescue DropboxApi::Errors, OAuth2::Error
        raise Unauthorized, "authorization token is invalid or incorrect"
      end
      
      private
      def client
        @client ||= DropboxApi::Client.new(ENV['cw_STORAGE_dropbox_access_token'])
      end

      def resolve_target(name, type = :file)
        name = "/#{name}" unless name[0] == "/"
        if type == :link
          link_obj = client.get_temporary_link(name)
          unless link_obj.file.to_hash[".tag"] == "file"
            raise TargetNotFound, "#{type} not found: #{args.first}"
          end
          link_obj
        else
          md = client.get_metadata(name)
          md.to_hash.tap do |f|
            if type == :file && f[".tag"] != "file"
              raise TargetNotFound, "#{type} not found: #{args.first}"
            elsif (type == :directory || type == :folder) && f[".tag"] != "folder"
              raise TargetNotFound, "#{type} not found: #{args.first}"
            end
          md
          end
        end
      rescue DropboxApi::Errors::NotFoundError
        raise TargetNotFound, "#{type} not found: #{args.first}"
      rescue DropboxApi::Errors::NotFileError
        raise TargetNotFound, "#{args.first} not a file, try --recursive"
      end

      def assert_token
        if !ENV['cw_STORAGE_dropbox_access_token']
          raise Unauthorized, "access token (cw_STORAGE_dropbox_access_token)" \
                              " environment variable was not set"
        end
      end
    end
  end
end
