#! /bin/bash
while true; do
    for file in /etc/getmailrc.d/getmailrc*; do
        #/usr/bin/getmail --getmaildir /etc/getmailrc.d --rcfile getmailrc.file
        if ! pgrep -f "${file}"$; then
          /usr/bin/getmail --getmaildir /var/lib/getmail --rcfile "${file}"
        fi
    done
    sleep 300
done
