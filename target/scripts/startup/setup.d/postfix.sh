#!/bin/bash

# Just a helper to prepend the log messages with `(Postfix setup)` so
# users know exactly where the message originated from.
#
# @param ${1} = log level
# @param ${2} = message
function __postfix__log { _log "${1:-}" "(Postfix setup) ${2:-}" ; }

function _setup_postfix_early() {
  _log 'debug' 'Configuring Postfix (early setup)'

  __postfix__log 'trace' 'Applying hostname and domainname'
  postconf "myhostname = ${HOSTNAME}"
  postconf "mydomain = ${DOMAINNAME}"

  if [[ ${POSTFIX_INET_PROTOCOLS} != 'all' ]]; then
    __postfix__log 'trace' 'Setting up POSTFIX_INET_PROTOCOLS option'
    postconf "inet_protocols = ${POSTFIX_INET_PROTOCOLS}"
  fi

  __postfix__log 'trace' "Configuring SASLauthd"
  if [[ ${ENABLE_SASLAUTHD} -eq 1 ]] && [[ ! -f /etc/postfix/sasl/smtpd.conf ]]; then
    cat >/etc/postfix/sasl/smtpd.conf << EOF
pwcheck_method: saslauthd
mech_list: plain login
EOF
  fi

  # User has explicitly requested to disable SASL auth:
  # TODO: Additive config by feature would be better. Should only enable SASL auth
  # on submission(s) services in master.cf when SASLAuthd or Dovecot is enabled.
  if [[ ${ENABLE_SASLAUTHD} -eq 0 ]] && [[ ${SMTP_ONLY} -eq 1 ]]; then
    # Default for services (eg: Port 25); NOTE: This has since become the default:
    sed -i -E \
      's|^smtpd_sasl_auth_enable =.*|smtpd_sasl_auth_enable = no|g' \
      /etc/postfix/main.cf
    # Submission services that are explicitly enabled by default:
    sed -i -E \
      's|^  -o smtpd_sasl_auth_enable=.*|  -o smtpd_sasl_auth_enable=no|g' \
      /etc/postfix/master.cf
  fi

  # scripts/helpers/aliases.sh:_create_aliases()
  __postfix__log 'trace' 'Setting up aliases'
  _create_aliases

  # scripts/helpers/postfix.sh:_create_postfix_vhost()
  __postfix__log 'trace' 'Setting up Postfix vhost'
  _create_postfix_vhost

  __postfix__log 'trace' "Configuring message size limit to '${POSTFIX_MESSAGE_SIZE_LIMIT}'"
  postconf "message_size_limit = ${POSTFIX_MESSAGE_SIZE_LIMIT}"

  __postfix__log 'trace' "Configuring mailbox size limit to '${POSTFIX_MAILBOX_SIZE_LIMIT}'"
  postconf "mailbox_size_limit = ${POSTFIX_MAILBOX_SIZE_LIMIT}"

  __postfix__log 'trace' "Configuring virtual mailbox size limit to '${POSTFIX_MAILBOX_SIZE_LIMIT}'"
  postconf "virtual_mailbox_limit = ${POSTFIX_MAILBOX_SIZE_LIMIT}"

  if [[ ${POSTFIX_REJECT_UNKNOWN_CLIENT_HOSTNAME} -eq 1 ]]; then
    __postfix__log 'trace' 'Enabling reject_unknown_client_hostname to dms_smtpd_sender_restrictions'
    sedfile -i -E \
      's|^(dms_smtpd_sender_restrictions = .*)|\1, reject_unknown_client_hostname|' \
      /etc/postfix/main.cf
  fi

  # Dovecot feature integration
  # TODO: Alias SMTP_ONLY=0 to DOVECOT_ENABLED=1?
  if [[ ${SMTP_ONLY} -ne 1 ]]; then
    __postfix__log 'trace' 'Configuring Postfix with Dovecot integration'

    # /etc/postfix/vmailbox is created by: scripts/helpers/accounts.sh:_create_accounts()
    # This file config is for Postfix to verify a mail account exists before accepting
    # mail arriving and delivering it to Dovecot over LMTP.
    if [[ ${ACCOUNT_PROVISIONER} == 'FILE' ]]; then
      postconf 'virtual_mailbox_maps = texthash:/etc/postfix/vmailbox'
    fi
    # Historical context regarding decision to use LMTP instead of LDA (do not change this):
    # https://github.com/docker-mailserver/docker-mailserver/issues/4178#issuecomment-2375489302
    postconf 'virtual_transport = lmtp:unix:/var/run/dovecot/lmtp'
  fi

  if [[ -n ${POSTFIX_DAGENT} ]]; then
    __postfix__log 'trace' "Changing virtual transport to '${POSTFIX_DAGENT}'"
    postconf "virtual_transport = ${POSTFIX_DAGENT}"
  fi
}

