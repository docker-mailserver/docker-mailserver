#!/bin/bash


# Set up OpenDKIM & OpenDMARC.
#
# ## Attention
#
# The OpenDKIM milter must come before the OpenDMARC milter in Postfix's#
# `smtpd_milters` milters options.
function _setup_dkim_dmarc
{
  if [[ ${ENABLE_OPENDKIM} -eq 1 ]]
  then
    _log 'debug' 'Setting up DKIM'

    mkdir -p /etc/opendkim/keys/
    touch /etc/opendkim/{SigningTable,TrustedHosts,KeyTable}

    _log 'trace' "Adding OpenDKIM to Postfix's milters"
    postconf 'dkim_milter = inet:localhost:8891'
    # shellcheck disable=SC2016
    sed -i -E                                            \
      -e 's|^(smtpd_milters =.*)|\1 \$dkim_milter|g'     \
      -e 's|^(non_smtpd_milters =.*)|\1 \$dkim_milter|g' \
      /etc/postfix/main.cf

    # check if any keys are available
    if [[ -e /tmp/docker-mailserver/opendkim/KeyTable ]]
    then
      cp -a /tmp/docker-mailserver/opendkim/* /etc/opendkim/
      _log 'trace' "DKIM keys added for: $(find /etc/opendkim/keys/ -maxdepth 1 -type f -printf '%f ')"
      chown -R opendkim:opendkim /etc/opendkim/
      chmod -R 0700 /etc/opendkim/keys/
    else
      _log 'debug' 'OpenDKIM enabled but no DKIM key(s) provided'
    fi

    # setup nameservers parameter from /etc/resolv.conf if not defined
    if ! grep -q '^Nameservers' /etc/opendkim.conf
    then
      local NAMESERVER_IPS
      NAMESERVER_IPS=$(grep '^nameserver' /etc/resolv.conf | awk -F " " '{print $2}' | paste -sd ',' -)
      echo "Nameservers ${NAMESERVER_IPS}" >>/etc/opendkim.conf
      _log 'trace' "Nameservers added to '/etc/opendkim.conf'"
    fi
  fi

  if [[ ${ENABLE_OPENDMARC} -eq 1 ]]
  then
    # TODO when disabling SPF is possible, add a check whether DKIM and SPF is disabled
    #      for DMARC to work, you should have at least one enabled
    #      (see RFC 7489 https://www.rfc-editor.org/rfc/rfc7489#page-24)
    _log 'trace' "Adding OpenDMARC to Postfix's milters"
    postconf 'dmarc_milter = inet:localhost:8893'
    # Make sure to append the OpenDMARC milter _after_ the OpenDKIM milter!
    # shellcheck disable=SC2016
    sed -i -E 's|^(smtpd_milters =.*)|\1 \$dmarc_milter|g' /etc/postfix/main.cf
  fi
}

function _setup_dmarc_hostname
{
  _log 'debug' 'Setting up DMARC'
  sed -i -e \
    "s|^AuthservID.*$|AuthservID          ${HOSTNAME}|g" \
    -e "s|^TrustedAuthservIDs.*$|TrustedAuthservIDs  ${HOSTNAME}|g" \
    /etc/opendmarc.conf
}
