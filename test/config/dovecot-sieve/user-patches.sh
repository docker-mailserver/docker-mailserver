#!/bin/bash
##
# This user script will be executed between configuration and starting daemons
# To enable it you must save it in your config directory as "user-patches.sh"
##

echo "[user-patches.sh] Adding a global (before) Sieve script to verify that all scripts in the Sieve directory are run"

cat >/usr/lib/dovecot/sieve-global/before/60-drop-in.sieve << EOF
require ["fileinto", "copy", "mailbox"];

if address :contains ["From"] "spam@spam.com" {
  fileinto :copy :create "INBOX.drop-in";
}
EOF

sievec /usr/lib/dovecot/sieve-global/before/60-drop-in.sieve
chown dovecot:root /usr/lib/dovecot/sieve-global/before/60-drop-in.{sieve,svbin}
