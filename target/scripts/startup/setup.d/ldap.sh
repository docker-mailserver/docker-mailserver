#!/bin/bash

function _setup_ldap() {
  _log 'debug' 'Setting up LDAP'
  _log 'trace' 'Checking for custom configs'

  for i in 'users' 'groups' 'aliases' 'domains'; do
    local FPATH="/tmp/docker-mailserver/ldap-${i}.cf"
    if [[ -f ${FPATH} ]]; then
      cp "${FPATH}" "/etc/postfix/ldap-${i}.cf"
    fi
  done

  _log 'trace' 'Starting to override configs'

  local FILES=(
    /etc/postfix/ldap-users.cf
    /etc/postfix/ldap-groups.cf
    /etc/postfix/ldap-aliases.cf
    /etc/postfix/ldap-domains.cf
    /etc/postfix/ldap-senders.cf
    /etc/postfix/maps/sender_login_maps.ldap
  )

  for FILE in "${FILES[@]}"; do
    [[ ${FILE} =~ ldap-user ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_USER}"
    [[ ${FILE} =~ ldap-group ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_GROUP}"
    [[ ${FILE} =~ ldap-aliases ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_ALIAS}"
    [[ ${FILE} =~ ldap-domains ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_DOMAIN}"
    [[ ${FILE} =~ ldap-senders ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_SENDERS}"
    [[ -f ${FILE} ]] && _replace_by_env_in_file 'LDAP_' "${FILE}"
  done

  _log 'trace' "Configuring Dovecot LDAP"

  declare -A DOVECOT_LDAP_MAPPING

  DOVECOT_LDAP_MAPPING['DOVECOT_BASE']="${DOVECOT_BASE:="${LDAP_SEARCH_BASE}"}"
  DOVECOT_LDAP_MAPPING['DOVECOT_DN']="${DOVECOT_DN:="${LDAP_BIND_DN}"}"
  DOVECOT_LDAP_MAPPING['DOVECOT_DNPASS']="${DOVECOT_DNPASS:="${LDAP_BIND_PW}"}"
  DOVECOT_LDAP_MAPPING['DOVECOT_URIS']="${DOVECOT_URIS:="${LDAP_SERVER_HOST}"}"

  # Default DOVECOT_PASS_FILTER to the same value as DOVECOT_USER_FILTER
  DOVECOT_LDAP_MAPPING['DOVECOT_PASS_FILTER']="${DOVECOT_PASS_FILTER:="${DOVECOT_USER_FILTER}"}"

  for VAR in "${!DOVECOT_LDAP_MAPPING[@]}"; do
    export "${VAR}=${DOVECOT_LDAP_MAPPING[${VAR}]}"
  done

  _replace_by_env_in_file 'DOVECOT_' '/etc/dovecot/dovecot-ldap.conf.ext'

  _log 'trace' 'Enabling Dovecot LDAP authentication'

  sed -i -e '/\!include auth-ldap\.conf\.ext/s/^#//' /etc/dovecot/conf.d/10-auth.conf
  sed -i -e '/\!include auth-passwdfile\.inc/s/^/#/' /etc/dovecot/conf.d/10-auth.conf

  _log 'trace' "Configuring LDAP"

  if [[ -f /etc/postfix/ldap-users.cf ]]; then
    postconf 'virtual_mailbox_maps = ldap:/etc/postfix/ldap-users.cf'
  else
    _log 'warn' "'/etc/postfix/ldap-users.cf' not found"
  fi

  if [[ -f /etc/postfix/ldap-domains.cf ]]; then
    postconf 'virtual_mailbox_domains = /etc/postfix/vhost, ldap:/etc/postfix/ldap-domains.cf'
  else
    _log 'warn' "'/etc/postfix/ldap-domains.cf' not found"
  fi

  if [[ -f /etc/postfix/ldap-aliases.cf ]] && [[ -f /etc/postfix/ldap-groups.cf ]]; then
    postconf 'virtual_alias_maps = ldap:/etc/postfix/ldap-aliases.cf, ldap:/etc/postfix/ldap-groups.cf'
  else
    _log 'warn' "'/etc/postfix/ldap-aliases.cf' and / or '/etc/postfix/ldap-groups.cf' not found"
  fi

  # shellcheck disable=SC2016
  sed -i 's|mydestination = \$myhostname, |mydestination = |' /etc/postfix/main.cf

  return 0
}
