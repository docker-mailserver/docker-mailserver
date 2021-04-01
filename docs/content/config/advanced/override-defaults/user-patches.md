---
title: 'Custom User Changes & Patches | Scripting'
---

If you'd like to change, patch or alter files or behavior of `docker-mailserver`, you can use a script.

In case you cloned this repository, you can copy the file `user-patches.sh.dist` under `config/` with `#!sh cp config/user-patches.sh.dist config/user-patches.sh` in order to create the `user-patches.sh` script. In case you are managing your directory structure yourself, create a `config/` directory and the `user-patches.sh` file yourself.

``` sh
# 1. Either create the config/ directory yourself
#    or let docker-mailserver create it on initial
#    startup
~/somewhere $ mkdir config && cd config

# 2. Create the user-patches.sh and edit it
~/somewhere/config $ touch user-patches.sh
~/somewhere/config $ vi user-patches.sh
```

The contents could look like this

``` sh
#! /bin/bash

sed -i -E 's|(log_level).*|\1 = -1;|g' /etc/amavis/conf.d/49-docker-mailserver

cat >/etc/amavis/conf.d/50-user << "END"
use strict;

$undecipherable_subject_tag = undef;
$admin_maps_by_ccat{+CC_UNCHECKED} =  undef;

#------------ Do not modify anything below this line -------------
1;  # ensure a defined return
END

...
```

And you're done. The user patches script runs right before starting daemons. That means, all the other configuration is in place, so the script can make final adjustments.

!!! note
    Many "patches" can already be done with the Docker Compose-/Stack-file. Adding hostnames to `/etc/hosts` is done with the `#!yaml extra_hosts:` section, `sysctl` commands can be managed with the `#!yaml sysctls:` section, etc.
