#!/bin/bash
# Support for Relay Hosts

# Description:
# This helper is responsible for configuring outbound SMTP (delivery) through relay-hosts.
#
# When mail is sent from Postfix, it is considered relaying to that destination (or the next hop).
# By default delivery external of the container would be direct to the MTA of the recipient address (destination).
# Alternatively mail can be indirectly delivered to the destination by routing through a different MTA (relay-host service).
#
# This helper is only concerned with relaying mail from authenticated submission (ports 587 + 465).
# Thus it does not deal with `relay_domains` (which routes through `relay_transport` transport, default: `master.cf:relay`),
# that is intended for forwarding inbound mail (including from port 25) for any permitted domains.

# User Docs:
# https://docker-mailserver.github.io/docker-mailserver/edge/config/advanced/mail-forwarding/relay-hosts/

# Supported `setup` commands:
# setup.sh relay add-auth <domain> <username> [<password>]
# https://github.com/docker-mailserver/docker-mailserver/blob/master/target/bin/addsaslpassword
#
# setup.sh relay add-domain <domain> <host> [<port>]
# https://github.com/docker-mailserver/docker-mailserver/blob/master/target/bin/addrelayhost
#
# setup.sh relay exclude-domain <domain>
# https://github.com/docker-mailserver/docker-mailserver/blob/master/target/bin/excluderelaydomain

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
# a lookup occurring during a rebuild of these files that may affect or delay delivery?
# TODO: Should instead perform an atomic operation with a temporary file + `mv` to replace?
# Or switch back to using `hash` table type if plaintext access is not needed (unless retaining file for postmap).
# Either way, plaintext copy is likely accessible if using our supported configs for providing them to the container.


# NOTE: Present support has enforced wrapping the relay host with `[]` (prevents DNS MX record lookup),
# which restricts what is supported by RELAY_HOST, although you usually do want to provide MX host directly.
# NOTE: Present support expects to always append a port with an implicit default of `25`.
# NOTE: DEFAULT_RELAY_HOST imposes neither restriction.
#
# TODO: RELAY_PORT should be optional, it will use the transport default port (`postconf smtp_tcp_port`),
# That shouldn't be a breaking change, as long as the mapping is maintained correctly.
# TODO: RELAY_HOST should consider dropping `[]` and require the user to include that?
# Future refactor for _populate_relayhost_map may warrant dropping these two ENV in favor of DEFAULT_RELAY_HOST?
function _env_relay_host() {
  echo "[${RELAY_HOST}]:${RELAY_PORT:-25}"
}

# Responsible for `postfix-sasl-password.cf` support:
# `/etc/postfix/sasl_passwd` example at end of file.
function _relayhost_sasl() {
  if [[ ! -f /tmp/docker-mailserver/postfix-sasl-password.cf ]] \
    && [[ -z ${RELAY_USER} || -z ${RELAY_PASSWORD} ]]
  then
    _log 'warn' "Missing relay-host mapped credentials provided via ENV, or from postfix-sasl-password.cf"
    return 1
  fi

  _log 'trace' "Adding relay-host credential mappings to Postfix"

  # Start from a new `/etc/postfix/sasl_passwd`:
  : >/etc/postfix/sasl_passwd
  chown root:root /etc/postfix/sasl_passwd
  chmod 0600 /etc/postfix/sasl_passwd

  local DATABASE_SASL_PASSWD='/tmp/docker-mailserver/postfix-sasl-password.cf'
  if [[ -f ${DATABASE_SASL_PASSWD} ]]; then
    # Add domain-specific auth from config file:
    _get_valid_lines_from_file "${DATABASE_SASL_PASSWD}" >> /etc/postfix/sasl_passwd

    # Only relevant when providing this user config (unless users append elsewhere too)
    postconf 'smtp_sender_dependent_authentication = yes'
  fi

  # Add an authenticated relay host defined via ENV config:
  if [[ -n ${RELAY_USER} ]] && [[ -n ${RELAY_PASSWORD} ]]; then
    echo "$(_env_relay_host)    ${RELAY_USER}:${RELAY_PASSWORD}" >> /etc/postfix/sasl_passwd
  fi

  # Technically if only a single relay host is configured, a `static` lookup table could be used instead?:
  # postconf "smtp_sasl_password_maps = static:${RELAY_USER}:${RELAY_PASSWORD}"
  postconf 'smtp_sasl_password_maps = texthash:/etc/postfix/sasl_passwd'
}

