#!/bin/bash

# Outputs the DNS label count (delimited by `.`) for the given input string.
# Useful for determining an FQDN like `mail.example.com` (3), vs `example.com` (2).
function _get_label_count
{
  awk -F '.' '{ print NF }' <<< "${1}"
}

# This function is called very early during the setup process, directly after setting up Supervisor.
#
# ATTENTION: This function should only be called once! If you need access to ENV
# variables, use `source /etc/dms-settings`.
#
# This function will check whether DNS-related variables
# (https://docker-mailserver.github.io/docker-mailserver/edge/config/environment/#dns-names)
# are set. If not, it will try to derive the values from the environment.
#
# NOTE: This function touches `/etc/hostname` and `/etc/hosts` to ensure they are in-sync
# with DMS. This is required as some tools (like `openssl`) use these files.
function _handle_dns_names
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

    echo "${DMS_HOSTNAME}" >/etc/hostname
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

    echo "${DMS_FQDN}" >/etc/hostname
  fi

  # handle /etc/hosts as well
  # tools like `openssl` require this to be correctc
  echo " IP              FQDN (CANONICAL_HOSTNAME)    ALIASES
# --------------  ---------------------------  -----------------------

127.0.0.1         localhost
127.0.1.1         ${DMS_FQDN}   ${DMS_HOSTNAME}" >/etc/hosts 2>/dev/null

  if [[ $(tr -d '\n' < /sys/module/ipv6/parameters/disable) -eq 0 ]]
  then
    echo "

# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters" >>/etc/hosts 2>/dev/null
  fi
}
