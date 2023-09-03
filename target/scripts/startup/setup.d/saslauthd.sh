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

function _create_config_saslauthd() {
  local SASLAUTHD_LDAP_SERVER=${SASLAUTHD_LDAP_SERVER:=${LDAP_SERVER_HOST}}
  local SASLAUTHD_LDAP_BIND_DN=${SASLAUTHD_LDAP_BIND_DN:=${LDAP_BIND_DN}}
  local SASLAUTHD_LDAP_PASSWORD=${SASLAUTHD_LDAP_PASSWORD:=${LDAP_BIND_PW}}
  local SASLAUTHD_LDAP_SEARCH_BASE=${SASLAUTHD_LDAP_SEARCH_BASE:=${LDAP_SEARCH_BASE}}
  local SASLAUTHD_LDAP_FILTER=${SASLAUTHD_LDAP_FILTER:=(&(uniqueIdentifier=%u)(mailEnabled=TRUE))}
  local SASLAUTHD_LDAP_REFERRALS=${SASLAUTHD_LDAP_REFERRALS:=yes}

  # Generates a config from an ENV template while layering several other sources
  # into a single temporary file, used as input into `_cleanse_config` which
  # prepares the final output config.
  _cleanse_config ':' <(cat 2>/dev/null \
    /tmp/docker-mailserver/ldap/saslauthd.conf \
    <(_template_with_env 'SASLAUTHD_' /etc/dms/ldap/saslauthd.tmpl) \
  ) > /etc/saslauthd.conf
}