# Responsible for `postfix-relaymap.cf` support:
# `/etc/postfix/relayhost_map` example at end of file.
#
# Present support uses a table lookup for sender address or domain mapping to relay-hosts,
# Populated via `postfix-relaymap.cf `, which also features a non-standard way to exclude implicitly added internal domains from the feature.
# It also maps all known sender domains (from configs postfix-accounts + postfix-virtual.cf) to the same ENV configured relay-host.
#
# TODO: The account + virtual config parsing and appending to /etc/postfix/relayhost_map seems to be an excessive `main.cf:relayhost`
# implementation, rather than leveraging that for the same purpose and selectively overriding only when needed with `/etc/postfix/relayhost_map`.
# If the issue was to opt-out select domains, if avoiding a default relay-host was not an option, then mapping those sender domains or addresses
# to a separate transport (which can drop the `relayhost` setting) would be more appropriate.
# TODO: With `sender_dependent_default_transport_maps`, we can extract out the excluded domains and route them through a separate transport.
# while deprecating that support in favor of a transport config, similar to what is offered currently via sasl_passwd and relayhost_map.
function _populate_relayhost_map() {
  # Create the relayhost_map config file:
  : >/etc/postfix/relayhost_map
  chown root:root /etc/postfix/relayhost_map
  chmod 0600 /etc/postfix/relayhost_map

  # Matches lines that are not comments or only white-space:
  local MATCH_VALID='^\s*[^#[:space:]]'

  # This config is mostly compatible with `/etc/postfix/relayhost_map`, but additionally supports
  # not providing a relay host for a sender domain to opt-out of RELAY_HOST? (2nd half of function)
  if [[ -f /tmp/docker-mailserver/postfix-relaymap.cf ]]; then
    _log 'trace' "Adding relay mappings from postfix-relaymap.cf"

    # Match two values with some white-space between them (eg: `@example.test [relay.service.test]:465`):
    local MATCH_VALUE_PAIR='\S*\s+\S'

    # Copy over lines which are not a comment *and* have a destination.
    sed -n -r "/${MATCH_VALID}${MATCH_VALUE_PAIR}/p" /tmp/docker-mailserver/postfix-relaymap.cf >>/etc/postfix/relayhost_map
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
  function _list_domain_parts() {
    [[ -f $2 ]] && sed -n -r "/${MATCH_VALID}/ ${1}" "${2}"
  }
  # Matches and outputs (capture group via `/\1/p`) the domain part (value of address after `@`) in the config file.
  local PRINT_DOMAIN_PART_ACCOUNTS='s/^[^@|]*@([^\|]+)\|.*$/\1/p'
  local PRINT_DOMAIN_PART_VIRTUAL='s/^\s*[^@[:space:]]*@(\S+)\s.*/\1/p'

  {
    _list_domain_parts "${PRINT_DOMAIN_PART_ACCOUNTS}" /tmp/docker-mailserver/postfix-accounts.cf
    _list_domain_parts "${PRINT_DOMAIN_PART_VIRTUAL}" /tmp/docker-mailserver/postfix-virtual.cf
  } | sort -u | while read -r DOMAIN_PART; do
    # DOMAIN_PART not already present in `/etc/postfix/relayhost_map`, and not listed as a relay opt-out domain in `postfix-relaymap.cf`
    # `^@${DOMAIN_PART}\b` - To check for existing entry, the `\b` avoids accidental partial matches on similar domain parts.
    # `^\s*@${DOMAIN_PART}\s*$` - Matches line with only a domain part (eg: @example.test) to avoid including a mapping for those domains to the RELAY_HOST.
    if ! grep -q -e "^@${DOMAIN_PART}\b" /etc/postfix/relayhost_map && ! grep -qs -e "^\s*@${DOMAIN_PART}\s*$" /tmp/docker-mailserver/postfix-relaymap.cf; then
      _log 'trace' "Adding relay mapping for ${DOMAIN_PART}"
      echo "@${DOMAIN_PART}    $(_env_relay_host)" >> /etc/postfix/relayhost_map
    fi
  done

  postconf 'sender_dependent_relayhost_maps = texthash:/etc/postfix/relayhost_map'
}

