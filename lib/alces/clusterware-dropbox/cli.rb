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
        program :version, '0.0.1'
        program :description, 'Integration with Dropbox for Alces Clusterware storage'

        global_option '-t', '--token TOKEN', String, 'Dropbox account token'
        global_option '-s', '--secret SECRET', String, 'Dropbox account secret'
        
        command :put do |c|
          c.syntax = 'clusterware-dropbox get [options]'
          c.summary = ''
          c.description = ''
          c.action HandlerProxy, :put
        end

        command :get do |c|
          c.syntax = 'clusterware-dropbox get [options]'
          c.summary = ''
          c.description = ''
          c.action HandlerProxy, :get
        end

        command :rm do |c|
          c.syntax = 'clusterware-dropbox rm [options]'
          c.summary = ''
          c.description = ''
          c.action HandlerProxy, :rm
        end

        command :mkdir do |c|
          c.syntax = 'clusterware-dropbox mkdir [options]'
          c.summary = ''
          c.description = ''
          c.action HandlerProxy, :mkdir
        end

        command :rmdir do |c|
          c.syntax = 'clusterware-dropbox rmdir [options]'
          c.summary = ''
          c.description = ''
          c.action HandlerProxy, :rmdir
        end

        command :list do |c|
          c.syntax = 'clusterware-dropbox list [options]'
          c.summary = ''
          c.description = ''
          c.action HandlerProxy, :list
        end
        alias_command :ls, :list
        
        command :authorize do |c|
          c.syntax = 'clusterware-dropbox authorize [options]'
          c.summary = ''
          c.description = ''
          c.action HandlerProxy, :authorize
          c.option '-q', '--quiet', "Don't emit filename when tokens are written to a file"
        end

        command :verify do |c|
          c.syntax = 'clusterware-dropbox verify [options]'
          c.summary = ''
          c.description = ''
          c.action HandlerProxy, :verify
        end

        run!
      end
    end
  end
end

