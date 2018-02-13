#!/bin/sh

# use this line to learn user specific spam
# exec /usr/bin/sa-learn --spam --dbpath /var/mail-state/lib-amavis/.spamassassin-${1}
exec /usr/bin/sa-learn --spam --dbpath /var/mail-state/lib-amavis/.spamassassin
