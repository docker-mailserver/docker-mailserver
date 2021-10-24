#! /bin/bash
# Support for Postfix accounts managed via Dovecot

function _create_accounts
{
  : >/etc/postfix/vmailbox
  : >/etc/dovecot/userdb

  if [[ -f /tmp/docker-mailserver/postfix-accounts.cf ]] && [[ ${ENABLE_LDAP} -ne 1 ]]
  then
    _notify 'inf' "Checking file line endings"
    sed -i 's|\r||g' /tmp/docker-mailserver/postfix-accounts.cf

    _notify 'inf' "Regenerating postfix user list"
    echo "# WARNING: this file is auto-generated. Modify /tmp/docker-mailserver/postfix-accounts.cf to edit the user list." > /etc/postfix/vmailbox

    # checking that /tmp/docker-mailserver/postfix-accounts.cf ends with a newline
    # shellcheck disable=SC1003
    sed -i -e '$a\' /tmp/docker-mailserver/postfix-accounts.cf

    chown dovecot:dovecot /etc/dovecot/userdb
    chmod 640 /etc/dovecot/userdb

    sed -i -e '/\!include auth-ldap\.conf\.ext/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
    sed -i -e '/\!include auth-passwdfile\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf

    # creating users ; 'pass' is encrypted
    # comments and empty lines are ignored
    while IFS=$'|' read -r LOGIN PASS USER_ATTRIBUTES
    do
      # Setting variables for better readability
      USER=$(echo "${LOGIN}" | cut -d @ -f1)
      DOMAIN=$(echo "${LOGIN}" | cut -d @ -f2)

      # test if user has a defined quota
      if [[ -f /tmp/docker-mailserver/dovecot-quotas.cf ]]
      then
        declare -a USER_QUOTA
        IFS=':' ; read -r -a USER_QUOTA < <(grep "${USER}@${DOMAIN}:" -i /tmp/docker-mailserver/dovecot-quotas.cf)
        unset IFS

        [[ ${#USER_QUOTA[@]} -eq 2 ]] && USER_ATTRIBUTES="${USER_ATTRIBUTES} userdb_quota_rule=*:bytes=${USER_QUOTA[1]}"
      fi

      # Let's go!
      _notify 'inf' "user '${USER}' for domain '${DOMAIN}' with password '********', attr=${USER_ATTRIBUTES}"

      echo "${LOGIN} ${DOMAIN}/${USER}/" >> /etc/postfix/vmailbox
      # User database for dovecot has the following format:
      # user:password:uid:gid:(gecos):home:(shell):extra_fields
      # Example :
      # ${LOGIN}:${PASS}:5000:5000::/var/mail/${DOMAIN}/${USER}::userdb_mail=maildir:/var/mail/${DOMAIN}/${USER}
      echo "${LOGIN}:${PASS}:5000:5000::/var/mail/${DOMAIN}/${USER}::${USER_ATTRIBUTES}" >> /etc/dovecot/userdb
      mkdir -p "/var/mail/${DOMAIN}/${USER}"

      # Copy user provided sieve file, if present
      if [[ -e "/tmp/docker-mailserver/${LOGIN}.dovecot.sieve" ]]
      then
        cp "/tmp/docker-mailserver/${LOGIN}.dovecot.sieve" "/var/mail/${DOMAIN}/${USER}/.dovecot.sieve"
      fi

      echo "${DOMAIN}" >> /tmp/vhost.tmp
    done < <(grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-accounts.cf)
  fi
}
