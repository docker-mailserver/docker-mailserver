#!/bin/bash

# Set up test framework
wget -q https://raw.github.com/lehmannro/assert.sh/master/assert.sh -O assert.sh
source assert.sh

# Testing that services are running
assert_raises "docker exec mail ps aux --forest | grep '/usr/lib/postfix/master'" 0
assert_raises "docker exec mail ps aux --forest | grep '/usr/sbin/saslauthd'" 0
assert_raises "docker exec mail ps aux --forest | grep '/usr/sbin/clamd'" 0
assert_raises "docker exec mail ps aux --forest | grep '/usr/sbin/amavisd-new'" 0

# Testing IMAP server
assert_raises "docker exec mail nc -w 1 0.0.0.0 143 | grep '* OK' | grep 'STARTTLS' | grep 'Courier-IMAP ready'" 0
assert_raises "docker exec mail /bin/sh -c 'nc -w 1 0.0.0.0 143 < /tmp/test/email-templates/test-imap.txt'" 0

# Testing user creation
assert "docker exec mail sasldblistusers2" "user1@localhost.localdomain: userPassword\nuser2@otherdomain.tld: userPassword"
assert "docker exec mail ls -A /var/mail/localhost.localdomain/user1" "cur\nnew\ntmp"
assert "docker exec mail ls -A /var/mail/otherdomain.tld/user2" "cur\nnew\ntmp"

# Testing `vhost` creation
assert "docker exec mail cat /etc/postfix/vhost" "localhost.localdomain\notherdomain.tld"

# Testing that mail is received for existing user
assert_raises "docker exec mail grep 'status=sent (delivered to maildir)' /var/log/mail.log" 0
assert "docker exec mail ls -A /var/mail/localhost.localdomain/user1/new | wc -l | sed -e 's/^[ \t]*//'" "2"

# Testing that mail is rejected for non existing user
assert_raises "docker exec mail grep '<nouser@localhost.localdomain>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail.log" 0

# Testing that mail is received for existing alias
assert_raises "docker exec mail grep 'to=<user1@localhost.localdomain>, orig_to=<alias1@localhost.localdomain>' /var/log/mail.log | grep 'status=sent'" 0

# Testing that mail is redirected for external alias
assert_raises "docker exec mail grep -- '-> <external1@otherdomain.tld>' /var/log/mail.log" 0

# Testing that a SPAM is rejected
assert_raises "docker exec mail grep 'Blocked SPAM' /var/log/mail.log | grep spam@external.tld"

# Testing that a Virus is rejected
assert_raises "docker exec mail grep 'Blocked INFECTED' /var/log/mail.log | grep virus@external.tld"

# Testing presence of freshclam CRON
assert "docker exec mail crontab -l" "0 1 * * * /usr/bin/freshclam --quiet"

# Testing that log don't display errors
assert_raises "docker exec mail grep 'non-null host address bits in' /var/log/mail.log" 1
assert_raises "docker exec mail grep ': error:' /var/log/mail.log" 1

# Ending tests
assert_end 