function _relayhost_configure_postfix() {
  postconf \
    'smtp_sasl_auth_enable = yes' \
    'smtp_sasl_security_options = noanonymous' \
    'smtp_tls_security_level = encrypt'
}

function _setup_relayhost() {
  _log 'debug' 'Setting up Postfix Relay Hosts'

  if [[ -n ${DEFAULT_RELAY_HOST} ]]; then
    _log 'trace' "Setting default relay host ${DEFAULT_RELAY_HOST}"
    postconf "relayhost = ${DEFAULT_RELAY_HOST}"
  fi

  if [[ -n ${RELAY_HOST} ]]; then
    _log 'trace' "Setting up relay hosts (default: ${RELAY_HOST})"

    _relayhost_sasl
    _populate_relayhost_map

    _relayhost_configure_postfix
  fi
}

function _rebuild_relayhost() {
  if [[ -n ${RELAY_HOST} ]]; then
    _relayhost_sasl
    _populate_relayhost_map
  fi
}


#
# Config examples for reference
#

# main.cf:smtp_sasl_password_maps = texthash:/etc/postfix/sasl_passwd
# https://www.postfix.org/postconf.5.html#smtp_sasl_password_maps
#
# /etc/postfix/sasl_passwd
# --
# # Popular relay service examples (ports used are only to demonstrate variety):
# [smtp.sendgrid.net]:2525                     apikey:actual-generated-api-key
# [in.mailjet.com]:587                         apikey:secretkey
# [smtp.mailgun.org]:465                       postmaster@mydomain.com:password
# [email-smtp.us-west-2.amazonaws.com]:2465    SMTPUSERNAME:SMTPPASSWORD
#
# # No explicit port provided is valid. It will use the default port of the active transport:
# [mx.relay-service.test]                      relay-account:relay-pass
# # Without [], a DNS lookup for MX record will be performed:
# relay-service.test                           relay-account:relay-pass
#
#
# # Sender dependent credentials have priority over relay host credentials.
# # They will use a matching sender dependent relay-host,
# # or fallback to a default if configured.
#
# # You can provide a full sender address to use different credentials:
# user@domain1.test                            relay-account:relay-pass
#
# # Or for all users in a sender domain, with different relay-host each,
# # or sharing the same relay-host with different credentials:
# @domain1.test                                domain1-account:domain1-pass
# @domain2.test                                domain2-account:domain2-pass


# main.cf:sender_dependent_relayhost_maps = texthash:/etc/postfix/relayhost_map
# https://www.postfix.org/postconf.5.html#sender_dependent_relayhost_maps
# TODO: Official Postfix SASL_README docs page names the file `/etc/postfix/sender_relay` instead.
#
# setup /etc/postfix/relayhost_map
# --
# @domain1.test        [smtp.mailgun.org]:465
# @domain2.test        [smtp.mailgun.org]:465
# @domain3.test        [smtp.sendgrid.net]:2525
#
# # Can also use specific user or FQDN to lookup relay-host MX record:
# user@domain1.test    relay-service.test



#
# Relevant Postfix docs
#

# Enabling SASL authentication in the Postfix SMTP/LMTP client:
# https://www.postfix.org/SASL_README.html#client_sasl_enable
#
# Explains required settings for SASL client auth with relay support:
# smtp_sasl_auth_enable = yes
# smtp_tls_security_level = encrypt
# smtp_tls_security_options = noanonymous
#
# Details that configured relay-hosts must have an exact match for
# successful credentials lookup in `smtp_sasl_password_maps`.
#
# Advises that `/etc/postfix/sasl_passwd` is read+write only (600) for root,
# Along with an example using `hash` lookup table instead of `texthash`.

