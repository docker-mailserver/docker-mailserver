#!/bin/bash
##
# This user script will be executed between configuration and starting daemons
# To enable it you must save it in your config directory as "user-patches.sh"
##

echo "[user-patches.sh] Adjusting 'Junk' mailbox name to verify delivery to Junk mailbox based on special-use flag instead of mailbox's name"

sed -i -e 's/mailbox Junk/mailbox Spam/' /etc/dovecot/conf.d/15-mailboxes.conf

### Before / After ###

# mailbox Junk {
#   auto = subscribe
#   special_use = \Junk
# }

# mailbox Spam {
#   auto = subscribe
#   special_use = \Junk
# }
