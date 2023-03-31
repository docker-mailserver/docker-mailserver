#!/bin/bash
##
# This user script will be executed between configuration and starting daemons
# To enable it you must save it in your config directory as "user-patches.sh"
##

echo "[user-patches.sh] Changing Dovecot LMTP service listener from a unix socket to TCP on port 24"

cat >/etc/dovecot/conf.d/lmtp-master.inc << EOF
service lmtp {
  inet_listener lmtp {
    address = 127.0.0.1
    port = 24
  }
}
EOF

### Before / After ###

# service lmtp {
#   unix_listener lmtp {
#     mode = 0660
#     group = postfix
#   }
# }

# service lmtp {
#   inet_listener lmtp {
#     address = 127.0.0.1
#     port = 24
#   }
# }
