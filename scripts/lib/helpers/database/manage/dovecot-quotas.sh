#!/bin/bash

# Manage DB writes for: DATABASE_QUOTA

# Logic to perform for requested operations handled here:
function _manage_dovecot_quota() {
  local ACTION=${1}
  local MAIL_ACCOUNT=${2}
  # Only for ACTION 'update':
  local QUOTA=${3}

  local DATABASE_QUOTA='/tmp/docker-mailserver/dovecot-quotas.cf'
  case "${ACTION}" in
    ( 'update' )
      _db_entry_add_or_replace "${DATABASE_QUOTA}" "${MAIL_ACCOUNT}" "${QUOTA}"
      ;;

    ( 'delete' )
      _db_entry_remove "${DATABASE_QUOTA}" "${MAIL_ACCOUNT}"
      ;;

    ( * ) # This should not happen if using convenience wrapper methods:
      _exit_with_error "Unsupported Action: '${ACTION}'"
      ;;

  esac
}

# Convenience wrappers:
function _manage_dovecot_quota_update { _manage_dovecot_quota 'update' "${@}" ; } # setquota
function _manage_dovecot_quota_delete { _manage_dovecot_quota 'delete' "${@}" ; } # delquota, delmailuser
