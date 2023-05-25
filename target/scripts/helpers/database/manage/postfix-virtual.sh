#!/bin/bash

# Manage DB writes for: DATABASE_VIRTUAL

# A virtual alias may be any of `user@domain`, `user`, `@domain`.
# Recipients are local (internal services), hosted (managed accounts), remote (third-party MTA), or aliases themselves,
# An alias may redirect mail to one or more recipients. If a recipient is an alias Postfix will recursively resolve it.
#
# WARNING: Support for multiple and recursive recipients may not be well supported by this projects scripts/features.
# One of those features is Dovecot Quota support, which uses a naive workaround for supporting quota checks for inbound
# mail to an alias address.

# Logic to perform for requested operations handled here:
function _manage_virtual_aliases() {
  local ACTION=${1}
  local MAIL_ALIAS=${2}
  local RECIPIENT=${3}

  # Validation error handling expects that the caller has defined a '__usage' method:
  [[ -z ${MAIL_ALIAS} ]] && { __usage ; _exit_with_error 'No alias specified'     ; }
  [[ -z ${RECIPIENT}  ]] && { __usage ; _exit_with_error 'No recipient specified' ; }

  local DATABASE_VIRTUAL='/tmp/docker-mailserver/postfix-virtual.cf'
  case "${ACTION}" in
    # Associate RECIPIENT to MAIL_ALIAS:
    ( 'update' )
      if [[ -f ${DATABASE_ACCOUNTS} ]] && grep -q "^${MAIL_ALIAS}" "${DATABASE_ACCOUNTS}"; then
        _exit_with_error "'${MAIL_ALIAS}' is already defined as an account"
      fi
      _db_entry_add_or_append "${DATABASE_VIRTUAL}" "${MAIL_ALIAS}" "${RECIPIENT}"
      ;;

    # Removes RECIPIENT from MAIL_ALIAS - or all aliases when MAIL_ALIAS='_':
    # NOTE: If a matched alias has no additional recipients, it is also removed.
    ( 'delete' )
      [[ ${MAIL_ALIAS} == '_' ]] && MAIL_ALIAS='\S\+'
      _db_entry_remove "${DATABASE_VIRTUAL}" "${MAIL_ALIAS}" "${RECIPIENT}"
      ;;

    ( * ) # This should not happen if using convenience wrapper methods:
      _exit_with_error "Unsupported Action: '${ACTION}'"
      ;;

  esac
}

# Convenience wrappers:
function _manage_virtual_aliases_update { _manage_virtual_aliases 'update' "${@}" ; } # addalias
function _manage_virtual_aliases_delete { _manage_virtual_aliases 'delete' "${@}" ; } # delalias, delmailuser
