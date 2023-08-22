#!/bin/bash

# Set up OpenDKIM
#
# ## Attention
#
# The OpenDKIM milter must come before the OpenDMARC milter in Postfix's
# `smtpd_milters` milters options.
function _setup_opendkim() {
  if [[ ${ENABLE_OPENDKIM} -eq 1 ]]; then
    _log 'debug' 'Configuring DKIM'

    mkdir -p /etc/opendkim/keys/
    touch /etc/opendkim/{SigningTable,TrustedHosts,KeyTable}

    _log 'trace' "Adding OpenDKIM to Postfix's milters"
    postconf 'dkim_milter = inet:localhost:8891'
    # shellcheck disable=SC2016
    _add_to_or_update_postfix_main 'smtpd_milters' '$dkim_milter'
    # shellcheck disable=SC2016
    _add_to_or_update_postfix_main 'non_smtpd_milters' '$dkim_milter'

    # check if any keys are available
    if [[ -e /tmp/docker-mailserver/opendkim/KeyTable ]]; then
      cp -a /tmp/docker-mailserver/opendkim/* /etc/opendkim/
      _log 'trace' "DKIM keys added for: $(find /etc/opendkim/keys/ -maxdepth 1 -type f -printf '%f ')"
      chown -R opendkim:opendkim /etc/opendkim/
      chmod -R 0700 /etc/opendkim/keys/
    else
      _log 'debug' 'OpenDKIM enabled but no DKIM key(s) provided'
    fi

    # setup nameservers parameter from /etc/resolv.conf if not defined
    if ! grep -q '^Nameservers' /etc/opendkim.conf; then
      local NAMESERVER_IPS
      NAMESERVER_IPS=$(grep '^nameserver' /etc/resolv.conf | awk -F " " '{print $2}' | paste -sd ',' -)
      echo "Nameservers ${NAMESERVER_IPS}" >>/etc/opendkim.conf
      _log 'trace' "Nameservers added to '/etc/opendkim.conf'"
    fi
  else
    # Even though we do nothing here and the message suggests we perform some action, the
    # message is due to the default value being `1`, i.e. enabled. If the default were `0`,
    # we could have said `OpenDKIM is disabled`, but we need to make it uniform with all
    # other functions.
    _log 'debug' 'Disabling OpenDKIM'
  fi
}

# Set up OpenDMARC
#
# ## Attention
#
# The OpenDMARC milter must come after the OpenDKIM milter in Postfix's
# `smtpd_milters` milters options.
function _setup_opendmarc() {
  if [[ ${ENABLE_OPENDMARC} -eq 1 ]]; then
    # TODO When disabling SPF is possible, add a check whether DKIM and SPF is disabled
    #      for DMARC to work, you should have at least one enabled
    #      (see RFC 7489 https://www.rfc-editor.org/rfc/rfc7489#page-24)
    _log 'debug' 'Configuring OpenDMARC'

    _log 'trace' "Adding OpenDMARC to Postfix's milters"
    postconf 'dmarc_milter = inet:localhost:8893'
    # Make sure to append the OpenDMARC milter _after_ the OpenDKIM milter!
    # shellcheck disable=SC2016
    _add_to_or_update_postfix_main 'smtpd_milters' '$dmarc_milter'

    sed -i \
      -e "s|^AuthservID.*$|AuthservID          ${HOSTNAME}|g" \
      -e "s|^TrustedAuthservIDs.*$|TrustedAuthservIDs  ${HOSTNAME}|g" \
      /etc/opendmarc.conf
  else
    # Even though we do nothing here and the message suggests we perform some action, the
    # message is due to the default value being `1`, i.e. enabled. If the default were `0`,
    # we could have said `OpenDKIM is disabled`, but we need to make it uniform with all
    # other functions.
    _log 'debug' 'Disabling OpenDMARC'
  fi
}

# Configures the SPF check inside Postfix's configuration via policyd-spf. When
# using Rspamd, you will likely want to turn that off.
function _setup_policyd_spf() {
  if [[ ${ENABLE_POLICYD_SPF} -eq 1 ]]; then
    _log 'debug' 'Configuring policyd-spf'
    cat >>/etc/postfix/master.cf <<EOF

policyd-spf    unix  -       n       n       -       0       spawn
    user=policyd-spf argv=/usr/bin/policyd-spf
EOF

    # SPF policy settings
    postconf 'policyd-spf_time_limit = 3600'
    sedfile -i -E \
      's|^(smtpd_recipient_restrictions.*reject_unauth_destination)(.*)|\1, check_policy_service unix:private/policyd-spf\2|' \
      /etc/postfix/main.cf
  else
    _log 'debug' 'Disabling policyd-spf'
  fi
}
