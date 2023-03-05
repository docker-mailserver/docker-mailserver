#!/bin/bash

function postsrsd_stop
{
  /etc/init.d/postsrsd stop # does not properly stop postsrsd process
  kill $(pidof postsrsd)
}

trap postsrsd_stop EXIT

/etc/init.d/postsrsd start

# wait until postsrsd is dead (triggered by trap)
while kill -0 "$(< /var/run/postsrsd.pid)"
do
  sleep 5
done
