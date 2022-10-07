#! /bin/bash
for file in /etc/getmailrc.d/getmailrc*; do
  if ! pgrep -f "${file}"$; then
    /usr/bin/getmail --getmaildir /var/lib/getmail --rcfile "${file}"
  fi
done
