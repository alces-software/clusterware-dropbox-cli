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

module Alces
  module ClusterwareDropbox
    class HandlerProxy
      def method_missing(s,*a,&b)
        if Handler.instance_methods.include?(s)
          Bundler.with_clean_env do
            Handler.new(*a).send(s)
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
      def initialize(*)
        super
      end

      def put
        if args.length < 1
          raise MissingArgument, "source file must be specified"
        elsif !File.exists?(args.first)
          raise SourceNotFound, "could not find source file: #{args.first}"
        end
        target_name = args[1] || File.basename(args.first)
        begin
          client.find(target_name)
        rescue Dropbox::API::Error::NotFound
          nil
        else
          raise FileExists, "a remote file already exists at: #{target_name}"
        end
        client.chunked_upload(target_name, File.open(args[0]))
      end

      def get
        target_name =
          if args[1]
            if File.directory?(args[1])
              File.join(target_name, File.basename(args.first))
            else
              args[1]
            end
          else
            File.basename(args.first)
          end

        if File.exists?(target_name)
          raise FileExists, "a local file already exists at: #{target_name}"
        end

        if ! system("curl -L -s -o \"#{target_name}\" #{target.direct_url.url}")
          raise DownloadFailed, "failed to download: #{args.first}"
        end
      end

      def rm
        target(:file).destroy
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
      end

      def rmdir
        target(:directory).destroy
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
        @client ||= Dropbox::API::Client.new(token: options.token || ENV['cw_DROPBOX_access_token'],
                                             secret: options.secret || ENV['cw_DROPBOX_secret_token'])
      end

      def target(type = :file)
        if args.length > 0
          client.find(args.first).tap do |f|
            if f.is_dir && type == :file
              raise TargetNotFound, "#{type} not found: #{args.first}"
            elsif !f.is_dir && type == :directory
              raise TargetNotFound, "#{type} not found: #{args.first}"
            end
          end
        else
          raise MissingArgument, "no #{type} name supplied"
        end
      rescue Dropbox::API::Error::NotFound
        raise TargetNotFound, "#{type} not found: #{args.first}"
      end
    end
  end
end
