#!/bin/bash

# Docs - Config:
# https://www.fetchmail.info/fetchmail-man.html#the-run-control-file
# Docs - CLI:
# https://www.fetchmail.info/fetchmail-man.html#general-operation
# https://www.fetchmail.info/fetchmail-man.html#daemon-mode

function _setup_fetchmail() {
  if [[ ${ENABLE_FETCHMAIL} -eq 1 ]]; then
    _log 'trace' 'Enabling and configuring Fetchmail'

    local CONFIGURATION FETCHMAILRC

    CONFIGURATION='/tmp/docker-mailserver/fetchmail.cf'
    FETCHMAILRC='/etc/fetchmailrc'

    # Create `/etc/fetchmailrc` with default global config, optionally appending user-provided config:
    if [[ -f ${CONFIGURATION} ]]; then
      cat /etc/fetchmailrc_general "${CONFIGURATION}" >"${FETCHMAILRC}"
    else
      cat /etc/fetchmailrc_general >"${FETCHMAILRC}"
    fi

    chmod 700 "${FETCHMAILRC}"
    chown fetchmail:root "${FETCHMAILRC}"
  else
    _log 'debug' 'Fetchmail is disabled'
  fi
}

# NOTE: This feature is only actually relevant for entries polling via IMAP (to support leveraging the "IMAP IDLE" extension):
# - With either the `--idle` CLI or `idle` config option present
# - With a constraint on one fetchmail instance per server polled (and only for a single mailbox folder to monitor from that poll entry)
# - Reference: https://otremba.net/wiki/Fetchmail_(Debian)#Immediate_Download_via_IMAP_IDLE
function _setup_fetchmail_parallel() {
  if [[ ${FETCHMAIL_PARALLEL} -eq 1 ]]; then
    _log 'trace' 'Enabling and configuring Fetchmail parallel'
    mkdir /etc/fetchmailrc.d/

    # Extract the content of `/etc/fetchmailrc` into:
    # - Individual `/etc/fetchmailrc.d/fetchmail-*.rc` files, one per server (`poll` entries)
    # - Global config options temporarily to `/etc/fetchmailrc.d/defaults`, which is prepended to each `fetchmail-*.rc` file
    function _fetchmailrc_split() {
      local FETCHMAILRC='/etc/fetchmailrc'
      local FETCHMAILRCD='/etc/fetchmailrc.d'
      local DEFAULT_FILE="${FETCHMAILRCD}/defaults"

      if [[ ! -r ${FETCHMAILRC} ]]; then
        _log 'warn' "File '${FETCHMAILRC}' not found"
        return 1
      fi

      if [[ ! -d ${FETCHMAILRCD} ]]; then
        if ! mkdir "${FETCHMAILRCD}"; then
          _log 'warn' "Unable to create folder '${FETCHMAILRCD}'"
          return 1
        fi
      fi

      # Scan through the config:
      # 1. Extract the global fetchmail config lines (before any poll entry is configured).
      # 2. Once a poll entry line is found, create a new config with the global config and append the poll entry config.
      # 3. Repeat step 2 when another poll entry is found, until reaching the end of `/etc/fetchmailrc`.
      local COUNTER=0 SERVER=0
      while read -r LINE; do
        if [[ ${LINE} =~ poll ]]; then
          # Signal that global config has been captured (only remaining poll entry configs needs to be parsed):
          SERVER=1

          # Create a new fetchmail config for this poll entry:
          COUNTER=$(( COUNTER + 1 ))
          cat "${DEFAULT_FILE}" >"${FETCHMAILRCD}/fetchmail-${COUNTER}.rc"
          echo "${LINE}" >>"${FETCHMAILRCD}/fetchmail-${COUNTER}.rc"
        elif [[ ${SERVER} -eq 0 ]]; then
          # Until the first poll entry is encountered, all lines are captured as global config:
          echo "${LINE}" >>"${DEFAULT_FILE}"
        else
          # Otherwise until a new poll entry is encountered, all lines are captured for the current poll config:
          echo "${LINE}" >>"${FETCHMAILRCD}/fetchmail-${COUNTER}.rc"
        fi
      done < <(_get_valid_lines_from_file "${FETCHMAILRC}")

      rm "${DEFAULT_FILE}"
    }

    _fetchmailrc_split

    # Create supervisord service files for each instance:
    # `--idfile` is intended for supporting POP3 with UIDL cache (requires either `--uidl` for CLI, or `uidl` setting in config)
    local COUNTER=0
    for RC in /etc/fetchmailrc.d/fetchmail-*.rc; do
      COUNTER=$(( COUNTER + 1 ))
      cat >"/etc/supervisor/conf.d/fetchmail-${COUNTER}.conf" << EOF
[program:fetchmail-${COUNTER}]
startsecs=0
autostart=false
autorestart=true
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log
user=fetchmail
command=/usr/bin/fetchmail --fetchmailrc ${RC} --verbose --nodetach --daemon %(ENV_FETCHMAIL_POLL)s --idfile /var/lib/fetchmail/.fetchmail-UIDL-cache --pidfile /var/run/fetchmail/%(program_name)s.pid
EOF

      chmod 700 "${RC}"
      chown fetchmail:root "${RC}"
    done

    supervisorctl reread
    supervisorctl update
  else
    _log 'debug' 'Fetchmail parallel is disabled'
  fi
}
