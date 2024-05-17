#!/bin/bash

function _setup_getmail() {
  if [[ ${ENABLE_GETMAIL} -eq 1 ]]; then
    _log 'trace' 'Preparing Getmail configuration'

    local GETMAILRC ID CONFIGS

    GETMAILRC='/etc/getmailrc.d'
    CONFIGS=0

    mkdir -p "${GETMAILRC}"

    # Generate getmailrc configs, starting with the `/etc/getmailrc_general` base config,
    # Add a unique `message_log` config, then append users own config to the end.
    for FILE in /tmp/docker-mailserver/getmail-*.cf; do
      if [[ -f ${FILE} ]]; then
        CONFIGS=1
        ID=$(cut -d '-' -f 3 <<< "${FILE}" | cut -d '.' -f 1)
        local GETMAIL_CONFIG="${GETMAILRC}/getmailrc-${ID}"

        cat /etc/getmailrc_general                                 >"${GETMAIL_CONFIG}"
        echo -e "message_log = /var/log/mail/getmail-${ID}.log\n" >>"${GETMAIL_CONFIG}"
        cat "${FILE}"                                             >>"${GETMAIL_CONFIG}"
      fi
    done

    if [[ ${CONFIGS} -eq 1 ]]; then
      cat >/etc/cron.d/getmail << EOF
*/${GETMAIL_POLL} * * * * root /usr/local/bin/getmail-cron
EOF
      chmod -R 600 "${GETMAILRC}"
    fi

    # Both the debug command and cron job (that runs getmail) for getmail
    # expect this location to exist.
    GETMAILDIR=/tmp/docker-mailserver/getmail
    mkdir -p "${GETMAILDIR}"
  else
    _log 'debug' 'Getmail is disabled'
  fi
}
