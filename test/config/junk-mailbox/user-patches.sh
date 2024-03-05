#!/bin/bash
##
# This user script will be executed between configuration and starting daemons
# To enable it you must save it in your config directory as "user-patches.sh"
##

echo "[user-patches.sh] Adjusting 'Junk' mailbox name to verify special-use flag delivers to modified mailbox folder name"

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
