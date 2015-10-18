#!/bin/bash

# Set up test framework
wget -q https://raw.github.com/lehmannro/assert.sh/master/assert.sh
source assert.sh

# Testing user creation
assert "docker exec mail ls -A /var/mail/localhost.localdomain/user1" "cur\nnew\ntmp"
assert "docker exec mail ls /var/mail/otherdomain.tld/user2" "cur\nnew\ntmp"

# Testing that mail is received for existing user
assert_raises "docker exec mail grep 'status=sent (delivered to maildir)' /var/log/mail.log" "false"
assert "docker exec mail ls -A /var/mail/localhost.localdomain/user1/new | wc -l" "       1"

# Ending tests
assert_end 



