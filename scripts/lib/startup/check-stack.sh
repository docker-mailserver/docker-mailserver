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

function _check_hostname() {
  _log 'debug' 'Checking that hostname/domainname is provided or overridden'

  _log 'debug' "Domain has been set to ${DOMAINNAME}"
  _log 'debug' "Hostname has been set to ${HOSTNAME}"

  # HOSTNAME should be an FQDN (eg: hostname.domain)
  if ! grep -q -E '^(\S+[.]\S+)$' <<< "${HOSTNAME}"; then
    _dms_panic__general 'Setting hostname/domainname is required'
  fi
}

function _check_spam_prefix() {
  # This check should be independent of ENABLE_POP3 and ENABLE_IMAP
  if [[ ${MOVE_SPAM_TO_JUNK} -eq 0 ]] \
  && [[ -z ${SPAM_SUBJECT} ]]; then
    _log 'warn' "'MOVE_SPAM_TO_JUNK=0' and 'SPAM_SUBJECT' is empty - make sure this is intended: spam e-mails might not be immediately recognizable in this configuration"
  fi
}
