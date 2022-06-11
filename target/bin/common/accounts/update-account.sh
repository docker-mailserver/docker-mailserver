#! /bin/bash

source ../helper.sh

function _validate_parameters
{
  _provided_mail_account
}

function _update_account_password_in_db
{
  local DATABASE=${1}
  touch "${DATABASE}"
  _create_lock # Protect config file with lock to avoid race conditions

  _account_should_already_exist
  _if_missing_request_password

  local PASSWD_HASH=$(_hash_password)
  # Update password for an account in the DATABASE:
  sed -i "s/^${MAIL_ACCOUNT}|.*/${MAIL_ACCOUNT}|${PASSWD_HASH}/" "${DATABASE}"
}
