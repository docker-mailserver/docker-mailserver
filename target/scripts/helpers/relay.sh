#! /bin/bash
# Support for Relay Hosts


# Responsible for these files:
# postfix-sasl-password.cf
# postfix-relaymap.cf
# /etc/postfix/relayhost_map
# /etc/postfix/sasl_passwd
#
# The config syntax uses white-space (any length is valid) to separate values on the same line.
# The table type `texthash` does not need to go through `postmap` after changes.
# It is however sensitive to changes when replacing the file with new content instead of appending.
# `postfix reload` or `supervisorctl restart postfix` should be run to properly apply config (which it is).
# Otherwise use another table type such as `hash` and run `postmap` on the table after modification.
#
# WARNING: Databases (tables above) are rebuilt during change detection. There is a minor chance of
# a lookup occuring during a rebuild of these files that may affect or delay delivery?
# TODO: Should instead perform an atomic operation with a temporary file + `mv` to replace?
# Or switch back to using `hash` table type if plaintext access is not needed (unless retaining file for postmap).
# Either way, plaintext copy is likely accessible if using our supported configs for providing them to the container.


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
    _log 'warn' "No relay auth file found and no default set"
    return 1
  fi

  if [[ -f /tmp/docker-mailserver/postfix-sasl-password.cf ]]
  then
    _log 'trace' "Adding relay authentication from postfix-sasl-password.cf"

    # Add domain-specific auth from config file:
    while read -r LINE
    do
      if ! _is_comment "${LINE}"
      then
        echo "${LINE}" >> /etc/postfix/sasl_passwd
      fi
    done < /tmp/docker-mailserver/postfix-sasl-password.cf

    # Only relevant when providing this user config (unless users append elsewhere too)
    postconf 'smtp_sender_dependent_authentication = yes'
  fi

  # Add an authenticated relay host defined via ENV config:
  if [[ -n ${RELAY_USER} ]] && [[ -n ${RELAY_PASSWORD} ]]
  then
    echo "[${RELAY_HOST}]:${RELAY_PORT} ${RELAY_USER}:${RELAY_PASSWORD}" >> /etc/postfix/sasl_passwd
  fi

  _sasl_set_passwd_permissions

  # Technically if only a single relay host is configured, a `static` lookup table could be used instead?:
  # postconf "smtp_sasl_password_maps = static:${RELAY_USER}:${RELAY_PASSWORD}"
  postconf 'smtp_sasl_password_maps = texthash:/etc/postfix/sasl_passwd'
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

  # Matches lines that are not comments or only white-space:
  local MATCH_VALID='^\s*[^#[:space:]]'

  # This config is mostly compatible with `/etc/postfix/relayhost_map`, but additionally supports
  # not providing a relay host for a sender domain to opt-out of RELAY_HOST? (2nd half of function)
  if [[ -f /tmp/docker-mailserver/postfix-relaymap.cf ]]
  then
    _log 'trace' "Adding relay mappings from postfix-relaymap.cf"

    # Match two values with some white-space between them (eg: `@example.test [relay.service.test]:465`):
    local MATCH_VALUE_PAIR='\S*\s+\S'

    # Copy over lines which are not a comment *and* have a destination.
    sed -n -r "/${MATCH_VALID}${MATCH_VALUE_PAIR}/p" /tmp/docker-mailserver/postfix-relaymap.cf >> /etc/postfix/relayhost_map
  fi

  # Everything below here is to parse `postfix-accounts.cf` and `postfix-virtual.cf`,
  # extracting out the domain parts (value of email address after `@`), and then
  # adding those as mappings to ENV configured RELAY_HOST for lookup in `/etc/postfix/relayhost_map`.
  # Provided `postfix-relaymap.cf` didn't exclude any of the domains,
  # and they don't already exist within `/etc/postfix/relayhost_map`.
  #
  # TODO: Breaking change. Replace this lower half and remove the opt-out feature from `postfix-relaymap.cf`.
  # Leverage `main.cf:relayhost` for setting a default relayhost as it was prior to this feature addition.
  # Any sender domains or addresses that need to opt-out of that default relay-host can either
  # map to a different relay-host, or use a separate transport (needs feature support added).

  # Args: <PRINT_DOMAIN_PART_> <config filepath>
  function _list_domain_parts
  {
    [[ -f $2 ]] && sed -n -r "/${MATCH_VALID}/ ${1}" "${2}"
  }
  # Matches and outputs (capture group via `/\1/p`) the domain part (value of address after `@`) in the config file.
  local PRINT_DOMAIN_PART_ACCOUNTS='s/^[^@|]*@([^\|]+)\|.*$/\1/p'
  local PRINT_DOMAIN_PART_VIRTUAL='s/^\s*[^@[:space:]]*@(\S+)\s.*/\1/p'

  {
    _list_domain_parts "${PRINT_DOMAIN_PART_ACCOUNTS}" /tmp/docker-mailserver/postfix-accounts.cf
    _list_domain_parts "${PRINT_DOMAIN_PART_VIRTUAL}" /tmp/docker-mailserver/postfix-virtual.cf
  } | sort -u | while read -r DOMAIN_PART
  do
    # DOMAIN_PART not already present in `/etc/postfix/relayhost_map`, and not listed as a relay opt-out domain in `postfix-relaymap.cf`
    # `^@${DOMAIN_PART}\b` - To check for existing entry, the `\b` avoids accidental partial matches on similar domain parts.
    # `^\s*@${DOMAIN_PART}\s*$` - Matches line with only a domain part (eg: @example.test) to avoid including a mapping for those domains to the RELAY_HOST.
    if ! grep -q -e "^@${DOMAIN_PART}\b" /etc/postfix/relayhost_map && ! grep -qs -e "^\s*@${DOMAIN_PART}\s*$" /tmp/docker-mailserver/postfix-relaymap.cf
    then
      _log 'trace' "Adding relay mapping for ${DOMAIN_PART}"
      echo "@${DOMAIN_PART}    [${RELAY_HOST}]:${RELAY_PORT}" >> /etc/postfix/relayhost_map
    fi
  done

  postconf 'sender_dependent_relayhost_maps = texthash:/etc/postfix/relayhost_map'
}

function _relayhost_configure_postfix
{
  postconf -e \
    "smtp_sasl_auth_enable = yes" \
    "smtp_sasl_security_options = noanonymous" \
    "smtp_tls_security_level = encrypt"
}

function _setup_relayhost
{
  _log 'debug' 'Setting up Postfix Relay Hosts'

  if [[ -n ${DEFAULT_RELAY_HOST} ]]
  then
    _log 'trace' "Setting default relay host ${DEFAULT_RELAY_HOST} to /etc/postfix/main.cf"
    postconf -e "relayhost = ${DEFAULT_RELAY_HOST}"
  fi

  if [[ -n ${RELAY_HOST} ]]
  then
    _relayhost_default_port_fallback
    _log 'trace' "Setting up outgoing email relaying via ${RELAY_HOST}:${RELAY_PORT}"

    # Expects `_sasl_passwd_create` was called prior in `setup-stack.sh`
    _relayhost_sasl
    _populate_relayhost_map

    _relayhost_configure_postfix
  fi
}

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