# Configuring sender-dependent SASL authentication:
# https://www.postfix.org/SASL_README.html#client_sasl_sender
#
# Explains that `/etc/postfix/sasl_passwd` table may map lookups by
# sender address or relay-host as keys to `user:password` values.
# Sender address has priority over relay-host and only supported when
# enabled with: `smtp_sender_dependent_authentication = yes`.
#
# Likewise those senders can be matched to different relay-hosts in the:
# `sender_dependent_relayhost_maps` table, otherwise they will fallback
# to the default relay-host (`main.cf:relayhost` setting).



#
# Advice to maintainers
#

# WARNING: Maintainers be wary of relay service docs/blogs, especially their advice for configuring Postfix.
#
# Not necessary:
# - `smtp_tls_note_starttls_offer = yes` - Only adds a log to know when an unencrypted
#   connection was made, but STARTTLS was offered:
#   https://www.postfix.org/postconf.5.html#smtp_tls_note_starttls_offer
# - `smtp_use_tls = yes` - Implied when using `smtp_tls_security_level = encrypt`:
#   https://www.postfix.org/postconf.5.html#smtp_tls_security_level
#
#
#
# MailJet:
# https://dev.mailjet.com/smtp-relay/configuration/
# https://www.mailjet.com/blog/news/which-smtp-port-mailjet/#port-465
# They describes port 465 support akin to it's prior purpose before RFC 8314 (2018).
# Every other supported port is considered "TLS" which is presumably explicit TLS (STARTTLS),
# while 465 is considered "SSL" (but unlike legacy purpose mandates authorization), presumably implicit TLS?
#
# Supported SMTP ports: https://dev.mailjet.com/smtp-relay/configuration/
# Explicit TLS: 25, 2525, 80, 587, 588 | Implicit TLS: 465
# States explicit TLS ports do not mandate TLS to connect successfully (bad).
#
#
#
# SendGrid:
# https://docs.sendgrid.com/for-developers/sending-email/integrating-with-the-smtp-api
# https://docs.sendgrid.com/for-developers/sending-email/getting-started-smtp
# Appears to make a similar distinction of port 465 as "SSL" and others "TLS".
# They at least seem aware of explicit (587) and implicit (465) TLS differences in their own blog.
# Although it's not clear if they restrict 465 to SSLv3 and earlier.. Doubtful.
#
# https://sendgrid.com/blog/whats-the-difference-between-ports-465-and-587/
# However they confusingly cite 465 is used for StartTLS (never was),
# and incorrectly describe how they deliver mail:
# https://sendgrid.com/blog/what-is-starttls/
#
# Supported SMTP ports: https://docs.sendgrid.com/for-developers/sending-email/integrating-with-the-smtp-api#smtp-ports
# Explicit TLS: 25, 2525, 587 | Implicit TLS: 465
# States explicit TLS ports do not mandate TLS to connect successfully (bad).
#
#
#
# MailGun:
# https://documentation.mailgun.com/en/latest/user_manual.html#smtp-relay
# Bad: Advises `smtp_tls_security_level = may` without enforcing TLS, allowing for unencrypted auth to relay.
# Bad: Advises setting `smtpd_tls` parameters (including legacy ones for key/cert).
# `smtpd_` is only for inbound mail, not relevant to sending / relaying mail from your MTA.
#
# Supported SMTP ports: https://documentation.mailgun.com/en/latest/user_manual.html#sending-via-smtp
# Explicit TLS: 25, 2525, 587 | Implicit TLS: 465
# All ports make TLS mandatory to connect successfully.
#
#
#
# Amazon SES:
# https://docs.aws.amazon.com/ses/latest/dg/postfix.html
# Decent docs, only lists a few unnecessary config parameters.
#
# Supported SMTP Ports: https://docs.aws.amazon.com/ses/latest/dg/smtp-connect.html
# Explicit TLS: 25, 587, 2587 | Implicit TLS: 465, 2465
# All ports make TLS mandatory to connect successfully. Port 25 may be throttled.
# Service can be configured to receive mail without requiring authentication.
