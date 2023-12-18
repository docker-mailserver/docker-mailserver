#!/bin/bash

# Support for Postfix accounts managed via Dovecot

# It looks like the DOMAIN in below logic is being stored in /etc/postfix/vhost,
# even if it's a value used for Postfix `main.cf:mydestination`, which apparently isn't good?
# Only an issue when $myhostname is an exact match (eg: bare domain FQDN).

DOVECOT_USERDB_FILE=/etc/dovecot/userdb
DOVECOT_MASTERDB_FILE=/etc/dovecot/masterdb

function _create_accounts() {
  : >/etc/postfix/vmailbox
  : >"${DOVECOT_USERDB_FILE}"

  [[ ${ACCOUNT_PROVISIONER} == 'FILE' ]] || return 0

  local DATABASE_ACCOUNTS='/tmp/docker-mailserver/postfix-accounts.cf'
  _create_masters

  if [[ -f ${DATABASE_ACCOUNTS} ]]; then
    _log 'trace' "Checking file line endings"
    sed -i 's|\r||g' "${DATABASE_ACCOUNTS}"

    _log 'trace' "Regenerating postfix user list"
    echo "# WARNING: this file is auto-generated. Modify ${DATABASE_ACCOUNTS} to edit the user list." > /etc/postfix/vmailbox

    # checking that ${DATABASE_ACCOUNTS} ends with a newline
    # shellcheck disable=SC1003
    sed -i -e '$a\' "${DATABASE_ACCOUNTS}"

    chown dovecot:dovecot "${DOVECOT_USERDB_FILE}"
    chmod 640 "${DOVECOT_USERDB_FILE}"

    sed -i -e '/\!include auth-ldap\.conf\.ext/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
    sed -i -e '/\!include auth-passwdfile\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf

    # creating users ; 'pass' is encrypted
    # comments and empty lines are ignored
    local LOGIN PASS USER_ATTRIBUTES
    while IFS=$'|' read -r LOGIN PASS USER_ATTRIBUTES; do
      # Setting variables for better readability
      USER=$(echo "${LOGIN}" | cut -d @ -f1)
      DOMAIN=$(echo "${LOGIN}" | cut -d @ -f2)

      # test if user has a defined quota
      if [[ -f /tmp/docker-mailserver/dovecot-quotas.cf ]]; then
        declare -a USER_QUOTA
        IFS=':' read -r -a USER_QUOTA < <(grep "${USER}@${DOMAIN}:" -i /tmp/docker-mailserver/dovecot-quotas.cf)

        if [[ ${#USER_QUOTA[@]} -eq 2 ]]; then
          USER_ATTRIBUTES="${USER_ATTRIBUTES:+${USER_ATTRIBUTES} }userdb_quota_rule=*:bytes=${USER_QUOTA[1]}"
        fi
      fi

      if [[ -z ${USER_ATTRIBUTES} ]]; then
        _log 'debug' "Creating user '${USER}' for domain '${DOMAIN}'"
      else
        _log 'debug' "Creating user '${USER}' for domain '${DOMAIN}' with attributes '${USER_ATTRIBUTES}'"
      fi

      local POSTFIX_VMAILBOX_LINE DOVECOT_USERDB_LINE

      POSTFIX_VMAILBOX_LINE="${LOGIN} ${DOMAIN}/${USER}/"
      if grep -qF "${POSTFIX_VMAILBOX_LINE}" /etc/postfix/vmailbox; then
        _log 'warn' "User '${USER}@${DOMAIN}' will not be added to '/etc/postfix/vmailbox' twice"
      else
        echo "${POSTFIX_VMAILBOX_LINE}" >>/etc/postfix/vmailbox
      fi

      # Dovecot's userdb has the following format
      # user:password:uid:gid:(gecos):home:(shell):extra_fields
      DOVECOT_USERDB_LINE="${LOGIN}:${PASS}:${DMS_VMAIL_UID}:${DMS_VMAIL_GID}::/var/mail/${DOMAIN}/${USER}/home::${USER_ATTRIBUTES}"
      if grep -qF "${DOVECOT_USERDB_LINE}" "${DOVECOT_USERDB_FILE}"; then
        _log 'warn' "Login '${LOGIN}' will not be added to '${DOVECOT_USERDB_FILE}' twice"
      else
        echo "${DOVECOT_USERDB_LINE}" >>"${DOVECOT_USERDB_FILE}"
      fi

      mkdir -p "/var/mail/${DOMAIN}/${USER}/home"

      # copy user provided sieve file, if present
      if [[ -e "/tmp/docker-mailserver/${LOGIN}.dovecot.sieve" ]]; then
        cp "/tmp/docker-mailserver/${LOGIN}.dovecot.sieve" "/var/mail/${DOMAIN}/${USER}/home/.dovecot.sieve"
      fi
    done < <(_get_valid_lines_from_file "${DATABASE_ACCOUNTS}")

    _create_dovecot_alias_dummy_accounts
  fi
}

# Required when using Dovecot Quotas to avoid blacklisting risk from backscatter
# Note: This is a workaround only suitable for basic aliases that map to single real addresses,
# not multiple addresses (real accounts or additional aliases), those will not work with Postfix
# `quota-status` policy service and remain at risk of backscatter.
#
# see https://github.com/docker-mailserver/docker-mailserver/pull/2248#issuecomment-953313852
# for more details on this method
function _create_dovecot_alias_dummy_accounts() {
  local DATABASE_VIRTUAL='/tmp/docker-mailserver/postfix-virtual.cf'

  if [[ -f ${DATABASE_VIRTUAL} ]] && [[ ${ENABLE_QUOTAS} -eq 1 ]]; then
    # adding aliases to Dovecot's userdb
    # ${REAL_FQUN} is a user's fully-qualified username
    local ALIAS REAL_FQUN DOVECOT_USERDB_LINE
    while read -r ALIAS REAL_FQUN; do
      # alias is assumed to not be a proper e-mail
      # these aliases do not need to be added to Dovecot's userdb
      [[ ! ${ALIAS} == *@* ]] && continue

      # clear possibly already filled arrays
      # do not remove the following line of code
      unset REAL_ACC USER_QUOTA
      declare -a REAL_ACC USER_QUOTA

      local REAL_USERNAME REAL_DOMAINNAME
      REAL_USERNAME=$(cut -d '@' -f 1 <<< "${REAL_FQUN}")
      REAL_DOMAINNAME=$(cut -d '@' -f 2 <<< "${REAL_FQUN}")

      if ! grep -q "${REAL_FQUN}" "${DATABASE_ACCOUNTS}"; then
        _log 'debug' "Alias '${ALIAS}' is non-local (or mapped to a non-existing account) and will not be added to Dovecot's userdb"
        continue
      fi

      _log 'debug' "Adding alias '${ALIAS}' for user '${REAL_FQUN}' to Dovecot's userdb"

      # ${REAL_ACC[0]} => real account name (e-mail address) == ${REAL_FQUN}
      # ${REAL_ACC[1]} => password hash
      # ${REAL_ACC[2]} => optional user attributes
      IFS='|' read -r -a REAL_ACC < <(grep "${REAL_FQUN}" "${DATABASE_ACCOUNTS}")

      if [[ -z ${REAL_ACC[1]} ]]; then
        _dms_panic__misconfigured 'postfix-accounts.cf' 'alias configuration'
      fi

      # test if user has a defined quota
      if [[ -f /tmp/docker-mailserver/dovecot-quotas.cf ]]; then
        IFS=':' read -r -a USER_QUOTA < <(grep "${REAL_FQUN}:" -i /tmp/docker-mailserver/dovecot-quotas.cf)
        if [[ ${#USER_QUOTA[@]} -eq 2 ]]; then
          REAL_ACC[2]="${REAL_ACC[2]:+${REAL_ACC[2]} }userdb_quota_rule=*:bytes=${USER_QUOTA[1]}"
        fi
      fi

      DOVECOT_USERDB_LINE="${ALIAS}:${REAL_ACC[1]}:${DMS_VMAIL_UID}:${DMS_VMAIL_GID}::/var/mail/${REAL_DOMAINNAME}/${REAL_USERNAME}::${REAL_ACC[2]:-}"
      if grep -qi "^${ALIAS}:" "${DOVECOT_USERDB_FILE}"; then
        _log 'warn' "Alias '${ALIAS}' will not be added to '${DOVECOT_USERDB_FILE}' twice"
      else
        echo "${DOVECOT_USERDB_LINE}" >>"${DOVECOT_USERDB_FILE}"
      fi
    done < <(_get_valid_lines_from_file "${DATABASE_VIRTUAL}")
  fi
}

# Support Dovecot master user: https://doc.dovecot.org/configuration_manual/authentication/master_users/
# Supporting LDAP users requires `auth_bind = yes` in `dovecot-ldap.conf.ext`, see docker-mailserver/docker-mailserver/pull/2535 for details
function _create_masters() {
  : >"${DOVECOT_MASTERDB_FILE}"

  local DATABASE_DOVECOT_MASTERS='/tmp/docker-mailserver/dovecot-masters.cf'
  if [[ -f ${DATABASE_DOVECOT_MASTERS} ]]; then
    _log 'trace' "Checking file line endings"
    sed -i 's|\r||g' "${DATABASE_DOVECOT_MASTERS}"

    _log 'trace' "Regenerating dovecot masters list"

    # checking that ${DATABASE_DOVECOT_MASTERS} ends with a newline
    # shellcheck disable=SC1003
    sed -i -e '$a\' "${DATABASE_DOVECOT_MASTERS}"

    chown dovecot:dovecot "${DOVECOT_MASTERDB_FILE}"
    chmod 640 "${DOVECOT_MASTERDB_FILE}"

    sed -i -e '/\!include auth-master\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf

    # creating users ; 'pass' is encrypted
    # comments and empty lines are ignored
    local LOGIN PASS
    while IFS=$'|' read -r LOGIN PASS; do
      _log 'debug' "Creating master user '${LOGIN}'"

      local DOVECOT_MASTERDB_LINE

      # Dovecot's masterdb has the following format
      # user:password
      DOVECOT_MASTERDB_LINE="${LOGIN}:${PASS}"
      if grep -qF "${DOVECOT_MASTERDB_LINE}" "${DOVECOT_MASTERDB_FILE}"; then
        _log 'warn' "Login '${LOGIN}' will not be added to '${DOVECOT_MASTERDB_FILE}' twice"
      else
        echo "${DOVECOT_MASTERDB_LINE}" >>"${DOVECOT_MASTERDB_FILE}"
      fi
    done < <(_get_valid_lines_from_file "${DATABASE_DOVECOT_MASTERS}")
  fi
}
