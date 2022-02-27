---
title: 'Custom User Changes & Patches | Scripting'
---

If you'd like to change, patch or alter files or behavior of `docker-mailserver`, you can use a script.

In case you cloned this repository, you can copy the file [`user-patches.sh.dist` (_under `config/`_)][gh-file-userpatches] with `#!sh cp config/user-patches.sh.dist docker-data/dms/config/user-patches.sh` in order to create the `user-patches.sh` script.

If you are managing your directory structure yourself, create a `docker-data/dms/config/` directory and add the `user-patches.sh` file yourself.

``` sh
# 1. Either create the docker-data/dms/config/ directory yourself
#    or let docker-mailserver create it on initial startup
/tmp $ mkdir -p docker-data/dms/config/ && cd docker-data/dms/config/

# 2. Create the user-patches.sh file and edit it
/tmp/docker-data/dms/config $ touch user-patches.sh
/tmp/docker-data/dms/config $ nano user-patches.sh
```

The contents could look like this:

``` sh
#! /bin/bash

cat >/etc/amavis/conf.d/50-user << "END"
use strict;

$undecipherable_subject_tag = undef;
$admin_maps_by_ccat{+CC_UNCHECKED} =  undef;

#------------ Do not modify anything below this line -------------
1;  # ensure a defined return
END

```

And you're done. The user patches script runs right before starting daemons. That means, all the other configuration is in place, so the script can make final adjustments.

!!! note
    Many "patches" can already be done with the Docker Compose-/Stack-file. Adding hostnames to `/etc/hosts` is done with the `#!yaml extra_hosts:` section, `sysctl` commands can be managed with the `#!yaml sysctls:` section, etc.

[gh-file-userpatches]: https://github.com/docker-mailserver/docker-mailserver/blob/master/config-examples/user-patches.sh.dist
