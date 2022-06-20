#! /bin/bash

# Manage DB writes for:
# - DATABASE_ACCOUNTS
# - DATABASE_DOVECOT_MASTERS

# Logic to perform for requested operations handled here:
function _manage_accounts
{
  local ACTION=${1}
  local DATABASE=${2}
  local MAIL_ACCOUNT=${3}
  # Only for ACTION 'create' or 'update':
  local PASSWD=${4}

  _arg_expect_mail_account

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

#
# Validation Methods
#

function _arg_expect_mail_account
{
  [[ -z ${MAIL_ACCOUNT} ]] && { __usage ; _exit_with_error 'No account specified' ; }

  # Dovecot Master accounts are validated (they are not email addresses):
  [[ ${DATABASE} == "${DATABASE_DOVECOT_MASTERS}" ]] && return 0

  # Account has both local and domain parts:
  [[ ${MAIL_ACCOUNT} =~ .*\@.* ]] || { __usage ; _exit_with_error "'${MAIL_ACCOUNT}' should include the domain (eg: user@example.com)" ; }
}

function _account_should_not_exist_yet
{
  __account_already_exists && _exit_with_error "'${MAIL_ACCOUNT}' already exists"
}

function _account_should_already_exist
{
  ! __account_already_exists && _exit_with_error "'${MAIL_ACCOUNT}' does not exist"
}

function __account_already_exists
{
  local DATABASE=${DATABASE:-"${DATABASE_ACCOUNTS}"}
  _key_exists_in_db "${MAIL_ACCOUNT}" "${DATABASE}"
}
