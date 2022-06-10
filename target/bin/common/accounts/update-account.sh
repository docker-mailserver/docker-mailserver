#! /bin/bash

function _validate_parameters
{
  [[ -z ${MAIL_ACCOUNT} ]] && { __usage ; _exit_with_error 'No username specified' ; }
}

function _if_missing_request_password
{
  if [[ -z ${PASSWD} ]]
  then
    read -r -s -p 'Enter Password: ' PASSWD
    echo
    [[ -z ${PASSWD} ]] && _exit_with_error 'Password must not be empty'
  fi
}

function _account_already_exists
{
  # Escaped values for use in regex patterns:
  local _MAIL_ACCOUNT_=$(_escape "${MAIL_ACCOUNT}")

  # `|` is a delimter between the account identity (_MAIL_ACCOUNT_) and the hashed password
  grep -qi "^${_MAIL_ACCOUNT_}|" "${DATABASE}" 2>/dev/null
}

function _update_account_password_in_db
{
  local DATABASE=${1}
  touch "${DATABASE}"
  _create_lock # Protect config file with lock to avoid race conditions

  if ! _account_already_exists
  then
    _exit_with_error "User '${MAIL_ACCOUNT}' does not exist"
  fi

  _if_missing_request_password
  # Create the hashed password, then update an account password in the DATABASE:
  local HASH=$(doveadm pw -s SHA512-CRYPT -u "${MAIL_ACCOUNT}" -p "${PASSWD}")
  sed -i "s/^${MAIL_ACCOUNT}|.*/${MAIL_ACCOUNT}|${HASH}/" "${DATABASE}"
}
