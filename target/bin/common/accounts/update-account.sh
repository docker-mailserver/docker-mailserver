#! /bin/bash

# Used from /usr/local/bin/helpers/index.sh:
# _create_lock, _log

source ../helper.sh

function _update_account_password_in_db
{
  local DATABASE=${1}
  touch "${DATABASE}"
  _create_lock # Protect config file with lock to avoid race conditions

  _account_should_already_exist
  _password_request_if_missing

  local PASSWD_HASH=$(_password_hash "${MAIL_ACCOUNT}" "${PASSWD}")
  # Update password for an account in the DATABASE:
  sed -i "s/^${MAIL_ACCOUNT}|.*/${MAIL_ACCOUNT}|${PASSWD_HASH}/" "${DATABASE}"
}
