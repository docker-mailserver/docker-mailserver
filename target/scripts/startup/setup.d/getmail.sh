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

        # The ID is embedded into a supervisord `command=` line, where quotes, spaces and `%` break parsing.
        if [[ ${GETMAIL_PARALLEL} -eq 1 ]] && [[ ! ${ID} =~ ^[A-Za-z0-9._-]+$ ]]; then
          _log 'warn' "Skipping getmail config '${ID}': with GETMAIL_PARALLEL=1, names may only contain 'A-Z', 'a-z', '0-9', '.', '_' and '-'"
          continue
        fi

        _log 'debug' "Processing getmail config '${ID}'"

        GETMAIL_RC=${GETMAIL_RC_DIR}/${ID}
        cat "${GETMAIL_RC_GENERAL}" "${FILE}" >"${GETMAIL_RC}"

        if [[ ${GETMAIL_PARALLEL} -eq 1 ]]; then
          # If parallel getmail execution is enabled, configure a separate service
          # for each getmailrc file. This enables the use of the "IMAP IDLE"
          # extension for the immediate downloading of new emails.
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
command=/bin/bash -l -c '/usr/local/bin/getmail-service.sh "${GETMAIL_RC}"'
environment=SERVICE_NAME="getmail-${COUNTER}"
EOF
        fi
      fi
    done

    # Strip read access from non-root due to files containing secrets:
    chmod -R 600 "${GETMAIL_RC_DIR}"

    if [[ ${GETMAIL_PARALLEL} -eq 1 ]]; then
      # Ensure new services are registered with supervisord.
      supervisorctl reread
      supervisorctl update
    elif [[ -n ${GETMAIL_IDLE} ]]; then
      _log 'warn' "GETMAIL_IDLE is set but has no effect unless GETMAIL_PARALLEL=1"
    fi

    # Directory, where "oldmail" files are stored.
    # For more information see: https://getmail6.org/faq.html#faq-about-oldmail
    # The debug command for getmail expects this location to exist.
    GETMAIL_DIR=/var/lib/getmail
    _log 'debug' "Creating getmail state-dir '${GETMAIL_DIR}'"
    mkdir -p "${GETMAIL_DIR}"
  else
    _log 'debug' 'Getmail is disabled'
  fi
}
