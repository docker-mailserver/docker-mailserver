#!/usr/bin/env bash
# postsrsd-wrapper.sh, version 0.1.0

DOMAINNAME="$(hostname -d)"
sed -i -e "s/localdomain/$DOMAINNAME/g" /etc/default/postsrsd

/etc/init.d/postsrsd start