function _setup_postfix_late() {
  _log 'debug' 'Configuring Postfix (late setup)'

  # These two config files are `access` database tables managed via `setup email restrict`:
  # NOTE: Prepends to existing restrictions, thus has priority over other permit/reject policies that follow.
  # https://www.postfix.org/postconf.5.html#smtpd_sender_restrictions
  # https://www.postfix.org/access.5.html
  __postfix__log 'trace' 'Configuring user access'
  if [[ -f /tmp/docker-mailserver/postfix-send-access.cf ]]; then
    # Prefer to prepend to our specialized variant instead:
    # https://github.com/docker-mailserver/docker-mailserver/pull/4379
    sed -i -E 's|^(dms_smtpd_sender_restrictions =)|\1 check_sender_access texthash:/tmp/docker-mailserver/postfix-send-access.cf,|' /etc/postfix/main.cf
  fi

  if [[ -f /tmp/docker-mailserver/postfix-receive-access.cf ]]; then
    sed -i -E 's|^(smtpd_recipient_restrictions =)|\1 check_recipient_access texthash:/tmp/docker-mailserver/postfix-receive-access.cf,|' /etc/postfix/main.cf
  fi

  __postfix__log 'trace' 'Configuring relay host'
  _setup_relayhost

  __postfix__setup_override_configuration
}

function __postfix__setup_override_configuration() {
  __postfix__log 'debug' 'Overriding / adjusting configuration with user-supplied values'

  local OVERRIDE_CONFIG_POSTFIX_MASTER='/tmp/docker-mailserver/postfix-master.cf'
  if [[ -f ${OVERRIDE_CONFIG_POSTFIX_MASTER} ]]; then
    while read -r LINE; do
      [[ ${LINE} =~ ^[0-9a-z] ]] && postconf -P "${LINE}"
    done < <(_get_valid_lines_from_file "${OVERRIDE_CONFIG_POSTFIX_MASTER}")
    __postfix__log 'trace' "Adjusted '/etc/postfix/master.cf' according to '${OVERRIDE_CONFIG_POSTFIX_MASTER}'"
  else
    __postfix__log 'trace' "No extra Postfix master settings loaded because optional '${OVERRIDE_CONFIG_POSTFIX_MASTER}' was not provided"
  fi

  # NOTE: `postfix-main.cf` should be handled after `postfix-master.cf` as custom parameters require an existing reference
  # in either `main.cf` or `master.cf` prior to `postconf` reading `main.cf`, otherwise it is discarded from output.
  local OVERRIDE_CONFIG_POSTFIX_MAIN='/tmp/docker-mailserver/postfix-main.cf'
  if [[ -f ${OVERRIDE_CONFIG_POSTFIX_MAIN} ]]; then
    cat "${OVERRIDE_CONFIG_POSTFIX_MAIN}" >>/etc/postfix/main.cf
    _adjust_mtime_for_postfix_maincf

    # Do not directly output to 'main.cf' as this causes a read-write-conflict.
    # `postconf` output is filtered to skip expected warnings regarding overrides:
    # https://github.com/docker-mailserver/docker-mailserver/pull/3880#discussion_r1510414576
    postconf -n >/tmp/postfix-main-new.cf 2> >(grep -v 'overriding earlier entry' >&2)

    mv /tmp/postfix-main-new.cf /etc/postfix/main.cf
    _adjust_mtime_for_postfix_maincf
    __postfix__log 'trace' "Adjusted '/etc/postfix/main.cf' according to '${OVERRIDE_CONFIG_POSTFIX_MAIN}'"
  else
    __postfix__log 'trace' "No extra Postfix main settings loaded because optional '${OVERRIDE_CONFIG_POSTFIX_MAIN}' was not provided"
  fi
}

function _setup_SRS() {
  _log 'debug' 'Setting up SRS'

  postconf 'sender_canonical_maps = tcp:localhost:10001'
  postconf "sender_canonical_classes = ${SRS_SENDER_CLASSES}"
  postconf 'recipient_canonical_maps = tcp:localhost:10002'
  postconf 'recipient_canonical_classes = envelope_recipient,header_recipient'

  function __generate_secret() {
    (
      umask 0077
      dd if=/dev/urandom bs=24 count=1 2>/dev/null | base64 -w0 >"${1}"
    )
  }

  local POSTSRSD_SECRET_FILE

  sed -i "s/localdomain/${SRS_DOMAINNAME}/g" /etc/default/postsrsd

  POSTSRSD_SECRET_FILE='/etc/postsrsd.secret'

  if [[ -n ${SRS_SECRET} ]]; then
    (
      umask 0077
      echo "${SRS_SECRET}" | tr ',' '\n' >"${POSTSRSD_SECRET_FILE}"
    )
  else
    if [[ ! -f ${POSTSRSD_SECRET_FILE} ]]; then
      __generate_secret "${POSTSRSD_SECRET_FILE}"
    fi
  fi

  if [[ -n ${SRS_EXCLUDE_DOMAINS} ]]; then
    sedfile -i -E \
      "s|^#?(SRS_EXCLUDE_DOMAINS=).*|\1${SRS_EXCLUDE_DOMAINS}|" \
      /etc/default/postsrsd
  fi
}
