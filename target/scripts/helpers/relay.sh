#!/bin/bash
# Support for Relay Hosts

# Description:
# This helper is responsible for configuring outbound SMTP (delivery) through relay-hosts.
#
# When mail is sent to Postfix and the destination is not a domain DMS manages, this requires relaying to that destination (or the next hop).
# By default outbound mail delivery would be direct to the MTA of the recipient address (destination).
# Alternatively mail can be delivered indirectly to that destination by routing through a different MTA (relay-host service).
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
# WARNING: Databases (tables above) are rebuilt during change detection.
# There is a minor chance of a lookup occurring during a rebuild of these files that may affect or delay delivery?
# TODO: Should instead perform an atomic operation with a temporary file + `mv` to replace?
# Or switch back to using `hash` table type if plaintext access is not needed (unless retaining file for postmap).
# Either way, plaintext copy is likely accessible if using our supported configs for providing them to the container.


# NOTE: Present support has enforced wrapping the `RELAY_HOST` value with `[]` (prevents DNS MX record lookup),
# shouldn't be an issue as you typically do want to provide the MX host directly? This was presumably for config convenience.
# NOTE: Present support expects to always append a port (_with an implicit default of `25`_).
# NOTE: The `DEFAULT_RELAY_HOST` ENV imposes neither restriction.
#
# TODO: `RELAY_PORT` should be optional (Postfix would fallback to the transports default port (`postconf smtp_tcp_port`),
# That shouldn't be a breaking change, as long as the mapping is maintained correctly.
# TODO: `RELAY_HOST` should consider dropping the implicit `[]` and require the user to include that?
#
# A future refactor of `_populate_relayhost_map()` may warrant dropping those two ENV in favor of `DEFAULT_RELAY_HOST`?
function _env_relay_host() {
  echo "[${RELAY_HOST}]:${RELAY_PORT:-25}"
}

# Responsible for `postfix-sasl-password.cf` support:
# `/etc/postfix/sasl_passwd` example at end of file.
function _relayhost_sasl() {
  local DATABASE_SASL_PASSWD='/tmp/docker-mailserver/postfix-sasl-password.cf'

  # Only relevant when required credential sources are provided:
  if [[ ! -f ${DATABASE_SASL_PASSWD} ]] \
  && [[ -z ${RELAY_USER} || -z ${RELAY_PASSWORD} ]]; then
    _log 'warn' "Missing relay-host mapped credentials provided via ENV, or from ${DATABASE_SASL_PASSWD}"
    return 1
  fi

  _log 'trace' "Adding relay-host credential mappings to Postfix"

  # Start from a new `/etc/postfix/sasl_passwd`:
  : >/etc/postfix/sasl_passwd
  chown root:root /etc/postfix/sasl_passwd
  chmod 0600 /etc/postfix/sasl_passwd

  if [[ -f ${DATABASE_SASL_PASSWD} ]]; then
    # Add domain-specific auth from config file:
    _get_valid_lines_from_file "${DATABASE_SASL_PASSWD}" >> /etc/postfix/sasl_passwd

    # Only relevant when providing this user config (unless users append elsewhere too)
    postconf 'smtp_sender_dependent_authentication = yes'
  fi

  # Support authentication to a primary relayhost (when configured with credentials via ENV):
  if [[ -n ${DEFAULT_RELAY_HOST} || -n ${RELAY_HOST} ]] \
  && [[ -n ${RELAY_USER} && -n ${RELAY_PASSWORD} ]]; then
    echo "${DEFAULT_RELAY_HOST:-$(_env_relay_host)}    ${RELAY_USER}:${RELAY_PASSWORD}" >>/etc/postfix/sasl_passwd
  fi

  # Enable credential lookup + SASL authentication to relayhost:
  # - `noanonymous` enforces authentication requirement
  # - `encrypt` enforces requirement for a secure connection (prevents sending credentials over cleartext, aka mandatory TLS)
  postconf \
    'smtp_sasl_password_maps = texthash:/etc/postfix/sasl_passwd' \
    'smtp_sasl_auth_enable = yes' \
    'smtp_sasl_security_options = noanonymous' \
    'smtp_tls_security_level = encrypt'
}

