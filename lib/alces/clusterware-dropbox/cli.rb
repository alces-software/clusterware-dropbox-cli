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
module Alces
  module ClusterwareDropbox
    class CLI
      include Commander::Methods

      def run
        program :version, '1.0.0'
        program :description, 'A basic command-line interface to Dropbox (for use with Alces Clusterware)'

        command :put do |c|
          c.syntax = 'clusterware-dropbox put SOURCE [TARGET]'
          c.summary = 'Upload a file'
          c.action HandlerProxy, :put
          c.option '--recursive', "Recursively upload source directory to Dropbox"
        end

        command :get do |c|
          c.syntax = 'clusterware-dropbox get SOURCE [TARGET]'
          c.summary = 'Download a file'
          c.action HandlerProxy, :get
          c.option '--recursive', "Recursively download source directory from Dropbox"
        end

        command :rm do |c|
          c.syntax = 'clusterware-dropbox rm TARGET'
          c.summary = 'Delete a remote file'
          c.action HandlerProxy, :rm
          c.option '--recursive', "Recursively delete target directory from Dropbox"
        end

        command :mkdir do |c|
          c.syntax = 'clusterware-dropbox mkdir TARGET'
          c.summary = 'Make a remote directory'
          c.action HandlerProxy, :mkdir
        end

        command :rmdir do |c|
          c.syntax = 'clusterware-dropbox rmdir TARGET'
          c.summary = 'Remove a remote directory tree'
          c.action HandlerProxy, :rmdir
        end

        command :list do |c|
          c.syntax = 'clusterware-dropbox list [TARGET]'
          c.summary = 'List remote files and directories'
          c.action HandlerProxy, :list
        end
        alias_command :ls, :list
        
        command :authorize do |c|
          c.syntax = 'clusterware-dropbox authorize'
          c.summary = 'Interactively authorize a Dropbox account'
          c.action HandlerProxy, :authorize
          c.option '-q', '--quiet', "Don't emit filename when tokens are written to a file"
        end

        command :verify do |c|
          c.syntax = 'clusterware-dropbox verify'
          c.summary = 'Verify an account token/secret is working'
          c.action HandlerProxy, :verify
        end

        run!
      end
    end
  end
end

