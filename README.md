# Alces Clusterware command-line interface for Dropbox

## Overview

This is a simple command-line application to provide a simple
interface to the contents of your Dropbox account.

This application is primarily intended for use to provide access to
Dropbox storage via the Alces Clusterware storage tool but may also
be used standalone.

## Installation

 * Clone the repo: `git clone https://github.com/alces-software/clusterware-dropbox-cli.git`
 * Install libraries: `bundle install`
 * Set your application key and secret in your environment or in a `.env` file in the application root:

```
cw_STORAGE_dropbox_appkey='<application key>'
cw_STORAGE_dropbox_appsecret='<application secret>'
```

## Usage

```
[user@localhost clusterware-dropbox-cli]$ bin/clusterwar-dropbox authorize
Please visit the following URL in your browser and click 'Authorize':

  https://www.dropbox.com/1/oauth/authorize?oauth_token=<auth_token>

Once you have completed authorization, please press ENTER to continue...

Authorization complete.  Your access token and secret are as follows:

   Access token: <access token>
  Access secret: <access secret>
     
[user@localhost clusterware-dropbox-cli]$ export cw_STORAGE_dropbox_access_token='<access token>'

[user@localhost clusterware-dropbox-cli]$ export cw_STORAGE_dropbox_access_secret='<access secret>'

[user@localhost clusterware-dropbox-cli]$ bin/clusterware-dropbox list
2015-03-24 07:34        DIR   Photos
2015-03-24 07:34        DIR   Public
2015-11-11 09:35        DIR   Shared
2016-02-12 20:02        DIR   test
2015-08-02 12:16    1333892   20140930_145134.jpg
2015-04-16 18:59    3140592   20141028_130940.jpg
2015-04-16 18:59    2556115   20141028_131053.jpg
2015-04-16 18:59    2689087   20141110_140754.jpg
2015-04-16 18:59    2446584   20141115_140149.jpg
2015-04-16 18:59     175932   20150412_110611.jpg

[user@localhost clusterware-dropbox-cli]$ bin/clusterware-dropbox put README.md
README.md -> README.md

[user@localhost clusterware-dropbox-cli]$ bin/clusterware-dropbox rm README.md
deleted README.md
```

Also see `clusterware-dropbox --help`.

## Contributing

Fork the project. Make your feature addition or bug fix. Send a pull
request. Bonus points for topic branches.

## Copyright and License

AGPLv3+ License, see [LICENSE.txt](LICENSE.txt) for details.

Copyright (C) 2016 Alces Software Ltd.

Alces Clusterware is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

Alces Clusterware is made available under a dual licensing model whereby use of the package in projects that are licensed so as to be compatible with AGPL Version 3 may use the package under the terms of that license. However, if AGPL Version 3.0 terms are incompatible with your planned use of this package, alternative license terms are available from Alces Software Ltd - please direct inquiries about licensing to [licensing@alces-software.com](mailto:licensing@alces-software.com).