# Responsible for `postfix-relaymap.cf` support:
# `/etc/postfix/relayhost_map` example at end of file.
#
# `postfix-relaymap.cf` represents table syntax expected for `/etc/postfix/relayhost_map`, except that it adds an opt-out parsing feature.
# All known mail domains managed by DMS (/etc/postfix/vhost) are implicitly configured to use `RELAY_HOST` + `RELAY_PORT` as the default relay.
# This approach is effectively equivalent to using `main.cf:relayhost`, but with an excessive workaround to support the explicit opt-out feature.
#
# TODO: Refactor this feature support so that in `main.cf`:
# - Relay all outbound mail through an external MTA by default (works without credentials):
#   `relayhost = ${DEFAULT_RELAY_HOST}`
# - Opt-in to relaying - Selectively relay outbound mail by sender/domain to an external MTA (relayhost can vary):
#   `sender_dependent_relayhost_maps = texthash:/etc/postfix/relayhost_map`
# - Opt-out from relaying - Selectively prevent outbound mail from relaying via separate transport mappings (where relayhost is not configured):
#   By sender: `sender_dependent_default_transport_maps = texthash:/etc/postfix/sender_transport_map` (the current opt-out feature could utilize this instead)
#   By recipient (has precedence): `transport_maps = texthash:/etc/postfix/recipient_transport_map`
#
# Support for relaying via port 465 or equivalent requires additional config support (as needed for 465 vs 587 transports extending smtpd)
# - Default relay transport is configured by `relay_transport`, with default transport port configured by `smtp_tcp_port`.
# - The `relay` transport itself extends from `smtp` transport. More than one can be configured with separate settings via `master.cf`.

function _populate_relayhost_map() {
  # Create the relayhost_map config file:
  : >/etc/postfix/relayhost_map
  chown root:root /etc/postfix/relayhost_map
  chmod 0600 /etc/postfix/relayhost_map

  _multiple_relayhosts
  _legacy_support

  postconf 'sender_dependent_relayhost_maps = texthash:/etc/postfix/relayhost_map'
}

function _multiple_relayhosts() {
  if [[ -f ${DATABASE_RELAYHOSTS} ]]; then
    _log 'trace' "Adding relay mappings from ${DATABASE_RELAYHOSTS}"

    # Matches lines that are not comments or only white-space:
    local MATCH_VALID='^\s*[^#[:space:]]'
    # Match two values with some white-space between them (eg: `@example.test [relay.service.test]:465`):
    local MATCH_VALUE_PAIR='\S*\s+\S'

    # Copy over lines which are not a comment *and* have a relay destination.
    # Extra condition is due to legacy support (due to opt-out feature), otherwise `_get_valid_lines_from_file()` would be valid.
    sed -n -r "/${MATCH_VALID}${MATCH_VALUE_PAIR}/p" "${DATABASE_RELAYHOSTS}" >> /etc/postfix/relayhost_map
  fi
}

# Implicitly force configure all domains DMS manages to be relayed that haven't yet been configured or provided an explicit opt-out.
# This would normally be handled via an opt-in approach, or through `main.cf:relayhost` with an opt-out approach (sender_dependent_default_transport_maps)
function _legacy_support() {
  local DATABASE_VHOST='/etc/postfix/vhost'

  # Only relevant when `RELAY_HOST` is configured:
  [[ -z ${RELAY_HOST} ]] && return 1

  # Configures each `SENDER_DOMAIN` to send outbound mail through the default `RELAY_HOST` + `RELAY_PORT`
  # (by adding an entry in `/etc/postfix/relayhost_map`) provided it:
  # - `/etc/postfix/relayhost_map` doesn't already have it as an existing entry.
  # - `postfix-relaymap.cf` has no explicit opt-out (SENDER_DOMAIN key exists, but with no relayhost value assigned)
  #
  # NOTE: /etc/postfix/vhost represents managed mail domains sourced from `postfix-accounts.cf` and `postfix-virtual.cf`.
  while read -r SENDER_DOMAIN; do
    local MATCH_EXISTING_ENTRY="^@${SENDER_DOMAIN}\s+"
    local MATCH_OPT_OUT_LINE="^\s*@${SENDER_DOMAIN}\s*$"

    # NOTE: `-E` is required for `\s+` syntax to avoid escaping `+`
    if ! grep -q -E "${MATCH_EXISTING_ENTRY}" /etc/postfix/relayhost_map && ! grep -qs "${MATCH_OPT_OUT_LINE}" "${DATABASE_RELAYHOSTS}"; then
      _log 'trace' "Configuring '${SENDER_DOMAIN}' for the default relayhost '${RELAY_HOST}'"
      echo "@${SENDER_DOMAIN}    $(_env_relay_host)" >> /etc/postfix/relayhost_map
    fi
  done < <(_get_valid_lines_from_file "${DATABASE_VHOST}")
}

function _setup_relayhost() {
  _log 'debug' 'Setting up Postfix Relay Hosts'

  if [[ -n ${DEFAULT_RELAY_HOST} ]]; then
    _log 'trace' "Setting default relay host ${DEFAULT_RELAY_HOST}"
    postconf "relayhost = ${DEFAULT_RELAY_HOST}"
  fi

  _process_relayhost_configs
}

# Called during initial container setup, or by change detection event:
function _process_relayhost_configs() {
  local DATABASE_RELAYHOSTS='/tmp/docker-mailserver/postfix-relaymap.cf'

  # One of these must configure a relayhost for the feature to relevant:
  if [[ ! -f ${DATABASE_RELAYHOSTS} ]] \
  && [[ -z ${DEFAULT_RELAY_HOST} ]] \
  && [[ -z ${RELAY_HOST} ]]; then
    return 1
  fi

  _relayhost_sasl
  _populate_relayhost_map
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
