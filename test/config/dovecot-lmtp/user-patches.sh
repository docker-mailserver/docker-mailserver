#!/bin/bash
##
# This user script will be executed between configuration and starting daemons
# To enable it you must save it in your config directory as "user-patches.sh"
##

echo "[user-patches.sh] Adding a TCP listener on port 24 to the Dovecot LMTP service (in addition to the unix socket)"

cat >/etc/dovecot/conf.d/lmtp-tcp.conf << EOF
service lmtp {
  inet_listener lmtp {
    listen = 127.0.0.1
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
#   unix_listener lmtp {
#     mode = 0660
#     group = postfix
#   }
#   inet_listener lmtp {
#     listen = 127.0.0.1
#     port = 24
#   }
# }
