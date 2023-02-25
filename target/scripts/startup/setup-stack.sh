#!/bin/bash

function _setup
{
  _log 'info' 'Configuring mail server'
  for FUNC in "${FUNCS_SETUP[@]}"
  do
    ${FUNC}
  done

  # All startup modifications to configs should have taken place before calling this:
  _prepare_for_change_detection
}

function _setup_supervisor
{
  SUPERVISOR_LOGLEVEL="${SUPERVISOR_LOGLEVEL:-warn}"

  if ! grep -q "loglevel = ${SUPERVISOR_LOGLEVEL}" /etc/supervisor/supervisord.conf
  then
    case "${SUPERVISOR_LOGLEVEL}" in
      ( 'critical' | 'error' | 'info' | 'debug' )
        sed -i -E \
          "s|(loglevel).*|\1 = ${SUPERVISOR_LOGLEVEL}|g" \
          /etc/supervisor/supervisord.conf

        supervisorctl reload
        exit
        ;;

      ( 'warn' ) ;;

      ( * )
        _log 'warn' \
          "SUPERVISOR_LOGLEVEL '${SUPERVISOR_LOGLEVEL}' unknown. Using default 'warn'"
        ;;

    esac
  fi

  return 0
}

# File/folder permissions are fine when using docker volumes, but may be wrong
# when file system folders are mounted into the container.
# Set the expected values and create missing folders/files just in case.
function _setup_file_permissions
{
  _log 'debug' 'Setting file and directory permissions'

  mkdir -p /var/log/supervisor

  mkdir -p /var/log/mail
  chown syslog:root /var/log/mail

  touch /var/log/mail/clamav.log
  chown clamav:adm /var/log/mail/clamav.log
  chmod 640 /var/log/mail/clamav.log

  touch /var/log/mail/freshclam.log
  chown clamav:adm /var/log/mail/freshclam.log
  chmod 640 /var/log/mail/freshclam.log
}

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

function _setup_user_patches
{
  local USER_PATCHES='/tmp/docker-mailserver/user-patches.sh'

  if [[ -f ${USER_PATCHES} ]]
  then
    _log 'debug' 'Applying user patches'
    /bin/bash "${USER_PATCHES}"
  else
    _log 'trace' "No optional '${USER_PATCHES}' provided"
  fi
}

function _setup_timezone
{
  [[ -n ${TZ} ]] || return 0
  _log 'debug' "Setting timezone to '${TZ}'"

  local ZONEINFO_FILE="/usr/share/zoneinfo/${TZ}"

  if [[ ! -e ${ZONEINFO_FILE} ]]
  then
    _log 'warn' "Cannot find timezone '${TZ}'"
    return 1
  fi

  if ln -fs "${ZONEINFO_FILE}" /etc/localtime \
  && dpkg-reconfigure -f noninteractive tzdata &>/dev/null
  then
    _log 'trace' "Set time zone to '${TZ}'"
  else
    _log 'warn' "Setting timezone to '${TZ}' failed"
    return 1
  fi
}
