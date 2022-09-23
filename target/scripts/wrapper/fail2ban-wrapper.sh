#! /bin/bash

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

# fail2ban calls close_range(0, $OPEN_MAX, ..) which causes it to hang on startup
# in some containers.
# fixed in 535a982dcc of fail2ban - delete once debian has the fix:
ulimit -n 1024

/usr/bin/fail2ban-client start
sleep 5

# wait until fail2ban is dead (triggered by trap)
while kill -0 "$(< /var/run/fail2ban/fail2ban.pid)"
do
  sleep 5
done

