#!/usr/bin/env bash
# fail2ban-wrapper.sh, version 0.0.1
#
# You cannot start fail2ban in some foreground mode and
# it's more or less important that docker doesn't kill
# fail2ban and its chilren if you stop the container.
#
# Use this script with supervisord and it will take
# care about starting and stopping fail2ban correctly.
#
# supervisord config snippet for fail2ban-wrapper:
#
# [program:fail2ban]
# process_name = fail2ban
# command = /path/to/fail2ban-wrapper.sh
# startsecs = 0
# autorestart = false
#

trap "/usr/bin/fail2ban-client stop" SIGINT
trap "/usr/bin/fail2ban-client stop" SIGTERM
trap "/usr/bin/fail2ban-client reload" SIGHUP

# start fail2ban
/usr/bin/fail2ban-client start

# lets give fail2ban some time to start
sleep 5

# wait until fail2ban is dead (triggered by trap)
while kill -0 "`cat /var/run/fail2ban/fail2ban.pid`"; do
  sleep 5
done

