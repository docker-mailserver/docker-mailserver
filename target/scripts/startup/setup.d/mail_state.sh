#!/bin/bash

# Consolidate all states into a single directory
# (/var/mail-state) to allow persistence using docker volumes
function _setup_save_states() {
  local DEST DESTDIR STATEDIR SERVICEDIR SERVICEDIRS SERVICEFILE SERVICEFILES

  STATEDIR='/var/mail-state'

  if [[ ${ONE_DIR} -eq 1 ]] && [[ -d ${STATEDIR} ]]; then
    _log 'debug' "Consolidating all state onto ${STATEDIR}"

    # Always enabled features:
    SERVICEDIRS=(
      lib/logrotate
      lib/postfix
      spool/postfix
    )

    # Only consolidate state for services that are enabled
    # Notably avoids copying over 200MB for the ClamAV database
    [[ ${ENABLE_AMAVIS}       -eq 1 ]] && SERVICEDIRS+=('lib/amavis')
    [[ ${ENABLE_CLAMAV}       -eq 1 ]] && SERVICEDIRS+=('lib/clamav')
    [[ ${ENABLE_FAIL2BAN}     -eq 1 ]] && SERVICEDIRS+=('lib/fail2ban')
    [[ ${ENABLE_FETCHMAIL}    -eq 1 ]] && SERVICEDIRS+=('lib/fetchmail')
    [[ ${ENABLE_GETMAIL}      -eq 1 ]] && SERVICEDIRS+=('lib/getmail')
    [[ ${ENABLE_POSTGREY}     -eq 1 ]] && SERVICEDIRS+=('lib/postgrey')
    [[ ${ENABLE_RSPAMD}       -eq 1 ]] && SERVICEDIRS+=('lib/rspamd')
    [[ ${ENABLE_RSPAMD_REDIS} -eq 1 ]] && SERVICEDIRS+=('lib/redis')
    [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]] && SERVICEDIRS+=('lib/spamassassin')
    [[ ${ENABLE_SRS}          -eq 1 ]] && SERVICEDIRS+=('lib/postsrsd')
    [[ ${SMTP_ONLY}           -ne 1 ]] && SERVICEDIRS+=('lib/dovecot')

    # Single service files
    [[ ${ENABLE_SRS}          -eq 1 ]] && SERVICEFILES+=('/etc/postsrsd.secret')

    for SERVICEFILE in "${SERVICEFILES[@]}"; do
      DEST="${STATEDIR}/${SERVICEFILE}"
      DESTDIR="${DEST%/*}"

      mkdir -p "${DESTDIR}"
      if [[ -f ${DEST} ]]; then
        _log 'trace' "Destination ${DEST} exists, linking ${SERVICEFILE} to it"
        # Original content from image no longer relevant, remove it:
        rm -f "${SERVICEFILE}"
      elif [[ -f "${SERVICEFILE}" ]]; then
        _log 'trace' "Moving ${SERVICEFILE} to ${DEST}"
        # Empty volume was mounted, or new content from enabling a feature ENV:
        mv "${SERVICEFILE}" "${DEST}"
      fi

      # Symlink the original file in the container ($SERVICEFILE) to be
      # sourced from assocaiated path in /var/mail-state/ ($DEST):
      ln -s "${DEST}" "${SERVICEFILE}"
    done

    for SERVICEDIR in "${SERVICEDIRS[@]}"; do
      DEST="${STATEDIR}/${SERVICEDIR//\//-}"
      SERVICEDIR="/var/${SERVICEDIR}"

      # If relevant content is found in /var/mail-state (presumably a volume mount),
      # use it instead. Otherwise copy over any missing directories checked.
      if [[ -d ${DEST} ]]; then
        _log 'trace' "Destination ${DEST} exists, linking ${SERVICEDIR} to it"
        # Original content from image no longer relevant, remove it:
        rm -rf "${SERVICEDIR}"
      elif [[ -d ${SERVICEDIR} ]]; then
        _log 'trace' "Moving contents of ${SERVICEDIR} to ${DEST}"
        # Empty volume was mounted, or new content from enabling a feature ENV:
        mv "${SERVICEDIR}" "${DEST}"
      fi

      # Symlink the original path in the container ($SERVICEDIR) to be
      # sourced from assocaiated path in /var/mail-state/ ($DEST):
      ln -s "${DEST}" "${SERVICEDIR}"
    done

    # This ensures the user and group of the files from the external mount have their
    # numeric ID values in sync. New releases where the installed packages order changes
    # can change the values in the Docker image, causing an ownership mismatch.
    # NOTE: More details about users and groups added during image builds are documented here:
    # https://github.com/docker-mailserver/docker-mailserver/pull/3011#issuecomment-1399120252
    _log 'trace' "Fixing ${STATEDIR}/* permissions"
    [[ ${ENABLE_AMAVIS}       -eq 1 ]] && chown -R amavis:amavis             "${STATEDIR}/lib-amavis"
    [[ ${ENABLE_CLAMAV}       -eq 1 ]] && chown -R clamav:clamav             "${STATEDIR}/lib-clamav"
    [[ ${ENABLE_FETCHMAIL}    -eq 1 ]] && chown -R fetchmail:nogroup         "${STATEDIR}/lib-fetchmail"
    [[ ${ENABLE_POSTGREY}     -eq 1 ]] && chown -R postgrey:postgrey         "${STATEDIR}/lib-postgrey"
    [[ ${ENABLE_RSPAMD}       -eq 1 ]] && chown -R _rspamd:_rspamd           "${STATEDIR}/lib-rspamd"
    [[ ${ENABLE_RSPAMD_REDIS} -eq 1 ]] && chown -R redis:redis               "${STATEDIR}/lib-redis"
    [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]] && chown -R debian-spamd:debian-spamd "${STATEDIR}/lib-spamassassin"

    chown -R root:root "${STATEDIR}/lib-logrotate"
    chown -R postfix:postfix "${STATEDIR}/lib-postfix"

    # NOTE: The Postfix spool location has mixed owner/groups to take into account:
    # UID = postfix(101): active, bounce, corrupt, defer, deferred, flush, hold, incoming, maildrop, private, public, saved, trace
    # UID = root(0): dev, etc, lib, pid, usr
    # GID = postdrop(103): maildrop, public
    # GID for all other directories is root(0)
    # NOTE: `spool-postfix/private/` will be set to `postfix:postfix` when Postfix starts / restarts
    # Set most common ownership:
    chown -R postfix:root "${STATEDIR}/spool-postfix"
    chown root:root "${STATEDIR}/spool-postfix"

    # These two require the postdrop(103) group:
    chgrp -R postdrop "${STATEDIR}"/spool-postfix/{maildrop,public}

    # After changing the group, special bits (set-gid, sticky) may be stripped, restore them:
    # Ref: https://github.com/docker-mailserver/docker-mailserver/pull/3149#issuecomment-1454981309
    chmod 1730 "${STATEDIR}/spool-postfix/maildrop"
    chmod 2710 "${STATEDIR}/spool-postfix/public"
  elif [[ ${ONE_DIR} -eq 1 ]]; then
    _log 'warn' "'ONE_DIR=1' but no volume was mounted to '${STATEDIR}'"
  else
    _log 'debug' 'Not consolidating state (because it has been disabled)'
  fi
}
