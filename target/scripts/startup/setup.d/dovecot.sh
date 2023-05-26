#!/bin/bash

function _setup_dovecot() {
  _log 'debug' 'Setting up Dovecot'

  cp -a /usr/share/dovecot/protocols.d /etc/dovecot/
  # disable pop3 (it will be eventually enabled later in the script, if requested)
  mv /etc/dovecot/protocols.d/pop3d.protocol /etc/dovecot/protocols.d/pop3d.protocol.disab
  mv /etc/dovecot/protocols.d/managesieved.protocol /etc/dovecot/protocols.d/managesieved.protocol.disab
  sed -i -e 's|#ssl = yes|ssl = yes|g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's|#port = 993|port = 993|g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's|#port = 995|port = 995|g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's|#ssl = yes|ssl = required|g' /etc/dovecot/conf.d/10-ssl.conf
  sed -i 's|^postmaster_address = .*$|postmaster_address = '"${POSTMASTER_ADDRESS}"'|g' /etc/dovecot/conf.d/15-lda.conf

  if ! grep -q -E '^stats_writer_socket_path=' /etc/dovecot/dovecot.conf; then
    printf '\n%s\n' 'stats_writer_socket_path=' >>/etc/dovecot/dovecot.conf
  fi

  # set mail_location according to mailbox format
  case "${DOVECOT_MAILBOX_FORMAT}" in

    ( 'sdbox' | 'mdbox' )
      _log 'trace' "Dovecot ${DOVECOT_MAILBOX_FORMAT} format configured"
      sedfile -i -E "s|^(mail_home =).*|\1 /var/mail/%d/%n|" /etc/dovecot/conf.d/10-mail.conf
      sedfile -i -E \
        "s|^(mail_location =).*|\1 ${DOVECOT_MAILBOX_FORMAT}:/var/mail/%d/%n|" \
        /etc/dovecot/conf.d/10-mail.conf
      _log 'trace' 'Enabling cron job for dbox purge'
      mv /etc/cron.d/dovecot-purge.disabled /etc/cron.d/dovecot-purge
      chmod 644 /etc/cron.d/dovecot-purge
      ;;

    ( * )
      _log 'trace' 'Dovecot default format (maildir) configured'
      ;;

  esac

  if [[ ${ENABLE_POP3} -eq 1 ]]; then
    _log 'debug' 'Enabling POP3 services'
    mv /etc/dovecot/protocols.d/pop3d.protocol.disab /etc/dovecot/protocols.d/pop3d.protocol
  fi

  [[ -f /tmp/docker-mailserver/dovecot.cf ]] && cp /tmp/docker-mailserver/dovecot.cf /etc/dovecot/local.conf
}

