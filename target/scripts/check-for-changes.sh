#! /bin/bash

# shellcheck source=./helper-functions.sh
. /usr/local/bin/helper-functions.sh

LOG_DATE=$(date +"%Y-%m-%d %H:%M:%S ")
_notify 'task' "${LOG_DATE} Start check-for-changes script."

# ? --------------------------------------------- Checks

cd /tmp/docker-mailserver || exit 1

# check postfix-accounts.cf exist else break
if [[ ! -f postfix-accounts.cf ]]
then
  _notify 'inf' "${LOG_DATE} postfix-accounts.cf is missing! This should not run! Exit!"
  exit 0
fi

# verify checksum file exists; must be prepared by start-mailserver.sh
if [[ ! -f ${CHKSUM_FILE} ]]
then
  _notify 'err' "${LOG_DATE} ${CHKSUM_FILE} is missing! Start script failed? Exit!"
  exit 0
fi

# ? --------------------------------------------- Actual script begins

# determine postmaster address, duplicated from start-mailserver.sh
# this script previously didn't work when POSTMASTER_ADDRESS was empty
_obtain_hostname_and_domainname

PM_ADDRESS="${POSTMASTER_ADDRESS:=postmaster@${DOMAINNAME}}"
_notify 'inf' "${LOG_DATE} Using postmaster address ${PM_ADDRESS}"
sleep 10

while true
do
  LOG_DATE=$(date +"%Y-%m-%d %H:%M:%S ")

  # get chksum and check it, no need to lock config yet
  _monitored_files_checksums >"${CHKSUM_FILE}.new"
  cmp --silent -- "${CHKSUM_FILE}" "${CHKSUM_FILE}.new"
  # cmp return codes
  # 0 – files are identical
  # 1 – files differ
  # 2 – inaccessible or missing argument
  if [ $? -eq 1 ]
  then
    _notify 'inf' "${LOG_DATE} Change detected"
    create_lock # Shared config safety lock
    CHANGED=$(grep -Fxvf "${CHKSUM_FILE}" "${CHKSUM_FILE}.new" | sed 's/^[^ ]\+  //')

    # Bug alert! This overwrites the alias set by start-mailserver.sh
    # Take care that changes in one script are propagated to the other

    # ! NEEDS FIX -----------------------------------------
    # TODO FIX --------------------------------------------
    # ! NEEDS EXTENSIONS ----------------------------------
    # TODO Perform updates below conditionally too --------
    # Also note that changes are performed in place and are not atomic
    # We should fix that and write to temporary files, stop, swap and start

    for FILE in ${CHANGED}
    do
      case "${FILE}" in
        "/etc/letsencrypt/acme.json" )
          for CERTDOMAIN in ${SSL_DOMAIN} ${HOSTNAME} ${DOMAINNAME}
          do
            _extract_certs_from_acme "${CERTDOMAIN}" && break
          done
          ;;

        * )
          _notify 'warn' 'File not found for certificate in check_for_changes.sh'
          ;;

      esac
    done

    # regenerate postix aliases
    echo "root: ${PM_ADDRESS}" >/etc/aliases
    if [[ -f /tmp/docker-mailserver/postfix-aliases.cf ]]
    then
      cat /tmp/docker-mailserver/postfix-aliases.cf >>/etc/aliases
    fi
    postalias /etc/aliases

    # regenerate postfix accounts
    _create_accounts

    _rebuild_relayhost

    if [[ -f postfix-virtual.cf ]]
    then
      # regenerate postfix aliases
      : >/etc/postfix/virtual
      : >/etc/postfix/regexp

      if [[ -f /tmp/docker-mailserver/postfix-virtual.cf ]]
      then
        cp -f /tmp/docker-mailserver/postfix-virtual.cf /etc/postfix/virtual

        # the `to` seems to be important; don't delete it
        # shellcheck disable=SC2034
        while read -r FROM TO
        do
          UNAME=$(echo "${FROM}" | cut -d @ -f1)
          DOMAIN=$(echo "${FROM}" | cut -d @ -f2)

          # if they are equal it means the line looks like: "user1	 other@domain.tld"
          [ "${UNAME}" != "${DOMAIN}" ] && echo "${DOMAIN}" >>/tmp/vhost.tmp
        done  < <(grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-virtual.cf || true)
      fi

      if [[ -f /tmp/docker-mailserver/postfix-regexp.cf ]]
      then
        cp -f /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp
        sed -i -e '/^virtual_alias_maps/{
s/ regexp:.*//
s/$/ regexp:\/etc\/postfix\/regexp/
}' /etc/postfix/main.cf
      fi
    fi

    if [[ -f /tmp/vhost.tmp ]]
    then
      sort < /tmp/vhost.tmp | uniq >/etc/postfix/vhost
      rm /tmp/vhost.tmp
    fi

    if find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | read -r
    then
      chown -R 5000:5000 /var/mail
    fi

    supervisorctl restart postfix

    # prevent restart of dovecot when smtp_only=1
    [[ ${SMTP_ONLY} -ne 1 ]] && supervisorctl restart dovecot

    remove_lock
  fi

  # mark changes as applied
  mv "${CHKSUM_FILE}.new" "${CHKSUM_FILE}"

  sleep 1
done

exit 0
