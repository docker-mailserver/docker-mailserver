The latest version of the script `setup.sh` is included in the `docker-mailserver` repository. Get the last version to the script by copying this command in your console:

```
wget -q -O setup.sh https://raw.githubusercontent.com/tomav/docker-mailserver/master/setup.sh; chmod a+x ./setup.sh
```
if you use curl:
```
curl -o setup.sh https://raw.githubusercontent.com/tomav/docker-mailserver/master/setup.sh; chmod a+x ./setup.sh
```

Run `./setup.sh` without arguments and you get some usage informations.

```
Usage: ./setup.sh [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]

OPTIONS:

  -i IMAGE_NAME     The name of the docker-mailserver image, by default
                    'tvial/docker-mailserver:latest'.
  -c CONTAINER_NAME The name of the running container.

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

  config:

    ./setup.sh config dkim <keysize> (default: 2048)
    ./setup.sh config ssl

  debug:

    ./setup.sh debug fetchmail
    ./setup.sh debug show-mail-logs
    ./setup.sh debug inspect
    ./setup.sh debug login <commands>
```
# email 
* `./setup.sh email add <email> [<password>]`: Add an email-account (\<password\> is optional)
* `./setup.sh email update <email> [<password>]`: Change the password of an email-account (\<password\> is optional)
* `./setup.sh email del <email>': delete an email-account
* `./setup.sh email restrict <add|del|list> <send|receive> [<email>]`: deny users to send or receive mail. You can also list the respective denied mail-accounts.
* `./setup.sh email list`: list all existing email-accounts
# alias
* `./setup.sh alias add <email> <recipient>`: add an alias(email) for an email-account(recipient)
* `./setup.sh alias del <email> <recipient>`: delete an alias
* `./setup.sh alias list`: list all aliases
# config 
* `./setup.sh config dkim <keysize> (default: 2048)`: autoconfig the dkim-config with an (optional) keysize value
* `./setup.sh config ssl`: generate ssl-certificates
# debug 
* `./setup.sh debug fetchmail`: see [wiki](https://github.com/tomav/docker-mailserver/wiki/Retrieve-emails-from-a-remote-mail-server-%28using-builtin-fetchmail%29#debugging)
* `./setup.sh debug fail2ban <unban> <ip-address>`: omitt all options to get a list of banned IPs, otherwise unban the specified IP.
* `./setup.sh debug show-mail-logs`: show the logfile contents of the mail container
* `./setup.sh debug inspect`: show infos about the running container
* `./setup.sh debug login <commands>`: run a command inside the mail container (omit the command to get shell access)

