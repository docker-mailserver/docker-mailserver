#! /bin/bash

source ../helper.sh

function _add_account_to_db
{
  local DATABASE=${1}
  touch "${DATABASE}"
  _create_lock # Protect config file with lock to avoid race conditions

  _account_should_not_exist_yet
  _if_missing_request_password

  local PASSWD_HASH=$(_hash_password)
  # Add an account entry with hashed password into the DATABASE:
  echo "${MAIL_ACCOUNT}|${PASSWD_HASH}" >>"${DATABASE}"
}

# Tests fail if the creation of /var/mail/${DOMAIN}/${USER} doesn't happen fast enough after addmailuser executes (check-for-changes.sh race-condition)
# Prevent infinite loop in tests like "checking accounts: user3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf even when that file does not exist"
function _wait_until_account_maildir_exists
{
  if [[ -e ${CHKSUM_FILE} ]]
  then
    local USER="${MAIL_ACCOUNT%@*}"
    local DOMAIN="${MAIL_ACCOUNT#*@}"

    while [[ ! -d "/var/mail/${DOMAIN}/${USER}" ]]
    do
      _log 'info' "Waiting for dovecot to create '/var/mail/${DOMAIN}/${USER}/'"
      sleep 1
    done
  fi
}
