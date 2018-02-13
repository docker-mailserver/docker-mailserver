#!/bin/sh

# use this line to learn user specific ham
# exec /usr/bin/sa-learn --ham --dbpath /var/mail-state/lib-amavis/.spamassassin-${1}
exec /usr/bin/sa-learn --ham --dbpath /var/mail-state/lib-amavis/.spamassassin
