#!/bin/bash

DMS_STATE_DIR='/var/mail-state'

# Consolidate all states into a single directory
# (/var/mail-state) to allow persistence using docker volumes
function _setup_save_states() {
  if [[ ! -d ${DMS_STATE_DIR} ]]; then
    _log 'debug' "'${DMS_STATE_DIR}' is not present - not consolidating state"
    return 0
  fi

  _log 'debug' "Consolidating all state onto ${DMS_STATE_DIR}"

  local DEST SERVICEDIR SERVICEDIRS SERVICEFILE SERVICEFILES

  # Always enabled features:
  SERVICEDIRS=(
    'lib/logrotate'
    'lib/postfix'
    'spool/postfix'
  )

  # Only consolidate state for services that are enabled
  # Notably avoids copying over 200MB for the ClamAV database
  [[ ${ENABLE_AMAVIS}       -eq 1 ]] && SERVICEDIRS+=('lib/amavis')
  [[ ${ENABLE_CLAMAV}       -eq 1 ]] && SERVICEDIRS+=('lib/clamav')
  [[ ${ENABLE_FAIL2BAN}     -eq 1 ]] && SERVICEDIRS+=('lib/fail2ban')
  [[ ${ENABLE_FETCHMAIL}    -eq 1 ]] && SERVICEDIRS+=('lib/fetchmail')
  [[ ${ENABLE_GETMAIL}      -eq 1 ]] && SERVICEDIRS+=('lib/getmail')
  [[ ${ENABLE_MTA_STS}      -eq 1 ]] && SERVICEDIRS+=('lib/mta-sts')
  [[ ${ENABLE_POSTGREY}     -eq 1 ]] && SERVICEDIRS+=('lib/postgrey')
  [[ ${ENABLE_RSPAMD}       -eq 1 ]] && SERVICEDIRS+=('lib/rspamd')
  [[ ${ENABLE_RSPAMD_REDIS} -eq 1 ]] && SERVICEDIRS+=('lib/redis')
  [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]] && SERVICEDIRS+=('lib/spamassassin')
  [[ ${ENABLE_SRS}          -eq 1 ]] && SERVICEDIRS+=('lib/postsrsd')
  [[ ${SMTP_ONLY}           -ne 1 ]] && SERVICEDIRS+=('lib/dovecot')

  # Single service files
  [[ ${ENABLE_SRS}          -eq 1 ]] && SERVICEFILES+=('/etc/postsrsd.secret')

  for SERVICEFILE in "${SERVICEFILES[@]}"; do
    DEST="${DMS_STATE_DIR}/${SERVICEFILE}"

    # Append service parent dir(s) path to the state dir and ensure it exists:
    mkdir -p "${DEST%/*}"
    if [[ -f ${DEST} ]]; then
      _log 'trace' "Destination ${DEST} exists, linking ${SERVICEFILE} to it"
      # Original content from image no longer relevant, remove it:
      rm -f "${SERVICEFILE}"
    elif [[ -f "${SERVICEFILE}" ]]; then
      _log 'trace' "Moving ${SERVICEFILE} to ${DEST}"
      # Empty volume was mounted, or new content from enabling a feature ENV:
      mv "${SERVICEFILE}" "${DEST}"
      # Apply SELinux security context to match the state directory, so access
      # is not restricted to the current running container:
      chcon -R --reference="${DMS_STATE_DIR}" "${DEST}" 2>/dev/null || true
    fi

    # Symlink the original file in the container ($SERVICEFILE) to be
    # sourced from assocaiated path in /var/mail-state/ ($DEST):
    ln -s "${DEST}" "${SERVICEFILE}"
  done

  for SERVICEDIR in "${SERVICEDIRS[@]}"; do
    DEST="${DMS_STATE_DIR}/${SERVICEDIR//\//-}"
    SERVICEDIR="/var/${SERVICEDIR}"

    # If relevant content is found in /var/mail-state (presumably a volume mount),
    # use it instead. Otherwise copy over any missing directories checked.
    if [[ -d ${DEST} ]]; then
      _log 'trace' "Destination ${DEST} exists, linking ${SERVICEDIR} to it"
      # Original content from image no longer relevant, remove it:
      rm -rf "${SERVICEDIR}"
    elif [[ -d ${SERVICEDIR} ]]; then
      _log 'trace' "Moving contents of ${SERVICEDIR} to ${DEST}"
      # An empty volume was mounted, or new content dir now exists from enabling a feature ENV:
      mv "${SERVICEDIR}" "${DEST}"
      # Apply SELinux security context to match the state directory, so access
      # is not restricted to the current running container:
      # https://github.com/docker-mailserver/docker-mailserver/pull/3890
      chcon -R --reference="${DMS_STATE_DIR}" "${DEST}" 2>/dev/null || true
    else
      _log 'error' "${SERVICEDIR} should exist but is missing"
    fi

    # Symlink the original path in the container ($SERVICEDIR) to be
    # sourced from associated path in /var/mail-state/ ($DEST):
    ln -s "${DEST}" "${SERVICEDIR}"
  done
}

