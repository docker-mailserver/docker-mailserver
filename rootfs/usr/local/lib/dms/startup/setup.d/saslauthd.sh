#!/bin/bash

function _setup_saslauthd() {
  _log 'debug' 'Setting up SASLAUTHD'

  # NOTE: It's unlikely this file would already exist,
  # Unlike Dovecot/Postfix LDAP support, this file has no ENV replacement
  # nor does it copy from the DMS config volume to this internal location.
  if [[ ${ACCOUNT_PROVISIONER} == 'LDAP' ]] \
  && [[ ! -f /etc/saslauthd.conf ]]; then
    _log 'trace' 'Creating /etc/saslauthd.conf'

    # Create a config based on ENV
    sed '/^.*: $/d'> /etc/saslauthd.conf << EOF
ldap_servers: ${SASLAUTHD_LDAP_SERVER:=${LDAP_SERVER_HOST}}
ldap_auth_method: ${SASLAUTHD_LDAP_AUTH_METHOD:=bind}
ldap_bind_dn: ${SASLAUTHD_LDAP_BIND_DN:=${LDAP_BIND_DN}}
ldap_bind_pw: ${SASLAUTHD_LDAP_PASSWORD:=${LDAP_BIND_PW}}
ldap_search_base: ${SASLAUTHD_LDAP_SEARCH_BASE:=${LDAP_SEARCH_BASE}}
ldap_filter: ${SASLAUTHD_LDAP_FILTER:=(&(uniqueIdentifier=%u)(mailEnabled=TRUE))}
ldap_start_tls: ${SASLAUTHD_LDAP_START_TLS:=no}
ldap_tls_check_peer: ${SASLAUTHD_LDAP_TLS_CHECK_PEER:=no}
ldap_tls_cacert_file: ${SASLAUTHD_LDAP_TLS_CACERT_FILE}
ldap_tls_cacert_dir: ${SASLAUTHD_LDAP_TLS_CACERT_DIR}
ldap_password_attr: ${SASLAUTHD_LDAP_PASSWORD_ATTR}
ldap_mech: ${SASLAUTHD_LDAP_MECH}
ldap_referrals: yes
log_level: 10
EOF
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
