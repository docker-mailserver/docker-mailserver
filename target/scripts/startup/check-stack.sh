#! /bin/bash

function check
{
  _notify 'tasklog' 'Checking configuration'

  for FUNC in "${FUNCS_CHECK[@]}"
  do
    ${FUNC} || _defunc
  done
}

function _check_hostname
{
  _notify "task" "Check that hostname/domainname is provided or overridden [in ${FUNCNAME[0]}]"

  if [[ -n ${OVERRIDE_HOSTNAME} ]]
  then
    export HOSTNAME=${OVERRIDE_HOSTNAME}
    export DOMAINNAME="${HOSTNAME#*.}"
  fi

  _notify 'inf' "Domain has been set to ${DOMAINNAME}"
  _notify 'inf' "Hostname has been set to ${HOSTNAME}"

  if ! grep -q -E '^(\S+[.]\S+)$' <<< "${HOSTNAME}"
  then
    _notify 'err' "Setting hostname/domainname is required"
    kill "$(< /var/run/supervisord.pid)"
    return 1
  fi
}
