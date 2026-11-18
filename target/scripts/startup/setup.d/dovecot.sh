#!/bin/bash

# Enables a protocol in the `protocols` block of `dovecot.conf` (`imap`, `pop3` or `sieve`).
function __dovecot_enable_protocol() {
  sedfile -i -E "/^protocols \{/,/^\}/s#^( *${1} =).*#\1 yes#" /etc/dovecot/dovecot.conf
}

function _setup_dovecot() {
  _log 'debug' 'Setting up Dovecot'

  # NOTE: While Postfix will deliver to Dovecot via LMTP (Previously LDA until DMS v2),
  # LDA may be used via other services like Getmail being configured to use /usr/lib/dovecot/deliver
  # when mail does not need to go through Postfix.
  #
  # https://doc.dovecot.org/main/core/summaries/settings.html#postmaster_address
  # https://doc.dovecot.org/main/core/config/delivery/lmtp.html#common-delivery-settings
  # https://doc.dovecot.org/main/core/config/delivery/lda.html#common-delivery-settings
  sedfile -i -r \
    -e "s|^(postmaster_address =).*|\1 ${POSTMASTER_ADDRESS}|" \
    -e "s|^(hostname =).*|\1 ${HOSTNAME}|" \
    /etc/dovecot/dovecot.conf

  # set mail_location according to mailbox format
  case "${DOVECOT_MAILBOX_FORMAT}" in

    ( 'sdbox' | 'mdbox' )
      _log 'trace' "Dovecot ${DOVECOT_MAILBOX_FORMAT} format configured"
      sedfile -i -E \
        -e 's#^(mail_home =).*#\1 /var/mail/%{user | domain}/%{user | username}#' \
        -e "s|^(mail_driver =).*|\1 ${DOVECOT_MAILBOX_FORMAT}|" \
        /etc/dovecot/dovecot.conf

      _log 'trace' 'Enabling cron job for dbox purge'
      mv /etc/cron.d/dovecot-purge.disabled /etc/cron.d/dovecot-purge
      chmod 644 /etc/cron.d/dovecot-purge
      ;;

    ( * )
      _log 'trace' 'Dovecot default format (maildir) configured'
      ;;

  esac

  if [[ ${ENABLE_POP3} -eq 1 || ${ENABLE_IMAP} -eq 1 ]]; then
    sedfile -i -E 's|^(ssl =).*|\1 required|' /etc/dovecot/dovecot.conf
  fi

  if [[ ${ENABLE_POP3} -eq 1 ]]; then
    _log 'debug' 'Enabling POP3 services'
    __dovecot_enable_protocol 'pop3'
  fi

  if [[ ${ENABLE_IMAP} -eq 1 ]]; then
    _log 'debug' 'Enabling IMAP services'
    __dovecot_enable_protocol 'imap'
  fi

  [[ -f /tmp/docker-mailserver/dovecot.cf ]] && cp /tmp/docker-mailserver/dovecot.cf /etc/dovecot/local.conf
}

# The `sieve` plugin is always enabled in DMS, this method handles user supplied sieve scripts + ManageSieve protocol
# NOTE: There is a related post-setup step for this sieve support handled at `_setup_post()` (setup-stack.sh)
# TODO: Improved sieve support may be needed in DMS to support this use-case:
# https://github.com/docker-mailserver/docker-mailserver/issues/3904
# TODO: Change detection support + refactor/DRY this sieve logic:
# https://github.com/orgs/docker-mailserver/discussions/2633#discussioncomment-11622955
function _setup_dovecot_sieve() {
  mkdir -p /usr/lib/dovecot/sieve-{filter,global,pipe}
  mkdir -p /usr/lib/dovecot/sieve-global/{before,after}

  if [[ ${ENABLE_MANAGESIEVE} -eq 1 ]]; then
    _log 'trace' 'Sieve management enabled'
    __dovecot_enable_protocol 'sieve'
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
    return 0
  fi

  cp /etc/dovecot/features/quota.conf /etc/dovecot/conf.d/quota.conf

  local MESSAGE_SIZE_LIMIT_MB=$((POSTFIX_MESSAGE_SIZE_LIMIT / 1000000))
  local MAILBOX_LIMIT_MB=$((POSTFIX_MAILBOX_SIZE_LIMIT / 1000000))

  sedfile -i \
    "s|quota_mail_size =.*|quota_mail_size = ${MESSAGE_SIZE_LIMIT_MB}$([[ ${MESSAGE_SIZE_LIMIT_MB} -eq 0 ]] && echo "" || echo "M")|g" \
    /etc/dovecot/conf.d/quota.conf

  sedfile -i \
    "s|quota_storage_size = .*|quota_storage_size = ${MAILBOX_LIMIT_MB}$([[ ${MAILBOX_LIMIT_MB} -eq 0 ]] && echo "" || echo "M")|g" \
    /etc/dovecot/conf.d/quota.conf

  if [[ -d /tmp/docker-mailserver ]] && [[ ! -f /tmp/docker-mailserver/dovecot-quotas.cf ]]; then
    _log 'trace' "'/tmp/docker-mailserver/dovecot-quotas.cf' is not provided. Using default quotas."
    : >/tmp/docker-mailserver/dovecot-quotas.cf
  fi

  # enable quota policy check in postfix
  sedfile -i -E \
    "s|(reject_unknown_recipient_domain)|\1, check_policy_service inet:localhost:65265|g" \
    /etc/postfix/main.cf
}

function _setup_dovecot_local_user() {
  [[ ${SMTP_ONLY} -eq 1 ]] && return 0
  [[ ${ACCOUNT_PROVISIONER} == 'FILE' ]] || return 0

  _log 'debug' 'Setting up Dovecot Local User'

  cp /etc/dovecot/features/auth-passwdfile.conf /etc/dovecot/conf.d/auth-passwdfile.conf

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

  sedfile -i -E "s|^(listen =).*|\1 ${PROTOCOL}|" /etc/dovecot/dovecot.conf
}
