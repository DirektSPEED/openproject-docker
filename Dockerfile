# From the Ubuntu Core Baseimage
FROM dockerimages/ubuntu-core:14.04

MAINTAINER Frank Lemanschik (Direkt SPEED), info@dspeed.eu

ENV MYSQL_PASSWORD=`pwgen -c -n -1 15`
ENV RBENV_ROOT /home/openproject/.rbenv
ENV PATH /home/openproject/.rbenv/bin:$PATH
ENV CONFIGURE_OPTS --disable-install-doc

EXPOSE 80

# Install ruby and its dependencies
# Install Passanger (Ruby App Server)
# Install MySql Server
# Install Python 
# Install APT-SSH Transporter.
#
RUN echo "deb mirror://mirrors.ubuntu.com/mirrors.txt trusty main restricted universe multiverse \n\
deb mirror://mirrors.ubuntu.com/mirrors.txt trusty-updates main restricted universe multiverse \n\
deb mirror://mirrors.ubuntu.com/mirrors.txt trusty-backports main restricted universe multiverse \n\
deb mirror://mirrors.ubuntu.com/mirrors.txt trusty-security main restricted universe multiverse" > /etc/apt/sources.list
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 561F9B9CAC40B2F7 \
 && apt-get update -q && apt-get -y install apt-transport-https ca-certificates \
 && echo 'deb https://oss-binaries.phusionpassenger.com/apt/passenger trusty main' > /etc/apt/sources.list.d/passenger.list \
 && apt-get update -q \
 && locale-gen en_US en_US.UTF-8 \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
    build-essential curl git zlib1g-dev libssl-dev libreadline-dev libyaml-dev libxml2-dev \
    libxslt-dev libxslt1-dev libmysqlclient-dev libpq-dev libsqlite3-dev libyaml-0-2 libmagickwand-dev \
    libmagickcore-dev libmagickcore5-extra libgraphviz-dev libgvc6 ruby-dev memcached \
    subversion vim wget python-setuptools openssh-server sudo pwgen libcurl4-openssl-dev passenger \
    mysql-client mysql-server \
 && apt-get -y clean \
 && groupadd openproject \
 && useradd --create-home -g openproject -g sudo openproject \
 && chown openproject /home/openproject 
RUN apt-get install libgdbm-dev libncurses5-dev automake libtool bison libffi-dev \
 && curl -L https://get.rvm.io | bash -s stable \
 && source ~/.rvm/scripts/rvm \
 && echo "source ~/.rvm/scripts/rvm" >> ~/.bashrc \
 && rvm install 2.1.2 \
 && rvm use 2.1.2 --default \
 && ruby -v \
 && cd /home/openproject \
 && git clone --depth 1 https://github.com/opf/openproject.git \
 && cd openproject \
 && mv /Gemfile.plugins /home/openproject/openproject/Gemfile.plugins \
 && mv /Gemfile.local /home/openproject/openproject/Gemfile.local

#mysql has to be started this way as it doesn't work to call from /etc/init.d
RUN exec "/usr/bin/mysqld_safe &" \
 && sleep 7s \
 && mysqladmin -u root password $MYSQL_PASSWORD
#mysql -uroot -p$MYSQL_PASSWORD -e "CREATE DATABASE openproject; GRANT ALL PRIVILEGES ON openproject.* TO 'openproject'@'localhost' IDENTIFIED BY '$OPENPROJECT_DB_PASSWORD'; FLUSH PRIVILEGES;"

RUN echo " \
production: \n\
  adapter: mysql2 \n\
  database: openproject \n\
  host: localhost \n\
  username: root \n\
  password: $MYSQL_PASSWORD \n\
  encoding: utf8 \n\
 \n\
development: \n\
  adapter: mysql2 \n\
  database: openproject \n\
  host: localhost \n\
  username: root \n\
  password: $MYSQL_PASSWORD \n\
  encoding: utf8 \n\
 \n\
test: \n\
  adapter: mysql2 \n\
  database: openproject_test \n\
  host: localhost \n\
  username: root \n\
  password: $MYSQL_PASSWORD \n\
  encoding: utf8" > /home/openproject/openproject/config/database.yml \
 && gem install bundler \
 && echo "# because of 'very good reasons'(tm) we need to source rbenv.sh again, so that it finds \ 
         the bundle command . /etc/profile.d/rbenv.sh" \
 && bundle install \
 && bundle exec rake db:create:all \
 && bundle exec rake db:migrate \
 && bundle exec rake generate_secret_token \
 && RAILS_ENV=production bundle exec rake db:seed \
 && bundle exec rake assets:precompile \
 && bundle exec passenger start --runtime-check-only \
 && killall mysqld \
 && sleep 7s \
 && chown -R openproject /home/openproject \
 && easy_install supervisor \
 && mkdir /var/log/supervisor/

ADD ./files/Gemfile.local /Gemfile.local
ADD ./files/Gemfile.plugins /Gemfile.plugins
ADD ./files/passenger-standalone.json /home/openproject/openproject/passenger-standalone.json
ADD ./files/start_openproject.sh /home/openproject/start_openproject.sh
ADD ./files/start_openproject_worker.sh /home/openproject/start_openproject_worker.sh
ADD ./files/supervisord.conf /etc/supervisord.conf
#ENTRYPOINT ["supervisord", "-n"]
CMD ["supervisord", "-n"]
# RUN echo "INFO: openproject ssh password: `cat /root/openproject-root-pw.txt`"
