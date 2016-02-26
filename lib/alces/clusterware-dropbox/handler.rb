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
      rescue Dropbox::API::Error, Alces::ClusterwareDropbox::Error
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
        begin
          target = client.find(target_name)
        rescue Dropbox::API::Error::NotFound
          nil
        else
          if !target.is_deleted
            raise FileExists, "a remote file already exists at: #{target_name}"
          end
        end

        uploader = ->(src, tgt) do
          if File.directory?(src)
            src_root = Pathname.new(src)
            Dir.glob(File.join(src_root,'*')).each do |f|
              rel_src = Pathname.new(f).relative_path_from(src_root).to_s
              uploader.call(f, File.join(tgt,rel_src))
            end
          else
            if File.size(src) == 0
              client.upload(tgt, '')
            else
              client.chunked_upload(tgt, File.open(src))
            end
            say "#{src} -> #{tgt}"
          end
        end
        
        uploader.call(args.first,target_name)
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
          remote = resolve_target(name)
          if ! system("curl -L -s -o \"#{tgt}\" #{remote.direct_url.url}")
            raise DownloadFailed, "failed to download: #{name}"
          end
          say "#{name} -> #{File.realpath(tgt)}"
        end

        lister = ->(dir) do
          client.ls(dir).map do |f|
            if f.is_dir
              lister.call(f.path)
            else
              f.path
            end
          end.flatten.reverse
        end
        
        if options.recursive
          resolve_target(args.first, :directory)
          lister.call(args.first).each do |src|
            tgt_file = File.join(target_name,src.gsub(%r(^#{args.first}/),''))
            FileUtils.mkdir_p(File.dirname(tgt_file))
            downloader.call(src, tgt_file)
          end
        else
          downloader.call(args.first, target_name)
        end
      end

      def rm
        if options.recursive
          base = resolve_target(args.first, :directory)
          destroyer = ->(dir) do
            client.ls(dir).map do |f|
              if f.is_dir
                destroyer.call(f.path)
              end
              f.destroy
              say "deleted #{f.path}"
            end
          end
          destroyer.call(args.first)
          base.destroy
          say "deleted #{base.path}"
        else
          target(:file).destroy
          say "deleted #{args[0]}"
        end
      end

      def list
        prefix = [args.first].compact
        files = client.ls(*prefix)
        files.select(&:is_dir).each do |d|
          puts sprintf("%s %10s   %s",
                       Time.rfc2822(d.modified).strftime('%Y-%m-%d %H:%M'),
                       'DIR',
                       d.path.split('/').last)
        end
        files.reject(&:is_dir).each do |f|
          puts sprintf("%s %10s   %s",
                       Time.rfc2822(f.modified).strftime('%Y-%m-%d %H:%M'),
                       f.bytes,
                       f.path.split('/').last)
        end
      rescue Dropbox::API::Error::NotFound
        raise TargetNotFound, "not found: #{args.first}"
      end

      def mkdir
        if args.length > 0
          client.mkdir args.first
        else
          raise MissingArgument, "no directory name supplied"
        end
        say "created bucket #{args[0]}"
      end

      def rmdir
        target(:directory).destroy
        say "removed bucket #{args[0]}"
      end

      def authorize
        consumer = Dropbox::API::OAuth.consumer(:authorize)
        request_token = consumer.get_request_token
        puts "Please visit the following URL in your browser and click 'Authorize':\n\n"
        puts "  #{request_token.authorize_url}"
        query = request_token.authorize_url.split('?').last
        params = CGI.parse(query)
        token = params['oauth_token'].first
        puts "\nOnce you have completed authorization, please press ENTER to continue..."
        $stdin.gets.chomp
        access_token = request_token.get_access_token(:oauth_verifier => token)
        print "Authorization complete."
        if args.first
          data = ["cw_STORAGE_dropbox_access_token='#{access_token.token}'",
                  "cw_STORAGE_dropbox_access_secret='#{access_token.secret}'"]
          File.write(args.first, data.join("\n"))
          if options.quiet
            puts ""
          else
            puts "  Your access token and secret are available in: #{args.first}"
          end
        else
          puts "  Your access token and secret are as follows:\n\n"
          puts "   Access token: #{access_token.token}"
          puts "  Access secret: #{access_token.secret}"
        end
      rescue OAuth::Unauthorized
        raise Unauthorized, "account authorization failed"
      end

      def verify
        account = client.account
        puts "#{account.display_name} <#{account.email}> verified."
      rescue Dropbox::API::Error::Unauthorized
        raise Unauthorized, "authorization token is invalid or incorrect"
      end
      
      private
      def client
        @client ||= Dropbox::API::Client.new(token: ENV['cw_STORAGE_dropbox_access_token'],
                                             secret: ENV['cw_STORAGE_dropbox_access_secret'])
      end

      def target(type = :file)
        if args.length > 0
          resolve_target(args.first, type)
        else
          raise MissingArgument, "no #{type} name supplied"
        end
      end

      def resolve_target(name, type = :file)
        client.find(name).tap do |f|
          if f.is_dir && type == :file
            raise TargetNotFound, "#{type} not found: #{args.first}"
          elsif !f.is_dir && type == :directory
            raise TargetNotFound, "#{type} not found: #{args.first}"
          end
        end
      rescue Dropbox::API::Error::NotFound
        raise TargetNotFound, "#{type} not found: #{args.first}"
      end

      def assert_token
        if !ENV['cw_STORAGE_dropbox_access_token'] || !ENV['cw_STORAGE_dropbox_access_secret']
          raise Unauthorized, "access token (cw_STORAGE_dropbox_access_token) and secret (cw_STORAGE_dropbox_access_secret) environment variables were not set"
        end
      end
    end
  end
end
