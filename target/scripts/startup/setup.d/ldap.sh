#!/bin/bash

function _setup_ldap() {
  _log 'debug' 'Setting up LDAP'

  _log 'trace' "Configuring Postfix for LDAP"
  mkdir -p /etc/postfix/ldap

  # Generate Postfix LDAP configs:
  for QUERY_KIND in 'users' 'groups' 'aliases' 'domains' 'senders'; do
    # NOTE: Presently, only `query_filter` is supported for individually targeting:
    case "${QUERY_KIND}" in
      ( 'users' )
        export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_USER}"
        ;;

      ( 'groups' )
        export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_GROUP}"
        ;;

      ( 'aliases' )
        export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_ALIAS}"
        ;;

      ( 'domains' )
        export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_DOMAIN}"
        ;;

      ( 'senders' )
        export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_SENDERS}"
        ;;
    esac

    _create_config_postfix "${QUERY_KIND}"
  done

  _log 'trace' "Configuring Dovecot for LDAP"
  # Default DOVECOT_PASS_FILTER to the same value as DOVECOT_USER_FILTER
  local DOVECOT_PASS_FILTER="${DOVECOT_PASS_FILTER:="${DOVECOT_USER_FILTER}"}"
  _create_config_dovecot

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

# NOTE: Only relies on the `LDAP_` prefix, presently assigned a `POSTFIX_` prefix.
function _create_config_postfix() {
  local QUERY_KIND=${1}

  _cleanse_config '=' <(cat 2>/dev/null \
    /etc/dms/ldap/postfix.base \
    "/tmp/docker-mailserver/ldap-${QUERY_KIND}.cf" \
    <(_template_with_env 'LDAP_' /etc/dms/ldap/postfix.tmpl) \
  ) > "/etc/postfix/ldap-${QUERY_KIND}.cf"
}
