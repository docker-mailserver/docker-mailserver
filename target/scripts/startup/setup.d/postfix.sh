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

  __postfix__log 'trace' "Disabling SMTPUTF8 support"
  postconf 'smtputf8_enable = no'

  __postfix__log 'trace' "Configuring SASLauthd"
  if [[ ${ENABLE_SASLAUTHD} -eq 1 ]] && [[ ! -f /etc/postfix/sasl/smtpd.conf ]]; then
    cat >/etc/postfix/sasl/smtpd.conf << EOF
pwcheck_method: saslauthd
mech_list: plain login
EOF
  fi

  if [[ ${ENABLE_SASLAUTHD} -eq 0 ]] && [[ ${SMTP_ONLY} -eq 1 ]]; then
    sed -i -E \
      's|^smtpd_sasl_auth_enable =.*|smtpd_sasl_auth_enable = no|g' \
      /etc/postfix/main.cf
    sed -i -E \
      's|^  -o smtpd_sasl_auth_enable=.*|  -o smtpd_sasl_auth_enable=no|g' \
      /etc/postfix/master.cf
  fi

  __postfix__log 'trace' 'Setting up aliases'
  _create_aliases

  __postfix__log 'trace' 'Setting up Postfix vhost'
  _create_postfix_vhost

  __postfix__log 'trace' 'Setting up DH Parameters'
  _setup_dhparam 'Postfix' '/etc/postfix/dhparams.pem'

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
}

function _setup_postfix_late() {
  _log 'debug' 'Configuring Postfix (late setup)'

  __postfix__log 'trace' 'Configuring user access'
  if [[ -f /tmp/docker-mailserver/postfix-send-access.cf ]]; then
    sed -i -E 's|(smtpd_sender_restrictions =)|\1 check_sender_access texthash:/tmp/docker-mailserver/postfix-send-access.cf,|' /etc/postfix/main.cf
  fi

  if [[ -f /tmp/docker-mailserver/postfix-receive-access.cf ]]; then
    sed -i -E 's|(smtpd_recipient_restrictions =)|\1 check_recipient_access texthash:/tmp/docker-mailserver/postfix-receive-access.cf,|' /etc/postfix/main.cf
  fi

  __postfix__log 'trace' 'Configuring relay host'
  _setup_relayhost

  if [[ -n ${POSTFIX_DAGENT} ]]; then
    __postfix__log 'trace' "Changing virtual transport to '${POSTFIX_DAGENT}'"
    # Default value in main.cf should be 'lmtp:unix:/var/run/dovecot/lmtp'
    postconf "virtual_transport = ${POSTFIX_DAGENT}"
  fi

  __postfix__setup_override_configuration
}

function __postfix__setup_override_configuration() {
  __postfix__log 'debug' 'Overriding / adjusting configuration with user-supplied values'

  if [[ -f /tmp/docker-mailserver/postfix-main.cf ]]; then
    cat /tmp/docker-mailserver/postfix-main.cf >>/etc/postfix/main.cf
    _adjust_mtime_for_postfix_maincf

    # do not directly output to 'main.cf' as this causes a read-write-conflict
    postconf -n >/tmp/postfix-main-new.cf 2>/dev/null

    mv /tmp/postfix-main-new.cf /etc/postfix/main.cf
    _adjust_mtime_for_postfix_maincf
    __postfix__log 'trace' "Adjusted '/etc/postfix/main.cf' according to '/tmp/docker-mailserver/postfix-main.cf'"
  else
    __postfix__log 'trace' "No extra Postfix settings loaded because optional '/tmp/docker-mailserver/postfix-main.cf' was not provided"
  fi

  if [[ -f /tmp/docker-mailserver/postfix-master.cf ]]; then
    while read -r LINE; do
      if [[ ${LINE} =~ ^[0-9a-z] ]]; then
        postconf -P "${LINE}"
      fi
    done < /tmp/docker-mailserver/postfix-master.cf
    __postfix__log 'trace' "Adjusted '/etc/postfix/master.cf' according to '/tmp/docker-mailserver/postfix-master.cf'"
  else
    __postfix__log 'trace' "No extra Postfix settings loaded because optional '/tmp/docker-mailserver/postfix-master.cf' was not provided"
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
