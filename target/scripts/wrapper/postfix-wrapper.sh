#! /bin/bash

# You cannot start postfix in some foreground mode and
# it's more or less important that docker doesn't kill
# postfix and its chilren if you stop the container.
#
# Use this script with supervisord and it will take
# care about starting and stopping postfix correctly.
#
# supervisord config snippet for postfix-wrapper:
#
# [program:postfix]
# process_name = postfix
# command = /path/to/postfix-wrapper.sh
# startsecs = 0
# autorestart = false
#

trap "service postfix stop" SIGINT
trap "service postfix stop" SIGTERM
trap "service postfix reload" SIGHUP

service postfix start

# wait until postfix is dead (triggered by trap)
while kill -0 "$(< /var/spool/postfix/pid/master.pid)"
do
  sleep 5
done
