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

  _setup_post
}

function _setup_post() {
  # Dovecot `.svbin` files must have a newer mtime than their `.sieve` source files,
  # Modifications during setup to these files sometimes results in a common mtime value.
  # Handled during post-setup as setup of Dovecot Sieve scripts is not centralized.
  find /usr/lib/dovecot/ -iname '*.sieve' -exec touch -d '2 seconds ago' {} +
  find /usr/lib/dovecot/ -iname '*.svbin' -exec touch -d '1 seconds ago' {} +

  # All startup modifications to configs should have taken place before calling this:
  _prepare_for_change_detection
}

function _early_supervisor_setup() {
  SUPERVISOR_LOGLEVEL="${SUPERVISOR_LOGLEVEL:-warn}"

  if ! grep -q "loglevel = ${SUPERVISOR_LOGLEVEL}" /etc/supervisor/supervisord.conf; then
    case "${SUPERVISOR_LOGLEVEL}" in
      ( 'critical' | 'error' | 'info' | 'debug' )
        sedfile -i -E \
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

# Misc checks and fixes migrated here until next refactor:
# NOTE: `start-mailserver.sh` runs this along with `mail-state.sh` during container restarts
function _setup_directory_and_file_permissions() {
  _log 'trace' 'Removing leftover PID files from a stop/start'
  find /var/run/ -not -name 'supervisord.pid' -name '*.pid' -delete
  touch /dev/shm/supervisor.sock

  _log 'debug' 'Checking /var/mail permissions'
  if ! _chown_var_mail_if_necessary; then
    _dms_panic__general 'Failed to fix /var/mail permissions'
  fi

  _log 'debug' 'Removing files and directories from older versions'
  rm -rf /var/mail-state/spool-postfix/{dev,etc,lib,pid,usr,private/auth}

  _rspamd_get_envs
  # /tmp/docker-mailserver/rspamd/dkim
  if [[ -d ${RSPAMD_DMS_DKIM_D} ]]; then
    _log 'debug' "Ensuring '${RSPAMD_DMS_DKIM_D}' is owned by '_rspamd:_rspamd'"
    chown -R _rspamd:_rspamd "${RSPAMD_DMS_DKIM_D}"
  fi

  __log_fixes
}

function _setup_run_user_patches() {
  local USER_PATCHES='/tmp/docker-mailserver/user-patches.sh'

  if [[ -f ${USER_PATCHES} ]]; then
    _log 'debug' 'Applying user patches'
    /bin/bash "${USER_PATCHES}"
  else
    _log 'trace' "No optional '${USER_PATCHES}' provided"
  fi
}

function __log_fixes() {
  _log 'debug' 'Ensuring /var/log/mail owneership + permissions are correct'

  # File/folder permissions are fine when using docker volumes, but may be wrong
  # when file system folders are mounted into the container.
  # Set the expected values and create missing folders/files just in case.
  mkdir -p /var/log/{mail,supervisor}

  # TODO: Remove these lines in a future release once concerns are resolved:
  # https://github.com/docker-mailserver/docker-mailserver/pull/4370#issuecomment-2661762043
  chown syslog:root /var/log/mail

  if [[ ${ENABLE_CLAMAV} -eq 1 ]]; then
    # TODO: Consider assigning /var/log/mail a writable non-root group for other processes like ClamAV?
    # - Check if ClamAV is capable of creating files itself when they're missing?
    # - Alternatively a symlink to /var/log/mail from the original intended location would allow write access
    #   as a user to the symlink location, while keeping ownership as root at /var/log/mail
    # - `LogSyslog false` for clamd.conf + freshclam.conf could possibly be enabled instead of log files?
    #   However without better filtering in place (once Vector is adopted), this should be avoided.
    touch /var/log/mail/{clamav,freshclam}.log
    chown clamav:adm /var/log/mail/{clamav,freshclam}.log
  fi

  # Volume permissions should be corrected:
  # https://github.com/docker-mailserver/docker-mailserver-helm/issues/137
  chmod 755 /var/log/mail/
  find /var/log/mail/ -type f -exec chmod 640 {} +
}
