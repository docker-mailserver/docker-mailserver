#!/bin/bash

function _setup_ldap() {
  _log 'debug' 'Setting up LDAP'

  _log 'trace' "Configuring Postfix for LDAP"

  # Configure Postfix settings for LDAP configs in advance:
  postconf \
    'virtual_mailbox_maps = ldap:/etc/postfix/ldap/users.cf' \
    'virtual_mailbox_domains = /etc/postfix/vhost ldap:/etc/postfix/ldap/domains.cf' \
    'virtual_alias_maps = ldap:/etc/postfix/ldap/aliases.cf ldap:/etc/postfix/ldap/groups.cf'

  # Generate Postfix LDAP configs:
  mkdir -p /etc/postfix/ldap
  for QUERY_KIND in 'users' 'groups' 'aliases' 'domains' 'senders'; do
    _create_config_postfix "${QUERY_KIND}"
  done

  _log 'trace' "Configuring Dovecot for LDAP"
  # Default DOVECOT_PASS_FILTER to the same value as DOVECOT_USER_FILTER
  local DOVECOT_PASS_FILTER="${DOVECOT_PASS_FILTER:="${DOVECOT_USER_FILTER}"}"
  _create_config_dovecot

  _log 'trace' 'Enabling Dovecot LDAP authentication'

  sed -i -e '/\!include auth-ldap\.conf\.ext/s/^#//' /etc/dovecot/conf.d/10-auth.conf
  sed -i -e '/\!include auth-passwdfile\.inc/s/^/#/' /etc/dovecot/conf.d/10-auth.conf

  # shellcheck disable=SC2016
  sed -i 's|mydestination = \$myhostname, |mydestination = |' /etc/postfix/main.cf

  return 0
}

# Generates a config from an ENV template while layering several other sources
# into a single temporary file, used as input into `_cleanse_config` which
# prepares the final output config.
function _create_config_dovecot() {
  _cleanse_config '=' <(cat 2>/dev/null \
    <(_template_with_env 'LDAP_' /etc/dms/ldap/dovecot.base) \
    /tmp/docker-mailserver/ldap/dovecot.conf \
    <(_template_with_env 'DOVECOT_' /etc/dms/ldap/dovecot.tmpl) \
  ) > /etc/dovecot/dovecot-ldap.conf.ext
}

function _create_config_postfix() {
local QUERY_KIND=${1:?QUERY_KIND is required in _create_config_postfix}
  local LDAP_CONFIG_FILE="/etc/postfix/ldap/${QUERY_KIND}.cf"

  _cleanse_config '=' <(cat 2>/dev/null \
    <(_template_with_env 'LDAP_' /etc/dms/ldap/postfix.base) \
    "/tmp/docker-mailserver/ldap-${QUERY_KIND}.cf" \
    <(_template_with_env 'POSTFIX_' /etc/dms/ldap/postfix.tmpl) \
    <(_template_with_env "POSTFIX_${QUERY_KIND^^}_" /etc/dms/ldap/postfix.tmpl) \
  ) > "${LDAP_CONFIG_FILE}"

  # Opt-out of generated config if `query_filter` was not configured:
  if ! grep -q '^query_filter =' "${LDAP_CONFIG_FILE}"; then
    _log 'warn' "'${LDAP_CONFIG_FILE}' is missing the 'query_filter' setting - disabling"

    sed -i "s/$(_escape_for_sed "${LDAP_CONFIG_FILE}")//" /etc/postfix/main.cf
  fi
}
