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
    ./setup.sh email del <email>
    ./setup.sh email list

  alias:
    ./setup.sh alias add <email> <recipient>
    ./setup.sh alias del <email> <recipient>
    ./setup.sh alias list

  config:

    ./setup.sh config dkim
    ./setup.sh config ssl

  debug:

    ./setup.sh debug fetchmail
    ./setup.sh debug show-mail-logs
    ./setup.sh debug inspect
    ./setup.sh debug login <commands>
```

