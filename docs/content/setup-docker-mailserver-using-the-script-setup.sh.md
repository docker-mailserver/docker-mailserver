[`setup.sh`](https://github.com/tomav/docker-mailserver/blob/master/setup.sh) is an administration script that helps with the most common tasks, including initial configuration. It is intented to be used from the host machine, _not_ from within your running container.

The latest version of the script is included in the `docker-mailserver` repository. You may retrieve it at any time by running this command in your console:

```sh
wget -q -O setup.sh https://raw.githubusercontent.com/tomav/docker-mailserver/master/setup.sh; chmod a+x ./setup.sh
```

Or if you use curl:

```sh
curl -o setup.sh https://raw.githubusercontent.com/tomav/docker-mailserver/master/setup.sh; chmod a+x ./setup.sh
```

## Usage

Run `./setup.sh` without arguments and you'll get some usage information:

```sh
Usage: ./setup.sh [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]

OPTIONS:

  -i IMAGE_NAME     The name of the docker-mailserver image, by default
                    'tvial/docker-mailserver:latest'.

  -c CONTAINER_NAME The name of the running container.

  -z                Allow container access to the bind mount content
                    that is shared among multiple containers
                    on a SELinux-enabled host.

  -Z                Allow container access to the bind mount content
                    that is private and unshared with other containers
                    on a SELinux-enabled host.

SUBCOMMANDS:

  email:

    ./setup.sh email add <email> <password>
    ./setup.sh email update <email> <password>
    ./setup.sh email del <email>
    ./setup.sh email restrict <add|del|list> <send|receive> [<email>]
    ./setup.sh email list

  alias:
    ./setup.sh alias add <email> <recipient>
    ./setup.sh alias del <email> <recipient>
    ./setup.sh alias list

  quota:
    ./setup.sh quota set <email> [<quota>]
    ./setup.sh quota del <email>

  config:

    ./setup.sh config dkim <keysize> (default: 2048)
    ./setup.sh config ssl

  debug:

    ./setup.sh debug fetchmail
    ./setup.sh debug show-mail-logs
    ./setup.sh debug inspect
    ./setup.sh debug login <commands>
```

## email

* `./setup.sh email add <email> [<password>]`: Add an email-account (\<password\> is optional)
* `./setup.sh email update <email> [<password>]`: Change the password of an email-account (\<password\> is optional)
* `./setup.sh email del <email>`: delete an email-account
* `./setup.sh email restrict <add|del|list> <send|receive> [<email>]`: deny users to send or receive mail. You can also list the respective denied mail-accounts.
* `./setup.sh email list`: list all existing email-accounts

## alias
* `./setup.sh alias add <email> <recipient>`: add an alias(email) for an email-account(recipient)
* `./setup.sh alias del <email> <recipient>`: delete an alias
* `./setup.sh alias list`: list all aliases

## quota

* `./setup.sh quota set <email> [<quota>]`: define the quota of a mailbox (quota format e.g. 302M (B (byte), k (kilobyte), M (megabyte), G (gigabyte) or T (terabyte)))
*  `./setup.sh quota del <email>`: delete the quota of a mailbox

## config 

* `./setup.sh config dkim <keysize> (default: 2048)`: autoconfig the dkim-config with an (optional) keysize value
* `./setup.sh config ssl`: generate ssl-certificates

## debug 

* `./setup.sh debug fetchmail`: see [wiki](https://github.com/tomav/docker-mailserver/wiki/Retrieve-emails-from-a-remote-mail-server-%28using-builtin-fetchmail%29#debugging)
* `./setup.sh debug fail2ban <unban> <ip-address>`: omitt all options to get a list of banned IPs, otherwise unban the specified IP.
* `./setup.sh debug show-mail-logs`: show the logfile contents of the mail container
* `./setup.sh debug inspect`: show infos about the running container
* `./setup.sh debug login <commands>`: run a command inside the mail container (omit the command to get shell access)