# These corrections are to fix changes to UID/GID values between upgrades,
# or when ownership/permissions were altered externally on the host (eg: migration or system scripts)
function _setup_adjust_state_permissions() {
  [[ ! -d ${DMS_STATE_DIR} ]] && return 0

  # Parent directories must have executable bit set to descend the file tree for access,
  # as each service running as a non-root user requires this to access their state directory,
  # `/var/mail-state` must allow all users `+x`:
  chmod +x "${DMS_STATE_DIR}"

  # This ensures the user and group of the files from the external mount have their
  # numeric ID values in sync. New releases where the installed packages order changes
  # can change the values in the Docker image, causing an ownership mismatch.
  # NOTE: More details about users and groups added during image builds are documented here:
  # https://github.com/docker-mailserver/docker-mailserver/pull/3011#issuecomment-1399120252
  _log 'trace' "Ensuring correct ownership + permissions for DMS state dir: '${DMS_STATE_DIR}'"
  [[ ${ENABLE_AMAVIS}       -eq 1 ]] && chown -R amavis:amavis             "${DMS_STATE_DIR}/lib-amavis"
  [[ ${ENABLE_CLAMAV}       -eq 1 ]] && chown -R clamav:clamav             "${DMS_STATE_DIR}/lib-clamav"
  [[ ${ENABLE_FETCHMAIL}    -eq 1 ]] && chown -R fetchmail:nogroup         "${DMS_STATE_DIR}/lib-fetchmail"
  [[ ${ENABLE_MTA_STS}      -eq 1 ]] && chown -R _mta-sts:_mta-sts         "${DMS_STATE_DIR}/lib-mta-sts"
  [[ ${ENABLE_POSTGREY}     -eq 1 ]] && chown -R postgrey:postgrey         "${DMS_STATE_DIR}/lib-postgrey"
  [[ ${ENABLE_RSPAMD}       -eq 1 ]] && chown -R _rspamd:_rspamd           "${DMS_STATE_DIR}/lib-rspamd"
  [[ ${ENABLE_RSPAMD_REDIS} -eq 1 ]] && chown -R redis:redis               "${DMS_STATE_DIR}/lib-redis"
  [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]] && chown -R debian-spamd:debian-spamd "${DMS_STATE_DIR}/lib-spamassassin"

  chown -R root:root "${DMS_STATE_DIR}/lib-logrotate"
  chown -R postfix:postfix "${DMS_STATE_DIR}/lib-postfix"

  # NOTE: The Postfix spool location has mixed owner/groups to take into account:
  # UID = postfix(101): active, bounce, corrupt, defer, deferred, flush, hold, incoming, maildrop, private, public, saved, trace
  # UID = root(0): dev, etc, lib, pid, usr
  # GID = postdrop(103): maildrop, public
  # GID for all other directories is root(0)
  # NOTE: `spool-postfix/private/` will be set to `postfix:postfix` when Postfix starts / restarts
  # Set most common ownership:
  chown -R postfix:root "${DMS_STATE_DIR}/spool-postfix"
  chown root:root "${DMS_STATE_DIR}/spool-postfix"

  # These two require the postdrop(103) group:
  chgrp -R postdrop "${DMS_STATE_DIR}"/spool-postfix/{maildrop,public}

  # These permissions rely on the `postdrop` binary having the SGID bit set.
  # Ref: https://github.com/docker-mailserver/docker-mailserver/pull/3625
  chmod 730 "${DMS_STATE_DIR}/spool-postfix/maildrop"
  chmod 710 "${DMS_STATE_DIR}/spool-postfix/public"
}
