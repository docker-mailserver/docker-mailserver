#!/bin/bash

# Enable GTUBE test patterns so we can properly check whether
# Rspamd is rejecting mail, adding headers, etc.
#
# We do not use `custom-commands.conf` because this a feature
# we are testing too.
echo 'gtube_patterns = "all"' >>/etc/rspamd/local.d/options.inc

# We want Dovecot to be very detailed about what it is doing,
# specifically for Sieve because we need to check whether the
# Sieve scripts are executed so Rspamd is trained when using
# `RSPAMD_LEARN=1`.
echo 'mail_debug = yes' >>/etc/dovecot/dovecot.conf
sed -i -E '/^}/d' /etc/dovecot/conf.d/90-sieve.conf
echo -e '\n  sieve_trace_debug = yes\n}' >>/etc/dovecot/conf.d/90-sieve.conf
