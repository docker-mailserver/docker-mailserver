#!/bin/bash

# Set up test framework
source assert.sh

# Testing that services are running and pop3 is disabled
assert_raises "docker exec mail ps aux --forest | grep '/usr/lib/postfix/master'" 0
assert_raises "docker exec mail ps aux --forest | grep '/usr/sbin/saslauthd'" 0
assert_raises "docker exec mail ps aux --forest | grep '/usr/sbin/clamd'" 0
assert_raises "docker exec mail ps aux --forest | grep '/usr/sbin/amavisd-new'" 0
assert_raises "docker exec mail ps aux --forest | grep '/usr/sbin/opendkim'" 0
assert_raises "docker exec mail ps aux --forest | grep '/usr/sbin/opendmarc'" 0
assert_raises "docker exec mail ps aux --forest | grep '/usr/lib/courier/courier/courierpop3d'" 1

# Testing services of pop3 container
assert_raises "docker exec mail_pop3 ps aux --forest | grep '/usr/lib/courier/courier/courierpop3d'" 0

# Testing IMAP server
assert_raises "docker exec mail nc -w 1 0.0.0.0 143 | grep '* OK' | grep 'STARTTLS' | grep 'Courier-IMAP ready'" 0
assert_raises "docker exec mail /bin/sh -c 'nc -w 1 0.0.0.0 143 < /tmp/test/auth/imap-auth.txt'" 0

# Testing POP3 server on pop3 container
assert_raises "docker exec mail_pop3 nc -w 1 0.0.0.0 110 | grep '+OK'" 0
assert_raises "docker exec mail_pop3 /bin/sh -c 'nc -w 1 0.0.0.0 110 < /tmp/test/auth/pop3-auth.txt'" 0

# Testing SASL
assert_raises "docker exec mail testsaslauthd -u user2 -r otherdomain.tld -p mypassword | grep 'OK \"Success.\"'" 0
assert_raises "docker exec mail testsaslauthd -u user2 -r otherdomain.tld -p BADPASSWORD | grep 'NO \"authentication failed\"'" 0
assert_raises "docker exec mail /bin/sh -c 'nc -w 1 0.0.0.0 25 < /tmp/test/auth/smtp-auth-plain.txt' | grep 'Authentication successful'"
assert_raises "docker exec mail /bin/sh -c 'nc -w 1 0.0.0.0 25 < /tmp/test/auth/smtp-auth-login.txt' | grep 'Authentication successful'"

# Testing user creation
assert "docker exec mail sasldblistusers2" "user1@localhost.localdomain: userPassword\nuser2@otherdomain.tld: userPassword"
assert "docker exec mail ls -A /var/mail/localhost.localdomain/user1" "cur\nnew\ntmp"
assert "docker exec mail ls -A /var/mail/otherdomain.tld/user2" "cur\nnew\ntmp"

# Testing `vhost` creation
assert "docker exec mail cat /etc/postfix/vhost" "localhost.localdomain\notherdomain.tld"

# Testing that mail is received for existing user
assert_raises "docker exec mail grep 'status=sent (delivered to maildir)' /var/log/mail.log" 0
assert "docker exec mail ls -A /var/mail/localhost.localdomain/user1/new | wc -l" "2"

# Testing that mail is rejected for non existing user
assert_raises "docker exec mail grep '<nouser@localhost.localdomain>: Recipient address rejected: User unknown in virtual mailbox table' /var/log/mail.log" 0

# Testing that mail is received for existing alias
assert_raises "docker exec mail grep 'to=<user1@localhost.localdomain>, orig_to=<alias1@localhost.localdomain>' /var/log/mail.log | grep 'status=sent'" 0

# Testing that mail is redirected for external alias
assert_raises "docker exec mail grep -- '-> <external1@otherdomain.tld>' /var/log/mail.log" 0

# Testing that a SPAM is rejected
assert_raises "docker exec mail grep 'Blocked SPAM' /var/log/mail.log | grep spam@external.tld" 0

# Testing that a Virus is rejected
assert_raises "docker exec mail grep 'Blocked INFECTED' /var/log/mail.log | grep virus@external.tld" 0

# Testing presence of freshclam CRON
assert "docker exec mail crontab -l" "0 1 * * * /usr/bin/freshclam --quiet"

# Testing that log don't display errors
assert_raises "docker exec mail grep 'non-null host address bits in' /var/log/mail.log" 1
assert_raises "docker exec mail grep ': error:' /var/log/mail.log" 1

# Testing that pop3 container log don't display errors
assert_raises "docker exec mail_pop3 grep 'non-null host address bits in' /var/log/mail.log" 1
assert_raises "docker exec mail_pop3 grep ': error:' /var/log/mail.log" 1

# Testing OpenDKIM
assert "docker exec mail cat /etc/opendkim/KeyTable | wc -l" "2"
assert "docker exec mail ls -l /etc/opendkim/keys/ | grep '^d' | wc -l" "2"

# Testing OpenDMARC
assert "docker exec mail cat /etc/opendmarc.conf | grep ^AuthservID | wc -l" "1"
assert "docker exec mail cat /etc/opendmarc.conf | grep ^TrustedAuthservID | wc -l" "1"

# Testing hostname config
assert "docker exec mail cat /etc/mailname" "my-domain.com"

# Ending tests
assert_end 
