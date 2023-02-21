#!/bin/bash
##
# This user script will be executed between configuration and starting daemons
# To enable it you must save it in your config directory as "user-patches.sh"
##
echo "[user-patches.sh] Changing Dovecot LMTP service listener from a unix socket to TCP on port 24"
sedfile -i \
  -e "s|unix_listener lmtp|inet_listener lmtp|" \
  -e "s|mode = 0660|address = 0.0.0.0|" \
  -e "s|group = postfix|port = 24|" \
  /etc/dovecot/conf.d/10-master.conf

### Before / After ###

# service lmtp {
#   unix_listener lmtp {
#     mode = 0660
#     group = postfix
#   }
# }

# service lmtp {
#   inet_listener lmtp {
#     address = 0.0.0.0
#     port = 24
#   }
# }
