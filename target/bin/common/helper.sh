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
