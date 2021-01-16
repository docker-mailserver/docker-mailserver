#! /bin/bash

# Report a quota usage warning to an user

PERCENT="${1}"
USER="${2}"
DOMAIN="${3}"

cat << EOF | /usr/lib/dovecot/dovecot-lda -d "${USER}" -o "plugin/quota=maildir:User quota:noenforcing"
From: postmaster@${DOMAIN}
Subject: quota warning

Your mailbox is now ${PERCENT}% full.
EOF
