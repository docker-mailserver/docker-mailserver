#!/bin/bash

# Outputs the DNS label count (delimited by `.`) for the given input string.
# Useful for determining an FQDN like `mail.example.com` (3), vs `example.com` (2).
function _get_label_count
{
  awk -F '.' '{ print NF }' <<< "${1}"
}

# This function is called very early during the setup process, directly after setting up Supervisor.
# It will check whether DNS-related variables (https://docker-mailserver.github.io/docker-mailserver/edge/config/environment/#dns-names)
# are set. If not, it will try to derive the values from the environment.
function _obtain_dns_names
{
  # TODO remove when OVERRIDE_HOSTNAME is dropped in v13.0.0.
  # We return early when OVERRIDE_HOSTNAME is set because it will be used to set the values
  # of the other DNS related variables.
  if [[ -n ${OVERRIDE_HOSTNAME+set} ]]
  then
    return 0
  fi

  if [[ -n ${DMS_FQDN+set} ]]
  then
    _log 'trace' "'DMS_FQDN' supplied"
  else
    _log 'debug' "'DMS_FQDN' not supplied; the value will be derived"
    DMS_FQDN=$(hostname -f)
    _log 'debug' "FQDN has been set to '${DMS_FQDN}'"

  fi

  # `hostname -f`, which derives it's return value from `/etc/hosts` or DNS query,
  # will result in an error that returns an empty value. This warrants a panic.
  if [[ -z ${DMS_FQDN} ]]
  then
    dms_panic__misconfigured 'DMS_FQDN' '/etc/hosts'
  fi

  # Check whether we're running a bare domain (i.e. if `DMS_FQDN`` is more than 2 labels
  # long (eg: mail.example.test).
  if [[ $(_get_label_count "${DMS_FQDN}") -gt 2 ]]
  then
    # using a subdomain
    if [[ -n ${DMS_DOMAINNAME+set} ]]
    then
      _log 'trace' "'DMS_DOMAINNAME' supplied"
    else
      _log 'debug' "'DMS_DOMAINNAME' not supplied; the value will be derived"
      # https://devhints.io/bash#parameter-expansions
      DMS_DOMAINNAME=${DMS_FQDN#*.}
    fi
    if [[ -n ${DMS_HOSTNAME+set} ]]
    then
      _log 'trace' "'DMS_HOSTNAME' supplied"
    else
      _log 'debug' "'DMS_HOSTNAME' not supplied; the value will be derived"
      DMS_HOSTNAME=$(cut -d '.' -f 1 <<< "${DMS_FQDN}")
    fi
  else
    # bare domain
    _log 'debug' 'Detected a bare domain setup'

    # small sanity check
    if [[ -n ${DMS_HOSTNAME+set} ]]
    then
      _log 'warn' "Running a bare domain setup but 'DMS_HOSTNAME' is set - this does not make sense!"
      _log 'warn' "Emptying 'DMS_HOSTNAME' now"
    fi
    DMS_HOSTNAME=

    if [[ -n ${DMS_DOMAINNAME+set} ]]
    then
      _log 'trace' "'DMS_DOMAINNAME' supplied"
    else
      _log 'debug' "'DMS_DOMAINNAME' not supplied; the value will be derived"
      DMS_DOMAINNAME=${DMS_FQDN}
    fi
  fi
}
