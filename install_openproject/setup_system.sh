#!/bin/bash

#let's create a user to ssh into
SSH_USERPASS=`pwgen -c -n -1 12`
groupadd openproject
useradd --create-home -g openproject -g sudo openproject
chown openproject /home/openproject
echo openproject:$SSH_USERPASS | chpasswd
echo ssh openproject password: $SSH_USERPASS
#mysql has to be started this way as it doesn't work to call from /etc/init.d
/usr/bin/mysqld_safe &
sleep 10s

MYSQL_PASSWORD=`pwgen -c -n -1 15`
#This is so the passwords show up in logs.
echo mysql root password: $MYSQL_PASSWORD
echo $MYSQL_PASSWORD > /mysql-root-pw.txt

mysqladmin -u root password $MYSQL_PASSWORD
#mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE openproject; GRANT ALL PRIVILEGES ON openproject.* TO 'openproject'@'localhost' IDENTIFIED BY '$OPENPROJECT_DB_PASSWORD'; FLUSH PRIVILEGES;"

# Download openproject and some public plugins
cd /home/openproject
git clone --depth 1 https://github.com/opf/openproject.git
cd openproject
cat <<__EOF__ > /home/openproject/openproject/Gemfile.plugins
# take the latest and greatest openproject gems from their unstable git branches
# this way we are up-to-date but might experience some bugs

gem 'openproject-plugins',    :git => 'https://github.com/opf/openproject-plugins.git',         :branch => 'dev'
gem 'openproject-backlogs',   :git => 'https://github.com/finnlabs/openproject-backlogs.git',   :branch => 'dev'
gem 'openproject-pdf_export', :git => 'https://github.com/finnlabs/openproject-pdf_export.git', :branch => 'dev'
gem 'openproject-meeting',    :git => 'https://github.com/finnlabs/openproject-meeting.git',    :branch => 'dev'
gem 'openproject-costs',      :git => 'https://github.com/finnlabs/openproject-costs.git',      :branch => 'dev'

__EOF__

cat <<__EOF__ > /home/openproject/openproject/Gemfile.local
# run server with unicorn

gem 'passenger'

__EOF__

cat <<__EOF__ > /home/openproject/openproject/passenger-standalone.json
{
  "port": 8000,
  "environment": "production",
  "min_instances": 1,
  "max_pool_size": 3
}

__EOF__

cat <<__EOF__ > /home/openproject/openproject/config/database.yml
production:
  adapter: mysql2
  database: openproject
  host: localhost
  username: root
  password: `echo $MYSQL_PASSWORD`
  encoding: utf8

development:
  adapter: mysql2
  database: openproject
  host: localhost
  username: root
  password: `echo $MYSQL_PASSWORD`
  encoding: utf8

test:
  adapter: mysql2
  database: openproject_test
  host: localhost
  username: root
  password: `echo $MYSQL_PASSWORD`
  encoding: utf8

__EOF__


gem install bundler
bundle install
bundle exec rake db:create
bundle exec rake db:migrate
bundle exec rake generate_secret_token
bundle exec rake assets:precompile
passenger start --runtime-check-only

killall mysqld
sleep 10s

chown -R openproject /home/openproject
