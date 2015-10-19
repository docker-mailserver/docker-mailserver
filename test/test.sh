#!/bin/bash

# Set up test framework
wget -q https://raw.github.com/lehmannro/assert.sh/master/assert.sh
source assert.sh

# Testing that services are running
assert_raises "docker exec mail ps aux --forest | grep '/usr/lib/postfix/master'" "true"
assert_raises "docker exec mail ps aux --forest | grep '/usr/sbin/saslauthd'" "true"
assert_raises "docker exec mail ps aux --forest | grep '/usr/sbin/clamd'" "true"
assert_raises "docker exec mail ps aux --forest | grep '/usr/sbin/amavisd-new'" "true"

# Testing user creation
assert "docker exec mail ls -A /var/mail/localhost.localdomain/user1" "cur\nnew\ntmp"
assert "docker exec mail ls -A /var/mail/otherdomain.tld/user2" "cur\nnew\ntmp"

# Testing that mail is received for existing user
assert_raises "docker exec mail grep 'status=sent (delivered to maildir)' /var/log/mail.log" "false"
assert "docker exec mail ls -A /var/mail/localhost.localdomain/user1/new | wc -l" "1"

# Testing presence of freshclam CRON
assert "docker exec mail crontab -l" "0 1 * * * /usr/bin/freshclam --quiet"

# Testing that log don't display errors
assert_raises "docker exec mail grep 'non-null host address bits in' /var/log/mail.log" "false"
assert_raises "docker exec mail grep ': error:' /var/log/mail.log" "false"

# Ending tests
assert_end 
