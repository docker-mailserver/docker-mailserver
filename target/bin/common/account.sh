#! /bin/bash

# Used from /usr/local/bin/helpers/index.sh:
# _create_lock

function _manage_accounts
{
  local ACTION=${1}
  local DATABASE=${2}
  local MAIL_ACCOUNT=${3}
  # Only for ACTION 'create' or 'update':
  local PASSWD=${4}

  touch "${DATABASE}"
  _create_lock # Protect config file with lock to avoid race conditions

  case "${ACTION}" in
    ( 'create' | 'update' )
      # Fail early before requesting password:
      [[ ${ACTION} == 'create' ]] && _account_should_not_exist_yet
      [[ ${ACTION} == 'update' ]] && _account_should_already_exist
      _password_request_if_missing

      local PASSWD_HASH
      PASSWD_HASH=$(_password_hash "${MAIL_ACCOUNT}" "${PASSWD}")
      # Early failure above ensures correct operation => Add (create) or Replace (update):
      _db_entry_add_or_replace "${DATABASE}" "${MAIL_ACCOUNT}" "${PASSWD_HASH}"
      ;;

    ( 'delete' )
      _db_entry_remove "${DATABASE}" "${MAIL_ACCOUNT}"
      ;;

    ( * ) # This should not happen if using convenience wrapper methods:
      _exit_with_error "Unsupported Action: '${ACTION}'"
      ;;

  esac
}

# Convenience wrappers:
DATABASE_ACCOUNTS='/tmp/docker-mailserver/postfix-accounts.cf'
function _manage_accounts_create { _manage_accounts 'create' "${DATABASE_ACCOUNTS}" "${@}" ; }
function _manage_accounts_update { _manage_accounts 'update' "${DATABASE_ACCOUNTS}" "${@}" ; }
function _manage_accounts_delete { _manage_accounts 'delete' "${DATABASE_ACCOUNTS}" "${@}" ; }

# Dovecot Master account support can leverage the same management logic:
DATABASE_DOVECOT_MASTERS='/tmp/docker-mailserver/dovecot-masters.cf'
function _manage_accounts_dovecotmaster_create { _manage_accounts 'create' "${DATABASE_DOVECOT_MASTERS}" "${@}" ; }
function _manage_accounts_dovecotmaster_update { _manage_accounts 'update' "${DATABASE_DOVECOT_MASTERS}" "${@}" ; }
function _manage_accounts_dovecotmaster_delete { _manage_accounts 'delete' "${DATABASE_DOVECOT_MASTERS}" "${@}" ; }
