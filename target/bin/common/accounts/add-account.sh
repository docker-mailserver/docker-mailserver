#! /bin/bash

source ../helper.sh

function _account_already_exists
{
  # Escaped values for use in regex patterns:
  local _MAIL_ACCOUNT_=$(_escape "${MAIL_ACCOUNT}")

  # `|` is a delimter between the account identity (_MAIL_ACCOUNT_) and the hashed password
  grep -qi "^${_MAIL_ACCOUNT_}|" "${DATABASE}" 2>/dev/null
}

function _add_account_to_db
{
  local DATABASE=${1}
  touch "${DATABASE}"
  _create_lock # Protect config file with lock to avoid race conditions

  if _account_already_exists
  then
    _exit_with_error "User '${MAIL_ACCOUNT}' already exists"
  fi

  _if_missing_request_password
  # Create the hashed password, then add an account entry into the DATABASE:
  local HASH=$(doveadm pw -s SHA512-CRYPT -u "${MAIL_ACCOUNT}" -p "${PASSWD}")
  echo "${MAIL_ACCOUNT}|${HASH}" >> "${DATABASE}"
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
