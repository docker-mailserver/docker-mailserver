#!/usr/bin/env bash
# postfix-wrapper.sh, version 0.1.0
#
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

# start postfix
service postfix start

# lets give postfix some time to start
sleep 5

# wait until postfix is dead (triggered by trap)
while kill -0 "`cat /var/spool/postfix/pid/master.pid`"; do
  sleep 5
done

