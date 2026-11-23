#!/bin/bash

# This becomes the sourcing script name
# (example: check-for-changes.sh)
SCRIPT_NAME=$(basename "$0")
# Used inside of lock files to identify them and
# prevent removal by other instances of docker-mailserver
LOCK_ID=$(uuid)

function _create_lock() {
  LOCK_FILE="/tmp/docker-mailserver/${SCRIPT_NAME}.lock"
  while [[ -e "${LOCK_FILE}" ]]; do
    # Handle stale lock files left behind on crashes
    # or premature/non-graceful exits of containers while they're making changes
    if [[ -n "$(find "${LOCK_FILE}" -mmin +1 2>/dev/null)" ]]; then
      _log 'warn' 'Lock file older than 1 minute - removing stale lock file'
      rm -f "${LOCK_FILE}"
    else
      _log 'warn' "Lock file '${LOCK_FILE}' exists - another execution of '${SCRIPT_NAME}' is happening - trying again shortly"
      sleep 5
    fi
  done
  trap _remove_lock EXIT

  _log 'trace' "Creating lock '${LOCK_FILE}'"
  echo "${LOCK_ID}" >"${LOCK_FILE}"
}

function _remove_lock() {
  LOCK_FILE="${LOCK_FILE:-"/tmp/docker-mailserver/${SCRIPT_NAME}.lock"}"
  [[ -z "${LOCK_ID}" ]] && _exit_with_error "Cannot remove '${LOCK_FILE}' as there is no LOCK_ID set"
  if [[ -e "${LOCK_FILE}" ]] && grep -q "${LOCK_ID}" "${LOCK_FILE}"; then # Ensure we don't delete a lock that's not ours
    rm -f "${LOCK_FILE}"
    _log 'trace' "Removed lock '${LOCK_FILE}'"
  fi
}
