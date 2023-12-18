#!/bin/bash

declare -a FUNCS_SETUP

function _register_setup_function() {
  FUNCS_SETUP+=("${1}")
  _log 'trace' "${1}() registered"
}

function _setup() {
  # Requires `shopt -s globstar` because of `**` which in
  # turn is required as we're decending through directories
  for FILE in /usr/local/bin/setup.d/**/*.sh; do
    # shellcheck source=/dev/null
    source "${FILE}"
  done

  _log 'info' 'Configuring mail server'
  for FUNC in "${FUNCS_SETUP[@]}"; do
    ${FUNC}
  done

  # All startup modifications to configs should have taken place before calling this:
  _prepare_for_change_detection
}

function _early_supervisor_setup() {
  SUPERVISOR_LOGLEVEL="${SUPERVISOR_LOGLEVEL:-warn}"

  if ! grep -q "loglevel = ${SUPERVISOR_LOGLEVEL}" /etc/supervisor/supervisord.conf; then
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

function _setup_timezone() {
  [[ -n ${TZ} ]] || return 0
  _log 'debug' "Setting timezone to '${TZ}'"

  local ZONEINFO_FILE="/usr/share/zoneinfo/${TZ}"

  if [[ ! -e ${ZONEINFO_FILE} ]]; then
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

function _setup_apply_fixes_after_configuration() {
  _log 'trace' 'Removing leftover PID files from a stop/start'
  find /var/run/ -not -name 'supervisord.pid' -name '*.pid' -delete
  touch /dev/shm/supervisor.sock

  _log 'debug' 'Checking /var/mail permissions'
  if ! _chown_var_mail_if_necessary; then
    _dms_panic__general 'Failed to fix /var/mail permissions'
  fi

  _log 'debug' 'Removing files and directories from older versions'
  rm -rf /var/mail-state/spool-postfix/{dev,etc,lib,pid,usr,private/auth}
}

function _run_user_patches() {
  local USER_PATCHES='/tmp/docker-mailserver/user-patches.sh'

  if [[ -f ${USER_PATCHES} ]]; then
    _log 'debug' 'Applying user patches'
    /bin/bash "${USER_PATCHES}"
  else
    _log 'trace' "No optional '${USER_PATCHES}' provided"
  fi
}
