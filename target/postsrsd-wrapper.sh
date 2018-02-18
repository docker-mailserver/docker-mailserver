#!/usr/bin/env bash
# postsrsd-wrapper.sh, version 0.2.0

DOMAINNAME="$(hostname -d)"
sed -i -e "s/localdomain/$DOMAINNAME/g" /etc/default/postsrsd

if [ -n "$SRS_EXCLUDE_DOMAINS" ]; then
  sed -i -e "s/^#\?SRS_EXCLUDE_DOMAINS=.*$/SRS_EXCLUDE_DOMAINS=$SRS_EXCLUDE_DOMAINS/g" /etc/default/postsrsd
fi

/etc/init.d/postsrsd start

