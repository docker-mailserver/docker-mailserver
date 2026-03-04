#!/bin/bash

# shellcheck source=../scripts/helpers/log.sh
source /usr/local/bin/helpers/log.sh

function _main() {
  if [[ ${GETMAIL_PARALLEL} -eq 1 ]]; then
    _log 'debug' 'Getmail parallel is enabled, required 1 argument to specify the getmailrc file will be processed in a seperate service'
    _require_n_parameters_or_print_usage 1 "${@}"
  else
    _log 'debug' 'Getmail parallel is disabled, running getmail in a loop'
    _require_n_parameters_or_print_usage 0 "${@}"
  fi

  local RC_FILE="${1}"
  local SERVICE="${SERVICE_NAME:-getmail}"

  _validate_parameters
  _add_relayhost
}

function __usage() {
  printf '%s' "${PURPLE}getmail-service${RED}(${YELLOW}8${RED})

${ORANGE}USAGE${RESET}
    ./getmail-service.sh [<RC_FILE>]

${ORANGE}OPTIONS${RESET}
    ${BLUE}Generic service to launch getmail${RESET}
        help       Print the usage information.

${ORANGE}DESCRIPTION${RESET}
    Run getmail in a loop, processing all configuration files in /etc/getmailrc.d/ periodically.
    The period is defined by GETMAIL_POLL environment variable (in minutes).

    If GETMAIL_PARALLEL is set, each configuration file is processed in a seperate service.
    The variable GETMAIL_IDLE can be set to either a list of getmailrc files (e.g. 'getmail-1.rc,getmail-2.rc')
    or to 'auto' to enable IMAP IDLE for all IMAP getmailrc files,

${ORANGE}EXAMPLES${RESET}
    ${LWHITE}./getmail-service.sh /etc/getmailrc.d/getmail-1.rc${RESET}
        Process the getmail configuration file '/etc/getmailrc.d/getmail-1.rc'.

    ${LWHITE}./getmail-service.sh${RESET}
        Process all getmail configuration files in /etc/getmailrc.d/.

${ORANGE}EXIT STATUS${RESET}
    Exit status is 0 if command was successful. If wrong arguments are provided
    or arguments contain errors, the script will exit early with exit status 1.

"
}

function _validate_parameters() {
  [[ -z ${RC_FILE} ]] && { __usage ; _exit_with_error 'No RC file specified'     ; }
}

# Directory, where "oldmail" files are stored.
# getmail stores its state - its "memory" of what it has seen in your POP/IMAP account - in the oldmail files.
GETMAIL_DIR=/var/lib/getmail

# Kill all child processes on EXIT.
# Otherwise 'supervisorctl restart getmail' leads to zombie 'sleep' processes.
trap 'pkill --parent ${$}' EXIT

function _syslog_error() {
  logger --priority mail.err --tag "${SERVICE}" "${1}"
}

function _stop_service() {
  _syslog_error "Stopping service"
  exec supervisorctl stop "${SERVICE}"
}

# Verify the correct value for GETMAIL_POLL. Valid are any numbers greater than 0.
if [[ ! ${GETMAIL_POLL} =~ ^[0-9]+$ ]] || [[ ${GETMAIL_POLL} -lt 1 ]]; then
  _syslog_error "Invalid value for GETMAIL_POLL: ${GETMAIL_POLL}"
  _stop_service
fi

# If no matching filenames are found, and the shell option nullglob is disabled, the word is left unchanged.
# If the nullglob option is set, and no matches are found, the word is removed.
shopt -s nullglob

if [[ -z "${RC_FILE}" ]]; then
  # Run each getmailrc periodically. This is the default behavior when GETMAIL_PARALLEL is disabled.
  while :; do
    for RC_FILE_LOOP in /etc/getmailrc.d/*; do
      _log 'debug' "Processing ${RC_FILE_LOOP}"
      getmail --getmaildir "${GETMAIL_DIR}" --rcfile "${RC_FILE_LOOP}"
    done

    # Stop service if no configuration is found.
    if [[ -z ${RC_FILE} ]]; then
      _syslog_error 'No configuration found'
      _stop_service
    fi

    sleep "${GETMAIL_POLL}m"
  done
elif [[ -n "${RC_FILE}" ]]; then
  # Run the specified getmailrc file. This is the default behavior when GETMAIL_PARALLEL is enabled.
  if [[ ! -f "${RC_FILE}" ]]; then
    _syslog_error "Specified RC file does not exist: ${RC_FILE}"
    _stop_service
  fi

  if grep -q 'IMAP' "${RC_FILE}" && [[ ${GETMAIL_IDLE} == "auto" || ${GETMAIL_IDLE} == *$(basename "${RC_FILE}")* ]]; then
    _log 'debug' "Enabling IMAP IDLE for ${RC_FILE}"
    getmail --getmaildir "${GETMAIL_DIR}" --rcfile "${RC_FILE}" --idle
  else
    _log 'debug' "IMAP IDLE not enabled for ${RC_FILE}"
  fi

  while :; do
    _log 'debug' "Processing ${RC_FILE}"
    getmail --getmaildir "${GETMAIL_DIR}" --rcfile "${RC_FILE}"

    sleep "${GETMAIL_POLL}m"
  done
else
  _syslog_error 'Invalid state: both RC_FILE and GETMAIL_PARALLEL are set'
  _stop_service
fi
