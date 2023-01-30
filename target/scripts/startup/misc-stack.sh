#!/bin/bash

function _start_misc
{
  _log 'info' 'Starting miscellaneous tasks'
  for FUNC in "${FUNCS_MISC[@]}"
  do
    ${FUNC}
  done
}

# consolidate all states into a single directory
# (/var/mail-state) to allow persistence using docker volumes
function _misc_save_states
{
  local STATEDIR FILE FILES

  STATEDIR='/var/mail-state'

  if [[ ${ONE_DIR} -eq 1 ]] && [[ -d ${STATEDIR} ]]
  then
    _log 'debug' "Consolidating all state onto ${STATEDIR}"

    # Always enabled features:
    FILES=(
      spool/postfix
      lib/postfix
    )

    # Only consolidate state for services that are enabled
    # Notably avoids copying over 200MB for the ClamAV database
    [[ ${ENABLE_AMAVIS} -eq 1 ]] && FILES+=('lib/amavis')
    [[ ${ENABLE_CLAMAV} -eq 1 ]] && FILES+=('lib/clamav')
    [[ ${ENABLE_FAIL2BAN} -eq 1 ]] && FILES+=('lib/fail2ban')
    [[ ${ENABLE_FETCHMAIL} -eq 1 ]] && FILES+=('lib/fetchmail')
    [[ ${ENABLE_POSTGREY} -eq 1 ]] && FILES+=('lib/postgrey')
    [[ ${ENABLE_RSPAMD} -eq 1 ]] && FILES+=('lib/rspamd')
    [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]] && FILES+=('lib/spamassassin')
    [[ ${SMTP_ONLY} -ne 1 ]] && FILES+=('lib/dovecot')

    for FILE in "${FILES[@]}"
    do
      DEST="${STATEDIR}/${FILE//\//-}"
      FILE="/var/${FILE}"

      # If relevant content is found in /var/mail-state (presumably a volume mount),
      # use it instead. Otherwise copy over any missing directories checked.
      if [[ -d ${DEST} ]]
      then
        _log 'trace' "Destination ${DEST} exists, linking ${FILE} to it"
        # Original content from image no longer relevant, remove it:
        rm -rf "${FILE}"
      elif [[ -d ${FILE} ]]
      then
        _log 'trace' "Moving contents of ${FILE} to ${DEST}"
        # Empty volume was mounted, or new content from enabling a feature ENV:
        mv "${FILE}" "${DEST}"
      fi

      # Symlink the original path in the container ($FILE) to be
      # sourced from assocaiated path in /var/mail-state/ ($DEST):
      ln -s "${DEST}" "${FILE}"
    done

    # This ensures the user and group of the files from the external mount have their
    # numeric ID values in sync. New releases where the installed packages order changes
    # can change the values in the Docker image, causing an ownership mismatch.
    # NOTE: More details about users and groups added during image builds are documented here:
    # https://github.com/docker-mailserver/docker-mailserver/pull/3011#issuecomment-1399120252
    _log 'trace' 'Fixing /var/mail-state/* permissions'
    [[ ${ENABLE_AMAVIS}       -eq 1 ]] && chown -R amavis:amavis             /var/mail-state/lib-amavis
    [[ ${ENABLE_CLAMAV}       -eq 1 ]] && chown -R clamav:clamav             /var/mail-state/lib-clamav
    [[ ${ENABLE_FETCHMAIL}    -eq 1 ]] && chown -R fetchmail:nogroup         /var/mail-state/lib-fetchmail
    [[ ${ENABLE_POSTGREY}     -eq 1 ]] && chown -R postgrey:postgrey         /var/mail-state/lib-postgrey
    [[ ${ENABLE_RSPAMD}       -eq 1 ]] && chown -R _rspamd:_rspamd           /var/mail-state/lib-rspamd
    [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]] && chown -R debian-spamd:debian-spamd /var/mail-state/lib-spamassassin

    chown -R postfix:postfix /var/mail-state/lib-postfix

    # NOTE: The Postfix spool location has mixed owner/groups to take into account:
    # UID = postfix(101): active, bounce, corrupt, defer, deferred, flush, hold, incoming, maildrop, private, public, saved, trace
    # UID = root(0): dev, etc, lib, pid, usr
    # GID = postdrop(103): maildrop, public
    # GID for all other directories is root(0)
    # NOTE: `spool-postfix/private/` will be set to `postfix:postfix` when Postfix starts / restarts
    # Set most common ownership:
    chown -R postfix:root /var/mail-state/spool-postfix
    chown root:root /var/mail-state/spool-postfix
    # These two require the postdrop(103) group:
    chgrp -R postdrop /var/mail-state/spool-postfix/maildrop
    chgrp -R postdrop /var/mail-state/spool-postfix/public
    # These all have root ownership at the src location:
    chown -R root /var/mail-state/spool-postfix/dev
    chown -R root /var/mail-state/spool-postfix/etc
    chown -R root /var/mail-state/spool-postfix/lib
    chown -R root /var/mail-state/spool-postfix/pid
    chown -R root /var/mail-state/spool-postfix/usr
  fi
}
