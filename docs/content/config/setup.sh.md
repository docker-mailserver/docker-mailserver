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

```bash
setup.sh Bootstrapping Script

Usage: ./setup.sh [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]

OPTIONS:

  -i IMAGE_NAME     The name of the docker-mailserver image
                    The default value is
                    'docker.io/mailserver/docker-mailserver:latest'

  -c CONTAINER_NAME The name of the running container.

  -p PATH           Config folder path (default: /home/georg/github/docker-mailserver/config)

  -h                Show this help dialogue

  -z                Allow container access to the bind mount content
                    that is shared among multiple containers
                    on a SELinux-enabled host.

  -Z                Allow container access to the bind mount content
                    that is private and unshared with other containers
                    on a SELinux-enabled host.

SUBCOMMANDS:

  email:

    ./setup.sh email add <email> [<password>]
    ./setup.sh email update <email> [<password>]
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

    ./setup.sh config dkim <keysize> (default: 4096) <domain.tld> (optional - for LDAP setups)
    ./setup.sh config ssl <fqdn>

  relay:

    ./setup.sh relay add-domain <domain> <host> [<port>]
    ./setup.sh relay add-auth <domain> <username> [<password>]
    ./setup.sh relay exclude-domain <domain>

  debug:

    ./setup.sh debug fetchmail
    ./setup.sh debug fail2ban [<unban> <ip-address>]
    ./setup.sh debug show-mail-logs
    ./setup.sh debug inspect
    ./setup.sh debug login <commands>

  help: Show this help dialogue
```

[github-file-setupsh]: https://github.com/docker-mailserver/docker-mailserver/blob/master/setup.sh
