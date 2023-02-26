#!/bin/bash

function _setup_dhparam
{
  local DH_SERVICE=$1
  local DH_DEST=$2
  local DH_CUSTOM='/tmp/docker-mailserver/dhparams.pem'

  _log 'debug' "Setting up ${DH_SERVICE} dhparam"

  if [[ -f ${DH_CUSTOM} ]]
  then # use custom supplied dh params (assumes they're probably insecure)
    _log 'trace' "${DH_SERVICE} will use custom provided DH paramters"
    _log 'warn' "Using self-generated dhparams is considered insecure - unless you know what you are doing, please remove '${DH_CUSTOM}'"

    cp -f "${DH_CUSTOM}" "${DH_DEST}"
  else # use official standardized dh params (provided via Dockerfile)
    _log 'trace' "${DH_SERVICE} will use official standardized DH parameters (ffdhe4096)."
  fi
}
