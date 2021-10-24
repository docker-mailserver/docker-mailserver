#! /bin/bash
# Support for Relay Hosts

function _relayhost_default_port_fallback
{
  [[ -z ${RELAY_PORT} ]] && RELAY_PORT=25
}

# setup /etc/postfix/sasl_passwd
# --
# @domain1.com        postmaster@domain1.com:your-password-1
# @domain2.com        postmaster@domain2.com:your-password-2
# @domain3.com        postmaster@domain3.com:your-password-3
#
# [smtp.mailgun.org]:587  postmaster@domain2.com:your-password-2
function _relayhost_sasl
{
  if [[ -f /tmp/docker-mailserver/postfix-sasl-password.cf ]]
  then
    _notify 'inf' "Adding relay authentication from postfix-sasl-password.cf"

    while read -r LINE
    do
      if ! echo "${LINE}" | grep -q -e "^\s*#"
      then
        echo "${LINE}" >> /etc/postfix/sasl_passwd
      fi
    done < /tmp/docker-mailserver/postfix-sasl-password.cf
  fi

  # add default relay
  if [[ -n ${RELAY_USER} ]] && [[ -n ${RELAY_PASSWORD} ]]
  then
    # 2 tabs of white-space used between value pairs for visual alignment, not a requirement:
    echo "[${RELAY_HOST}]:${RELAY_PORT}		${RELAY_USER}:${RELAY_PASSWORD}" >> /etc/postfix/sasl_passwd
  fi

  if [[ ! -f /tmp/docker-mailserver/postfix-sasl-password.cf ]] && [[ -z ${RELAY_USER} || -z ${RELAY_PASSWORD} ]]
  then
    _notify 'warn' "No relay auth file found and no default set"
  fi
}

# setup /etc/postfix/relayhost_map
# --
# @domain1.com        [smtp.mailgun.org]:587
# @domain2.com        [smtp.mailgun.org]:587
# @domain3.com        [smtp.mailgun.org]:587
function _populate_relayhost_map
{
  # Create the relayhost_map config file:
  : >/etc/postfix/relayhost_map
  chown root:root /etc/postfix/relayhost_map
  chmod 0600 /etc/postfix/relayhost_map

  if [[ -f /tmp/docker-mailserver/postfix-relaymap.cf ]]
  then
    _notify 'inf' "Adding relay mappings from postfix-relaymap.cf"
    # keep lines which are not a comment *and* have a destination.
    sed -n '/^\s*[^#[:space:]]\S*\s\+\S/p' /tmp/docker-mailserver/postfix-relaymap.cf >> /etc/postfix/relayhost_map
  fi

  {
    # note: won't detect domains when lhs has spaces (but who does that?!)
    sed -n '/^\s*[^#[:space:]]/ s/^[^@|]*@\([^|]\+\)|.*$/\1/p' /tmp/docker-mailserver/postfix-accounts.cf

    [ -f /tmp/docker-mailserver/postfix-virtual.cf ] && sed -n '/^\s*[^#[:space:]]/ s/^\s*[^@[:space:]]*@\(\S\+\)\s.*/\1/p' /tmp/docker-mailserver/postfix-virtual.cf
  } | while read -r DOMAIN
  do
    # DOMAIN not already present *and* not ignored
    if ! grep -q -e "^@${DOMAIN}\b" /etc/postfix/relayhost_map && ! grep -qs -e "^\s*@${DOMAIN}\s*$" /tmp/docker-mailserver/postfix-relaymap.cf
    then
      _notify 'inf' "Adding relay mapping for ${DOMAIN}"
      # shellcheck disable=SC2153
      echo "@${DOMAIN}    [${RELAY_HOST}]:${RELAY_PORT}" >> /etc/postfix/relayhost_map
    fi
  done
}

function _relayhost_configure_postfix
{
  postconf -e \
    "smtp_sasl_auth_enable = yes" \
    "smtp_sasl_security_options = noanonymous" \
    "smtp_sasl_password_maps = texthash:/etc/postfix/sasl_passwd" \
    "smtp_tls_security_level = encrypt" \
    "smtp_tls_note_starttls_offer = yes" \
    "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt" \
    "sender_dependent_relayhost_maps = texthash:/etc/postfix/relayhost_map" \
    "smtp_sender_dependent_authentication = yes"
}
