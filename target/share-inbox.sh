#!/bin/bash

# $1: The source account name
# $2: The account name of who receives access
# $3, $4 and so on: list of permissions - one of: lookup read write write-seen write-deleted insert post expunge
# Call me like this: share_inbox.sh office bob lookup read

DOMAIN=$(hostname -d)
if [[ "${ENABLE_SHARED_INBOX}" = 0 ]]
then
  echo "You have to enable inbox sharing by means of 'ENABLE_SHARED_INBOX' before actually sharing anything." >&2
  exit 1
fi

if ! grep -q '\.' <<< "${DOMAIN}"
then
  echo "Couldn't detect the target domain - 'hostname -d' returned '${DOMAIN}', which seems to be garbage. Configure the container, so it is aware of its domain" >&2
  exit 1
fi

sharing=$1
shift
shared_to=$1
shift

doveadm acl add -u "${sharing}@${DOMAIN}" 'Inbox' "user=${shared_to}@${DOMAIN}" "$@"
