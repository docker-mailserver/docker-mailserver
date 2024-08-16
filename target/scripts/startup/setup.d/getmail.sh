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

    # Generate getmailrc configs, starting with the `/etc/getmailrc_general` base config, then appending users own config to the end.
    for FILE in "${GETMAIL_CONFIG_DIR}"/*.cf; do
      if [[ ${FILE} =~ /getmail/(.+)\.cf ]] && [[ ${FILE} != "${GETMAIL_RC_GENERAL_CF}" ]]; then
        ID=${BASH_REMATCH[1]}

        _log 'debug' "Processing getmail config '${ID}'"

        GETMAIL_RC=${GETMAIL_RC_DIR}/${ID}
        cat "${GETMAIL_RC_GENERAL}" "${FILE}" >"${GETMAIL_RC}"
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
  else
    _log 'debug' 'Getmail is disabled'
  fi
}
