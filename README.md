# OpenProject Docker

A Dockerfile that installs OpenProject.
Actually it installs `sshd`, `memcached`, `mysql server`, `rbenv`, `ruby 2.1`, `passenger`,and a fresh `openproject` development snapshot.

Please keep in mind, that we do **not** recommend to use the produced Docker image in production.
Why?
Because the docker team says that docker ["should not be used in production"](https://www.docker.io/learn_more/),
your data is not persisted (we'll talk about that later), there are no backups, no monitoring etc.

However, we strive to make our docker image secure and stable, so that we/you can use it in production in the future.

## Installation

First [install docker](https://www.docker.io/). Then do the following to build an OpenProject image (this may take some time):

```
$ git clone https://github.com/opf/openproject-docker.git
$ cd openproject-docker
$ docker build -t="openproject_evaluation" .
```

**NOTE:** depending on your docker installation, you might need to prepend `sudo ` to your `docker` commands

## Usage

To spawn a new instance of OpenProject:

```bash
$ docker run -p 8080 -d openproject_evaluation
```

The `-d` flag lets docker start the image in the background and prints the container id to stdout.
You'll see an ID output like:
```
d404cc2fa27b
```

Use the container ID to check the port it's on:
```bash
$ docker port <container-id> 8080
```

which gives you something like:
```
0.0.0.0:49190
```

We see that `49190` is the port the webserver is located at (it is probably different for you!).
You can the visit the following URL in a browser on your host machine to get started:

```
http://127.0.0.1:<port>
```

## Get a shell on your OpenProject image

Concurrently with the OpenProject server, we start an ssh daemon which listens on the default port 22.
To connect to your OpenProject image, you have to tell docker to connect that port.
Start your image with the additional port:

```bash
$ docker run -p 8080 -p 20 -d openproject_evaluation
```

You may find out which of your local ports is mapped to the image-22-port with `docker port` and connect to your image:

```bash
$ ssh -p <port> openproject@localhost
$ openproject@localhost's password:
```

Well, we need a password now. The openproject account is secured with a random password.
We set that password during the image setup - watch for a line like `ssh openproject password: <random password>`
during the `docker build -t="openproject_evaluation" .` step.

## Further thoughts

### Persist your data

Everything OpenProject needs lies within its docker image. That includes the database and uploaded files (and log data, and maybe some repositories).
The time may come when you want to use a new OpenProject docker image (e.g. when a new OpenProject version was released) and we need to take care
of the data stored in your old image.

We don't have a good solution built-in yet, but there is [a promising blog post](http://www.tech-d.net/2013/12/16/persistent-volumes-with-docker-container-as-volume-pattern/)
from [Brian Goff](https://github.com/cpuguy83).

Brian proposes to use two docker containers - One for the app and another one for the data.
Now, the application container can mount directories from the data-container.
You can easily backup your data container, or replace your app container.

The places we need to take care of for OpenProject are:

* `RAILS_ROOT/files` - all files which are uploaded are placed here
* `/var/lib/mysql` - the place where MySQL stores its database
* `RAILS_ROOT/log` - the OpenProject logfiles, in case you care
* if you have configured OpenProject to use/create local repositories, the place where you store those repositories

### Update the OpenProject code base

To upgrade your OpenProject installation, ssh into your container and do a `git pull` within the OpenProject directory.
A `bundle install`, `bundle exec rake db:migrate`, and `bundle exec rake assets:precompile` should finish the upgrade.

Now restart your container and a new OpenProject should be running.

As always: If you care about your data, do a backup before upgrading!

### E-Mail Setup

The OpenProject image is configured to use `letter_opener` for mail handling. `letter_opener` does **not**
send actual mails, but displays the mail that would be sent in another browser tab.

If you want to send actual emails, edit the `configuration.yml` (in `files/configuration.yml` before you build).

Replace the lines

```yml
default:
  email_delivery_method: :letter_opener
```

with your actual Mail settings - for example:
```yml
default:
  # Outgoing emails configuration
  email_delivery_method: :smtp
  smtp_address: smtp.example.net
  smtp_port: 25
  smtp_domain: example.net
  smtp_authentication: :login
  smtp_user_name: "openproject@example.net"
  smtp_password: "my_openproject_password"
```

**Note:** Please take care of indentation - white space is important for `.yml` files!

### OpenProject plug-ins

We have included some OpenProject plug-ins into the docker image. However, you can change the list of plug-ins (and install some themes, or even remove all the plug-ins).
To do this, edit the `files/Gemfile.plugins` file before you build.

### Features which we'd love to have

* Ability yo use an external database
* an additional image (or instructions) for 'easy' development
* nice seed data
* make the admin change his password on the first login
* ssh-login with a different user (so that we can remove the openproject user from the sudoers list)


## Contribute

We are happy for any contribution :) You may either

* make a Pull Request (which we favor ;))
* [open a new issue](https://www.openproject.org/projects/docker/work_packages/new) at our bug tracker
* or discuss [at the forums](https://www.openproject.org/projects/openproject/boards)

## License

This work is licensed under the GPLv3 - see [COPYRIGHT.md](COPYRIGHT.md) for details.
