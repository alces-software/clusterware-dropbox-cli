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
require 'dropbox-api'
require 'commander'
require 'highline'
require 'dotenv'

require 'alces/clusterware-dropbox/errors'
require 'alces/clusterware-dropbox/handler'
require 'alces/clusterware-dropbox/cli'

HighLine.colorize_strings
Dotenv.load(File.expand_path("#{ENV['BUNDLE_GEMFILE']}/../.env"))
Dropbox::API::Config.app_key = ENV['cw_STORAGE_dropbox_appkey']
Dropbox::API::Config.app_secret = ENV['cw_STORAGE_dropbox_appsecret']
Dropbox::API::Config.mode = 'dropbox'
