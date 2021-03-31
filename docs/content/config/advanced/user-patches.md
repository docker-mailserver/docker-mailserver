---
title: 'Custom user changes & patches'
---

If you'd like to change, patch or alter files or behavior of `docker-mailserver`, you can use a script. Just place it the `config/` folder that is created on startup and call it `user-patches.sh`. The setup is done like this:

``` BASH
# 1. Either create the config/ directory yourself
#    or let docker-mailserver create it on initial
#    startup
/where/docker-mailserver/resides/ $ mkdir config && cd config

# 2. Create the user-patches.sh script and make it
#    executable
/where/docker-mailserver/resides/config/ $ touch user-patches.sh
/where/docker-mailserver/resides/config/ $ chmod +x user-patches.sh

# 3. Edit it
/where/docker-mailserver/resides/config/ $ vi user-patches.sh
/where/docker-mailserver/resides/config/ $ cat user-patches.sh
#! /bin/bash

# ! THIS IS AN EXAMPLE !

# If you modify any supervisord configuration, make sure
# to run `supervisorctl update` and/or `supervisorctl reload` afterwards.

# shellcheck source=/dev/null
. /usr/local/bin/helper-functions.sh

_notify 'Applying user-patches'

if ! grep -q '192.168.0.1' /etc/hosts
then
  echo -e '192.168.0.1 some.domain.com' >> /etc/hosts
fi
```

And you're done. The user patches script runs right before starting daemons. That means, all the other configuration is in place, so the script can make final adjustments.
