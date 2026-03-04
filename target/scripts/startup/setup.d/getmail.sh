#!/bin/bash

function _setup_getmail() {
  if [[ ${ENABLE_GETMAIL} -eq 1 ]]; then
    _log 'trace' 'Preparing Getmail configuration'

    local GETMAIL_RC ID GETMAIL_DIR

    local GETMAIL_CONFIG_DIR='/tmp/docker-mailserver/getmail'
    local GETMAIL_RC_DIR='/etc/getmailrc.d'
    local GETMAIL_RC_GENERAL_CF="${GETMAIL_CONFIG_DIR}/getmailrc_general.cf"
    local GETMAIL_RC_GENERAL='/etc/getmailrc_general'

    # Create the directory /etc/getmailrc.d to place the user config in later.
    mkdir -p "${GETMAIL_RC_DIR}"

    # Check if custom getmailrc_general.cf file is present.
    if [[ -f "${GETMAIL_RC_GENERAL_CF}" ]]; then
      _log 'debug' "Custom 'getmailrc_general.cf' found"
      cp "${GETMAIL_RC_GENERAL_CF}" "${GETMAIL_RC_GENERAL}"
    fi

    # If no matching filenames are found, and the shell option nullglob is disabled, the word is left unchanged.
    # If the nullglob option is set, and no matches are found, the word is removed.
    shopt -s nullglob

    local COUNTER=0
    # Generate getmailrc configs, starting with the `/etc/getmailrc_general` base config, then appending users own config to the end.
    for FILE in "${GETMAIL_CONFIG_DIR}"/*.cf; do
      if [[ ${FILE} =~ /getmail/(.+)\.cf ]] && [[ ${FILE} != "${GETMAIL_RC_GENERAL_CF}" ]]; then
        ID=${BASH_REMATCH[1]}

        _log 'debug' "Processing getmail config '${ID}'"

        GETMAIL_RC=${GETMAIL_RC_DIR}/${ID}
        cat "${GETMAIL_RC_GENERAL}" "${FILE}" >"${GETMAIL_RC}"

        if [[ ${GETMAIL_PARALLEL} -eq 1 ]]; then
          # If parallel getmail is enable, configure a seperate serivce for each getmail_rc file.
          # Lateron this allows to leverage the "IMAP IDLE" extension for immediate download of new mails.
          _log 'debug' "Defining new service for '${GETMAIL_RC}'"
          COUNTER=$(( COUNTER + 1 ))
          cat >"/etc/supervisor/conf.d/getmail-${COUNTER}.conf" << EOF
[program:getmail-${COUNTER}]
startsecs=0
stopwaitsecs=55
autostart=false
autorestart=true
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log
command=/bin/bash -l -c /usr/local/bin/getmail-service.sh ${GETMAIL_RC}
environment=SERVICE_NAME="getmail-${COUNTER}"
EOF

          chmod 700 "${GETMAIL_RC}"
          chown root:root "${GETMAIL_RC}"
        else
            _log 'debug' 'Getmail parallel is disabled'
        fi
      fi
    done
    # Strip read access from non-root due to files containing secrets:
    chmod -R 600 "${GETMAIL_RC_DIR}"

    # Directory, where "oldmail" files are stored.
    # For more information see: https://getmail6.org/faq.html#faq-about-oldmail
    # The debug command for getmail expects this location to exist.
    GETMAIL_DIR=/var/lib/getmail
    _log 'debug' "Creating getmail state-dir '${GETMAIL_DIR}'"
    mkdir -p "${GETMAIL_DIR}"

    # Ensure new services are registered with supervisord.
    supervisorctl reread
    supervisorctl update
  else
    _log 'debug' 'Getmail is disabled'
  fi
}
