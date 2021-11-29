#! /bin/bash
# Support for Relay Hosts

function _relayhost_default_port_fallback
{
  RELAY_PORT=${RELAY_PORT:-25}
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
  if [[ ! -f /tmp/docker-mailserver/postfix-sasl-password.cf ]] && [[ -z ${RELAY_USER} || -z ${RELAY_PASSWORD} ]]
  then
    _notify 'warn' "No relay auth file found and no default set"
    return 1
  fi

  if [[ -f /tmp/docker-mailserver/postfix-sasl-password.cf ]]
  then
    _notify 'inf' "Adding relay authentication from postfix-sasl-password.cf"

    # add domain-specific auth from config file:
    while read -r LINE
    do
      if ! _is_comment "${LINE}"
      then
        echo "${LINE}" >> /etc/postfix/sasl_passwd
      fi
    done < /tmp/docker-mailserver/postfix-sasl-password.cf
  fi

  # add default relay
  if [[ -n ${RELAY_USER} ]] && [[ -n ${RELAY_PASSWORD} ]]
  then
    # white-space separates value pairs (any length is valid)
    echo "[${RELAY_HOST}]:${RELAY_PORT} ${RELAY_USER}:${RELAY_PASSWORD}" >> /etc/postfix/sasl_passwd
  fi

  _sasl_set_passwd_permissions
}

# Introduced by: https://github.com/docker-mailserver/docker-mailserver/pull/1596
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

# ? --------------------------------------------- Callers

# setup-stack.sh:
function _setup_relayhost
{
  _notify 'task' 'Setting up Postfix Relay Hosts'

  if [[ -n ${DEFAULT_RELAY_HOST} ]]
  then
    _notify 'inf' "Setting default relay host ${DEFAULT_RELAY_HOST} to /etc/postfix/main.cf"
    postconf -e "relayhost = ${DEFAULT_RELAY_HOST}"
  fi

  if [[ -n ${RELAY_HOST} ]]
  then
    _relayhost_default_port_fallback
    _notify 'inf' "Setting up outgoing email relaying via ${RELAY_HOST}:${RELAY_PORT}"

    # Expects `_sasl_passwd_create` was called prior in `setup-stack.sh`
    _relayhost_sasl
    _populate_relayhost_map

    _relayhost_configure_postfix
  fi
}

# check-for-changes.sh:
function _rebuild_relayhost
{
  if [[ -n ${RELAY_HOST} ]]
  then
    _relayhost_default_port_fallback

    # Start from a new `/etc/postfix/sasl_passwd` state:
    _sasl_passwd_create

    _relayhost_sasl
    _populate_relayhost_map
  fi
}
