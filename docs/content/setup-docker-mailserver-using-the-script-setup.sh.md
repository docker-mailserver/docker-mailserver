The latest version of the script `setup.sh` is included in the `docker-mailserver` repository. Get the last version to the script by copying this command in your console:

```
wget -q -O setup.sh https://raw.githubusercontent.com/tomav/docker-mailserver/master/setup.sh; chmod a+x ./setup.sh
```

Run `./setup.sh` without arguments and you get some usage informations.

```
Usage: ./setup.sh <subcommand> <subcommand> [args]

SUBCOMMANDS:

  email:

    ./setup.sh email add <email> <password>
    ./setup.sh email del <email>
    ./setup.sh email list

  config:

    ./setup.sh config dkim
    ./setup.sh config ssl

  debug:

    ./setup.sh debug fetchmail
```

