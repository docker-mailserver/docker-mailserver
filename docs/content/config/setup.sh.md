---
title: Your best friend setup.sh
hide:
  - toc # Hide Table of Contents for this page
---

[`setup.sh`][github-file-setupsh] is an administration script that helps with the most common tasks, including initial configuration. It is intented to be used from the host machine, _not_ from within your running container.

The latest version of the script is included in the `docker-mailserver` repository. You may retrieve it at any time by running this command in your console:

```sh
wget https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/setup.sh
chmod a+x ./setup.sh
```

!!! info

    Make sure to get the `setup.sh` that comes with the release you're using. Look up the release and the git commit on which this release is based upon by selecting the appropriate tag on GitHub. This can done with the "Switch branches/tags" button on GitHub, choosing the right tag. This is done in order to rule out possible inconsistencies between versions.

## Usage

Run `./setup.sh help` and you'll get some usage information:

```TXT
SETUP(1)

NAME
    setup.sh - docker-mailserver administration script

SYNOPSIS
    ./setup.sh [ OPTIONS... ] COMMAND [ help | ARGUMENTS... ]

    COMMAND := { email | alias | quota | config | relay | debug } SUBCOMMAND

DESCRIPTION
    This is the main administration script that you use for all interactions with your
    mail server. Setup, configuration and much more is done with this script.

    Please note that the script executes most of the commands inside the container itself.
    If the image was not found, this script will pull the :latest tag of
    mailserver/docker-mailserver. This tag refers to the latest release,
    see the tagging convention in the README under
    https://github.com/docker-mailserver/docker-mailserver/blob/master/README.md

    You will be able to see detailed information about the script you are invoking and
    its arguments by appending help after your command. Currently, this
    does not work with all scripts.

VERSION
    The current version of this script is backwards compatible with versions of
    docker-mailserver after 8.0.1. In case that there is not a more recent release,
    this script is currently only working with the :edge tag.

    You can download the script for your release by substituting TAG from the
    following URL, where TAG looks like 'vX.X.X':
    https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/TAG/setup.sh

OPTIONS
    Config path, container or image adjustments
        -i IMAGE_NAME
            Provides the name of the docker-mailserver image. The default value is
            docker.io/mailserver/docker-mailserver:latest

        -c CONTAINER_NAME
            Provides the name of the running container.

        -p PATH
            Provides the config folder path. The default is
            /home/maxwell/Dokumente/github/docker-mailserver/config/

    SELinux
        -z
            Allows container access to the bind mount content that is shared among
            multiple containers on a SELinux-enabled host.

        -Z
            Allows container access to the bind mount content that is private and
            unshared with other containers on a SELinux-enabled host.

[SUB]COMMANDS
    COMMAND email :=
        ./setup.sh email add <EMAIL ADDRESS> [<PASSWORD>]
        ./setup.sh email update <EMAIL ADDRESS> [<PASSWORD>]
        ./setup.sh email del [ OPTIONS... ] <EMAIL ADDRESS> [ <EMAIL ADDRESS>... ]
        ./setup.sh email restrict <add|del|list> <send|receive> [<EMAIL ADDRESS>]
        ./setup.sh email list

    COMMAND alias :=
        ./setup.sh alias add <EMAIL ADDRESS> <RECIPIENT>
        ./setup.sh alias del <EMAIL ADDRESS> <RECIPIENT>
        ./setup.sh alias list

    COMMAND quota :=
        ./setup.sh quota set <EMAIL ADDRESS> [<QUOTA>]
        ./setup.sh quota del <EMAIL ADDRESS>

    COMMAND config :=
        ./setup.sh config dkim [ ARGUMENTS... ]

    COMMAND relay :=
        ./setup.sh relay add-domain <DOMAIN> <HOST> [<PORT>]
        ./setup.sh relay add-auth <DOMAIN> <USERNAME> [<PASSWORD>]
        ./setup.sh relay exclude-domain <DOMAIN>

    COMMAND debug :=
        ./setup.sh debug fetchmail
        ./setup.sh debug fail2ban [unban <IP>]
        ./setup.sh debug show-mail-logs
        ./setup.sh debug inspect
        ./setup.sh debug login <COMMANDS>

EXAMPLES
    ./setup.sh email add test@domain.tld
        Add the email account test@domain.tld. You will be prompted
        to input a password afterwards since no password was supplied.

    ./setup.sh config dkim keysize 2048 domain 'whoami.com,whoareyou.org'
        Creates keys of length 2048 but in an LDAP setup where domains are not known to
        Postfix by default, so you need to provide them yourself in a comma-separated list.

    ./setup.sh config dkim help
        This will provide you with a detailed explanation on how to use the 
        config dkim command, showing what arguments can be passed and what they do.

EXIT STATUS
    Exit status is 0 if the command was successful. If there was an unexpected error, an error
    message is shown describing the error. In case of an error, the script will exit with exit
    status 1.

```

[github-file-setupsh]: https://github.com/docker-mailserver/docker-mailserver/blob/master/setup.sh
