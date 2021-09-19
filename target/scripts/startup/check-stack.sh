#! /bin/bash

function check
{
  _notify 'tasklog' 'Checking configuration'
  for FUNC in "${FUNCS_CHECK[@]}"
  do
    ${FUNC}
  done
}

function _check_hostname
{
  _notify 'task' 'Checking that hostname/domainname is provided or overridden'

  _notify 'inf' "Domain has been set to ${DOMAINNAME}"
  _notify 'inf' "Hostname has been set to ${HOSTNAME}"

  # HOSTNAME should be an FQDN (eg: hostname.domain)
  if ! grep -q -E '^(\S+[.]\S+)$' <<< "${HOSTNAME}"
  then
    _shutdown 'Setting hostname/domainname is required'
  fi
}
