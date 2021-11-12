#! /bin/bash

function start_misc
{
  _notify 'inf' 'Starting miscellaneous tasks'
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
    _notify 'inf' "Consolidating all state onto ${STATEDIR}"

    FILES=(
      spool/postfix
      lib/postfix
      lib/amavis
      lib/clamav
      lib/spamassassin
      lib/fail2ban
      lib/postgrey
      lib/dovecot
    )

    for FILE in "${FILES[@]}"
    do
      DEST="${STATEDIR}/${FILE//\//-}"
      FILE="/var/${FILE}"

      if [[ -d ${DEST} ]]
      then
        _notify 'inf' "Destination ${DEST} exists, linking ${FILE} to it"
        rm -rf "${FILE}"
        ln -s "${DEST}" "${FILE}"
      elif [[ -d ${FILE} ]]
      then
        _notify 'inf' "Moving contents of ${FILE} to ${DEST}"
        mv "${FILE}" "${DEST}"
        ln -s "${DEST}" "${FILE}"
      else
        _notify 'inf' "Linking ${FILE} to ${DEST}"
        mkdir -p "${DEST}"
        ln -s "${DEST}" "${FILE}"
      fi
    done

    _notify 'inf' 'Fixing /var/mail-state/* permissions'
    chown -R clamav /var/mail-state/lib-clamav
    chown -R postfix /var/mail-state/lib-postfix
    chown -R postgrey /var/mail-state/lib-postgrey
    chown -R debian-spamd /var/mail-state/lib-spamassassin

    # UID = postfix(101): active, bounce, corrupt, defer, deferred, flush, hold, incoming, maildrop, private, public, saved, trace
    # UID = root(0): dev, etc, lib, pid, usr
    # GID = postdrop(103): maildrop, public
    # GID for all other directories is root(0)
    # Set most common ownership:
    chown -R postfix:root /var/mail-state/spool-postfix
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
