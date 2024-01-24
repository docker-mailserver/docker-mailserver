#!/bin/bash

function _setup_saslauthd() {
  _log 'debug' 'Setting up SASLAUTHD'

  # NOTE: It's unlikely this file would already exist,
  # Unlike Dovecot/Postfix LDAP support, this file has no ENV replacement
  # nor does it copy from the DMS config volume to this internal location.
  if [[ ${ACCOUNT_PROVISIONER} == 'LDAP' ]] \
  && [[ ! -f /etc/saslauthd.conf ]]; then
    _log 'trace' 'Creating /etc/saslauthd.conf'
    _create_config_saslauthd
  fi

  sed -i \
    -e "/^[^#].*smtpd_sasl_type.*/s/^/#/g" \
    -e "/^[^#].*smtpd_sasl_path.*/s/^/#/g" \
    /etc/postfix/master.cf

  sed -i \
    -e "/smtpd_sasl_path =.*/d" \
    -e "/smtpd_sasl_type =.*/d" \
    -e "/dovecot_destination_recipient_limit =.*/d" \
    /etc/postfix/main.cf

  gpasswd -a postfix sasl >/dev/null
}

# Generates a config from an ENV template while layering several other sources
# into a single temporary file, used as input into `_cleanse_config` which
# prepares the final output config.
function _create_config_saslauthd() {
  _cleanse_config ':' <(cat 2>/dev/null \
    <(_template_with_env 'LDAP_' /etc/dms/ldap/saslauthd.base) \
    /tmp/docker-mailserver/ldap/saslauthd.conf \
    <(_template_with_env 'SASLAUTHD_' /etc/dms/ldap/saslauthd.tmpl) \
  ) > /etc/saslauthd.conf
}
