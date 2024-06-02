#!/bin/bash

function _setup_spoof_protection() {
  if [[ ${SPOOF_PROTECTION} -eq 1 ]]; then
    _log 'trace' 'Enabling and configuring spoof protection'

    if [[ ${ACCOUNT_PROVISIONER} == 'LDAP' ]]; then
      if [[ -z ${LDAP_QUERY_FILTER_SENDERS} ]]; then
        postconf 'smtpd_sender_login_maps = ldap:/etc/postfix/ldap-users.cf ldap:/etc/postfix/ldap-aliases.cf ldap:/etc/postfix/ldap-groups.cf'
      else
        postconf 'smtpd_sender_login_maps = ldap:/etc/postfix/ldap-senders.cf'
      fi
    else
      # NOTE: This file is always created at startup, it potentially has content added.
      # TODO: From section: "SPOOF_PROTECTION=1 handling for smtpd_sender_login_maps"
      # https://github.com/docker-mailserver/docker-mailserver/issues/2819#issue-1402114383
      if [[ -f /etc/postfix/regexp && -f /etc/postfix/regexp-send-only ]]; then
        postconf 'smtpd_sender_login_maps = unionmap:{ texthash:/etc/postfix/virtual, hash:/etc/aliases, pcre:/etc/postfix/maps/sender_login_maps.pcre, pcre:/etc/postfix/regexp, pcre:/etc/postfix/regexp-send-only }'
      elif [[ -f /etc/postfix/regexp-send-only ]]; then
        postconf 'smtpd_sender_login_maps = unionmap:{ texthash:/etc/postfix/virtual, hash:/etc/aliases, pcre:/etc/postfix/maps/sender_login_maps.pcre, pcre:/etc/postfix/regexp-send-only }'
      elif [[ -f /etc/postfix/regexp ]]; then
        postconf 'smtpd_sender_login_maps = unionmap:{ texthash:/etc/postfix/virtual, hash:/etc/aliases, pcre:/etc/postfix/maps/sender_login_maps.pcre, pcre:/etc/postfix/regexp }'
      else
        postconf 'smtpd_sender_login_maps = texthash:/etc/postfix/virtual, hash:/etc/aliases, pcre:/etc/postfix/maps/sender_login_maps.pcre'
      fi
    fi
  else
    _log 'debug' 'Spoof protection is disabled'
    # shellcheck disable=SC2016
    postconf 'mua_sender_restrictions = $dms_smtpd_sender_restrictions'
  fi
}