function _setup_dovecot_sieve() {
  mkdir -p /usr/lib/dovecot/sieve-{filter,global,pipe}
  mkdir -p /usr/lib/dovecot/sieve-global/{before,after}

  # enable Managesieve service by setting the symlink
  # to the configuration file Dovecot will actually find
  if [[ ${ENABLE_MANAGESIEVE} -eq 1 ]]; then
    _log 'trace' 'Sieve management enabled'
    mv /etc/dovecot/protocols.d/managesieved.protocol.disab /etc/dovecot/protocols.d/managesieved.protocol
  fi

  if [[ -d /tmp/docker-mailserver/sieve-filter ]]; then
    cp /tmp/docker-mailserver/sieve-filter/* /usr/lib/dovecot/sieve-filter/
  fi
  if [[ -d /tmp/docker-mailserver/sieve-pipe ]]; then
    cp /tmp/docker-mailserver/sieve-pipe/* /usr/lib/dovecot/sieve-pipe/
  fi

  if [[ -f /tmp/docker-mailserver/before.dovecot.sieve ]]; then
    cp \
      /tmp/docker-mailserver/before.dovecot.sieve \
      /usr/lib/dovecot/sieve-global/before/50-before.dovecot.sieve
    sievec /usr/lib/dovecot/sieve-global/before/50-before.dovecot.sieve
  fi
  if [[ -f /tmp/docker-mailserver/after.dovecot.sieve ]]; then
    cp \
      /tmp/docker-mailserver/after.dovecot.sieve \
      /usr/lib/dovecot/sieve-global/after/50-after.dovecot.sieve
    sievec /usr/lib/dovecot/sieve-global/after/50-after.dovecot.sieve
  fi

  chown dovecot:root -R /usr/lib/dovecot/sieve-*
  find /usr/lib/dovecot/sieve-*             -type d -exec chmod 755 {} +
  find /usr/lib/dovecot/sieve-{filter,pipe} -type f -exec chmod +x {} +
}

function _setup_dovecot_quota() {
  _log 'debug' 'Setting up Dovecot quota'

  # Dovecot quota is disabled when using LDAP or SMTP_ONLY or when explicitly disabled.
  if [[ ${ACCOUNT_PROVISIONER} != 'FILE' ]] || [[ ${SMTP_ONLY} -eq 1 ]] || [[ ${ENABLE_QUOTAS} -eq 0 ]]; then
    # disable dovecot quota in docevot confs
    if [[ -f /etc/dovecot/conf.d/90-quota.conf ]]; then
      mv /etc/dovecot/conf.d/90-quota.conf /etc/dovecot/conf.d/90-quota.conf.disab
      sed -i \
        "s|mail_plugins = \$mail_plugins quota|mail_plugins = \$mail_plugins|g" \
        /etc/dovecot/conf.d/10-mail.conf
      sed -i \
        "s|mail_plugins = \$mail_plugins imap_quota|mail_plugins = \$mail_plugins|g" \
        /etc/dovecot/conf.d/20-imap.conf
    fi

    # disable quota policy check in postfix
    sed -i "s|check_policy_service inet:localhost:65265||g" /etc/postfix/main.cf
  else
    if [[ -f /etc/dovecot/conf.d/90-quota.conf.disab ]]; then
      mv /etc/dovecot/conf.d/90-quota.conf.disab /etc/dovecot/conf.d/90-quota.conf
      sed -i \
        "s|mail_plugins = \$mail_plugins|mail_plugins = \$mail_plugins quota|g" \
        /etc/dovecot/conf.d/10-mail.conf
      sed -i \
        "s|mail_plugins = \$mail_plugins|mail_plugins = \$mail_plugins imap_quota|g" \
        /etc/dovecot/conf.d/20-imap.conf
    fi

    local MESSAGE_SIZE_LIMIT_MB=$((POSTFIX_MESSAGE_SIZE_LIMIT / 1000000))
    local MAILBOX_LIMIT_MB=$((POSTFIX_MAILBOX_SIZE_LIMIT / 1000000))

    sed -i \
      "s|quota_max_mail_size =.*|quota_max_mail_size = ${MESSAGE_SIZE_LIMIT_MB}$([[ ${MESSAGE_SIZE_LIMIT_MB} -eq 0 ]] && echo "" || echo "M")|g" \
      /etc/dovecot/conf.d/90-quota.conf

    sed -i \
      "s|quota_rule = \*:storage=.*|quota_rule = *:storage=${MAILBOX_LIMIT_MB}$([[ ${MAILBOX_LIMIT_MB} -eq 0 ]] && echo "" || echo "M")|g" \
      /etc/dovecot/conf.d/90-quota.conf

    if [[ -d /tmp/docker-mailserver ]] && [[ ! -f /tmp/docker-mailserver/dovecot-quotas.cf ]]; then
      _log 'trace' "'/tmp/docker-mailserver/dovecot-quotas.cf' is not provided. Using default quotas."
      : >/tmp/docker-mailserver/dovecot-quotas.cf
    fi

    # enable quota policy check in postfix
    sed -i -E \
      "s|(reject_unknown_recipient_domain)|\1, check_policy_service inet:localhost:65265|g" \
      /etc/postfix/main.cf
  fi
}

function _setup_dovecot_local_user() {
  [[ ${SMTP_ONLY} -eq 1 ]] && return 0
  [[ ${ACCOUNT_PROVISIONER} == 'FILE' ]] || return 0

  _log 'debug' 'Setting up Dovecot Local User'

  if [[ ! -f /tmp/docker-mailserver/postfix-accounts.cf ]]; then
    _log 'trace' "No mail accounts to create - '/tmp/docker-mailserver/postfix-accounts.cf' is missing"
  fi

  function __wait_until_an_account_is_added_or_shutdown() {
    local SLEEP_PERIOD='10'

    for (( COUNTER = 11 ; COUNTER >= 0 ; COUNTER-- )); do
      if [[ $(grep -cE '.+@.+\|' /tmp/docker-mailserver/postfix-accounts.cf 2>/dev/null || printf '%s' '0') -ge 1 ]]; then
        return 0
      else
        _log 'warn' "You need at least one mail account to start Dovecot ($(( ( COUNTER + 1 ) * SLEEP_PERIOD ))s left for account creation before shutdown)"
        sleep "${SLEEP_PERIOD}"
      fi
    done

    _dms_panic__fail_init 'accounts provisioning because no accounts were provided - Dovecot could not be started'
  }

  __wait_until_an_account_is_added_or_shutdown

  _create_accounts
}

function _setup_dovecot_inet_protocols() {
  [[ ${DOVECOT_INET_PROTOCOLS} == 'all' ]] && return 0

  _log 'trace' 'Setting up DOVECOT_INET_PROTOCOLS option'

  local PROTOCOL
  # https://dovecot.org/doc/dovecot-example.conf
  if [[ ${DOVECOT_INET_PROTOCOLS} == "ipv4" ]]; then
    PROTOCOL='*' # IPv4 only
  elif [[ ${DOVECOT_INET_PROTOCOLS} == "ipv6" ]]; then
    PROTOCOL='[::]' # IPv6 only
  else
    # Unknown value, panic.
    _dms_panic__invalid_value 'DOVECOT_INET_PROTOCOLS' "${DOVECOT_INET_PROTOCOLS}"
  fi

  sedfile -i "s|^#listen =.*|listen = ${PROTOCOL}|g" /etc/dovecot/dovecot.conf
}

function _setup_dovecot_dhparam() {
  _setup_dhparam 'Dovecot' '/etc/dovecot/dh.pem'
}

function _setup_dovecot_hostname() {
  _log 'debug' 'Applying hostname to Dovecot'
  sed -i "s|^#hostname =.*$|hostname = '${HOSTNAME}'|g" /etc/dovecot/conf.d/15-lda.conf
}
