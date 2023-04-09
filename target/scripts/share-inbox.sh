#!/bin/bash

# $1: The source account name
# $2: The account name of who receives access
# $3, $4 and so on: list of permissions - one of: lookup read write write-seen write-deleted insert post expunge
# Call me like this: share_inbox.sh office bob lookup read

DOMAIN=$(hostname -d)
if [[ "${DOVECOT_ENABLE_INBOX_SHARING}" = 0 ]]
then
  echo "You have to enable inbox sharing by means of 'DOVECOT_ENABLE_INBOX_SHARING' before actually sharing anything." >&2
  exit 1
fi

if ! grep -q '\.' <<< "${DOMAIN}"
then
  echo "Couldn't detect the target domain - 'hostname -d' returned '${DOMAIN}', which seems to be garbage. Configure the container, so it is aware of its domain" >&2
  exit 1
fi

SHARING=$1
shift
SHARED_TO=$1
shift

doveadm acl add -u "${SHARING}@${DOMAIN}" 'Inbox' "user=${SHARED_TO}@${DOMAIN}" "$@"
