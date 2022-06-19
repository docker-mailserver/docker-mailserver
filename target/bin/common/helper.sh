#! /bin/bash

# These helpers expect vars referenced to be declared prior to calling them.

function _if_missing_request_password
{
  if [[ -z ${PASSWD} ]]
  then
    read -r -s -p 'Enter Password: ' PASSWD
    echo
    [[ -z ${PASSWD} ]] && _exit_with_error 'Password must not be empty'
  fi
}

function _hash_password
{
  echo $(doveadm pw -s SHA512-CRYPT -u "${MAIL_ACCOUNT}" -p "${PASSWD}")
}

function _account_already_exists
{
  # Escaped value for use in regex pattern:
  local _MAIL_ACCOUNT_=$(_escape "${MAIL_ACCOUNT}")

  # `|` is a delimter between the account identity (_MAIL_ACCOUNT_) and the hashed password
  grep -qi "^${_MAIL_ACCOUNT_}|" "${DATABASE}" 2>/dev/null
}

function _account_should_already_exist
{
  ! _account_already_exists && _exit_with_error "'${MAIL_ACCOUNT}' does not exist"
}

function _account_should_not_exist_yet
{
  _account_already_exists && _exit_with_error "'${MAIL_ACCOUNT}' already exists"
}
