#!/bin/bash

function _check
{
  _log 'info' 'Checking configuration'
  for FUNC in "${FUNCS_CHECK[@]}"
  do
    ${FUNC}
  done
}

function _check_dns_names
{
  _log 'debug' 'Checking that DNS names are properly set'

  _log 'trace' "DNS names: FQDN has been set to '${DMS_FQDN}'"
  _log 'trace' "DNS names: Domainname has been set to '${DMS_DOMAINNAME}'"
  _log 'trace' "DNS names: Hostname has been set to '${DMS_HOSTNAME}'"

  if ! grep -q -E '^(\S+[.]\S+)$' <<< "${DMS_FQDN}"
  then
    _shutdown "DNS names: FQDN ('${DMS_FQDN}') is invalid"
  fi

  if ! grep -q -E '^(\S+[.]\S+)$' <<< "${DMS_DOMAINNAME}"
  then
    _shutdown "DNS names: domainname ('${DMS_DOMAINNAME}') is invalid"
  fi

  if [[ -z ${DMS_HOSTNAME} ]]
  then
    _log 'debug' 'Detected bare domain setup'
  fi
}

function _check_log_level
{
  if [[ ! ${LOG_LEVEL} =~ ^(trace|debug|info|warn|error)$ ]]
  then
    local DEFAULT_LOG_LEVEL='info'
    _log 'warn' "Log level '${LOG_LEVEL}' is invalid (falling back to default '${DEFAULT_LOG_LEVEL}')"

    # shellcheck disable=SC2034
    VARS[LOG_LEVEL]="${DEFAULT_LOG_LEVEL}"
    LOG_LEVEL="${DEFAULT_LOG_LEVEL}"
  fi
}
