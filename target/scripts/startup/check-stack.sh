#!/bin/bash

declare -a FUNCS_CHECK

function _register_check_function() {
  FUNCS_CHECK+=("${1}")
  _log 'trace' "${1}() registered"
}

function _check() {
  _log 'info' 'Checking configuration'
  for FUNC in "${FUNCS_CHECK[@]}"; do
    ${FUNC}
  done
}

function _check_improper_restart() {
  _log 'debug' 'Checking for improper restart'

  if [[ -f /CONTAINER_START ]]; then
    _log 'warn' 'This container was (likely) improperly restarted which can result in undefined behavior'
    _log 'warn' 'Please destroy the container properly and then start DMS again'
  fi
}

function _check_hostname() {
  _log 'debug' 'Checking that hostname/domainname is provided or overridden'

  _log 'debug' "Domain has been set to ${DOMAINNAME}"
  _log 'debug' "Hostname has been set to ${HOSTNAME}"

  # HOSTNAME should be an FQDN (eg: hostname.domain)
  if ! grep -q -E '^(\S+[.]\S+)$' <<< "${HOSTNAME}"; then
    _dms_panic__general 'Setting hostname/domainname is required'
  fi
}

function _check_log_level() {
  if [[ ${LOG_LEVEL} == 'trace' ]] \
  || [[ ${LOG_LEVEL} == 'debug' ]] \
  || [[ ${LOG_LEVEL} == 'info' ]]  \
  || [[ ${LOG_LEVEL} == 'warn' ]]  \
  || [[ ${LOG_LEVEL} == 'error' ]]
  then
    return 0
  else
    local DEFAULT_LOG_LEVEL='info'
    _log 'warn' "Log level '${LOG_LEVEL}' is invalid (falling back to default '${DEFAULT_LOG_LEVEL}')"

    # shellcheck disable=SC2034
    VARS[LOG_LEVEL]="${DEFAULT_LOG_LEVEL}"
    LOG_LEVEL="${DEFAULT_LOG_LEVEL}"
  fi
}
