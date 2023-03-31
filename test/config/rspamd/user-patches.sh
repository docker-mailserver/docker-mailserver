#!/bin/bash

cat >/etc/rspamd/override.d/testmodule_complicated.conf << EOF
complicated {
    anOption = someValue;
}
EOF

echo "enable_test_patterns = true;" >>/etc/rspamd/local.d/options.inc

echo 'mail_debug = yes' >>/etc/dovecot/dovecot.conf
sed -i -E '/^}/d' /etc/dovecot/conf.d/90-sieve.conf
echo -e 'sieve_trace_debug = yes\n}' >>/etc/dovecot/conf.d/90-sieve.conf
