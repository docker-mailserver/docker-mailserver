#! /bin/bash

# Modifications are supported for the following databases:
#
# Accounts and Aliases (The 'virtual' kind):
DATABASE_ACCOUNTS='/tmp/docker-mailserver/postfix-accounts.cf'
DATABASE_DOVECOT_MASTERS='/tmp/docker-mailserver/dovecot-masters.cf'
DATABASE_VIRTUAL='/tmp/docker-mailserver/postfix-virtual.cf'
# Dovecot Quota support:
DATABASE_QUOTA='/tmp/docker-mailserver/dovecot-quotas.cf'
# Relay-Host support:
DATABASE_PASSWD='/tmp/docker-mailserver/postfix-sasl-password.cf'
DATABASE_RELAY='/tmp/docker-mailserver/postfix-relaymap.cf'

# Individual scripts with convenience methods to manage operations easier:
function _db_import_scripts
{
  # shellcheck source-path=target/scripts/helpers/database/manage
  local PATH_TO_SCRIPTS='/usr/local/bin/helpers/database/manage'

  source "${PATH_TO_SCRIPTS}/dovecot-quotas.sh"
  source "${PATH_TO_SCRIPTS}/postfix-accounts.sh"
  source "${PATH_TO_SCRIPTS}/postfix-virtual.sh"
}
_db_import_scripts

function _db_entry_add_or_append  { _db_operation 'append'  "${@}" ; } # Only used by addalias
function _db_entry_add_or_replace { _db_operation 'replace' "${@}" ; }
function _db_entry_remove         { _db_operation 'remove'  "${@}" ; }

function _db_operation
{
  local DB_ACTION=${1}
  local DATABASE=${2}
  local KEY=${3}
  # Optional arg:
  local VALUE=${4}

  local DELIMITER
  DELIMITER=$(__db_get_delimiter_for "${DATABASE}")

  # DELIMITER provides a match boundary to avoid substring matches:
  local KEY_LOOKUP
  KEY_LOOKUP="$(_escape "${KEY}")${DELIMITER}"

  # Supports adding or replacing an entire entry:
  # White-space delimiter should be written into DATABASE as 'space' character:
  [[ ${DELIMITER} == '\s' ]] && DELIMITER=' '
  local ENTRY="${KEY}${DELIMITER}${VALUE}"

  # Supports 'append' + 'remove' operations on value lists:
  # NOTE: Presently only required for `postfix-virtual.cf`.
  local _VALUE_
  _VALUE_=$(_escape "${VALUE}")
  # `postfix-virtual.cf` is using `,` for delimiting a list of recipients:
  [[ ${DATABASE} == "${DATABASE_VIRTUAL}" ]] && DELIMITER=','

  # Perform requested operation:
  if _db_has_entry_with_key "${KEY}" "${DATABASE}"
  then
    # Find entry for key and return status code:
    case "${DB_ACTION}" in
      ( 'append' )
        __db_list_already_contains_value && return 1

        sedfile --strict -i "/^${KEY_LOOKUP}/s/$/${DELIMITER}${VALUE}/" "${DATABASE}"
        ;;

      ( 'replace' )
        sedfile --strict -i "s/^${KEY_LOOKUP}.*/${ENTRY}/" "${DATABASE}"
        ;;

      ( 'remove' )
        if [[ -z ${VALUE} ]]
        then
          sedfile --strict -i "/^${KEY_LOOKUP}/d" "${DATABASE}"
        else
          __db_list_already_contains_value || return 0

          # If an exact match for VALUE exists for KEY,
          # - If VALUE is the only value => Remove entry
          # - If VALUE is the last value => Remove VALUE
          # - Otherwise => Collapse value to DELIMITER
          sedfile --strict -i \
            -e "/^${KEY_LOOKUP}\+${_VALUE_}$/d" \
            -e "/^${KEY_LOOKUP}/s/${DELIMITER}${_VALUE_}$//g" \
            -e "/^${KEY_LOOKUP}/s/${DELIMITER}${_VALUE_}${DELIMITER}/${DELIMITER}/g" \
            "${DATABASE}"
          fi
        ;;

      ( * ) # Should only fail for developer using this API:
        _exit_with_error "Unsupported DB operation: '${DB_ACTION}'"
        ;;

    esac
  else
    # Entry for key does not exist, DATABASE may be empty, or DATABASE does not exist
    case "${DB_ACTION}" in
      # Fallback action 'Add new entry':
      ( 'append' | 'replace' )
        echo "${ENTRY}" >>"${DATABASE}"
        ;;

      # Nothing to remove, return success status
      ( 'remove' )
        return 0
        ;;

      ( * ) # This should not happen if using convenience wrapper methods:
        _exit_with_error "Unsupported DB operation: '${DB_ACTION}'"
        ;;

    esac
  fi
}

# Internal method for: _db_operation
function __db_list_already_contains_value
{
  # Extract the entries current value (`\1`), and split into lines (`\n`) at DELIMITER,
  # then check if the target VALUE has an exact match (not a substring):
  # NOTE: `-n` + `p` ensures `grep` only receives the 2nd sed expression output.
  sed -n \
    -e "s/^${KEY_LOOKUP}\(.*\)/\1/" \
    -e "s/${DELIMITER}/\n/gp"       \
    "${DATABASE}" | grep -qi "^${_VALUE_}$"
}


# Internal method for: _db_operation + _db_has_entry_with_key
# References global vars `DATABASE_*`:
function __db_get_delimiter_for
{
  local DATABASE=${1}

  case "${DATABASE}" in
    ( "${DATABASE_ACCOUNTS}" | "${DATABASE_DOVECOT_MASTERS}" )
      echo "|"
      ;;

    # NOTE: These files support white-space delimiters, we have not
    # historically enforced a specific value; as a workaround
    # `_db_operation` will convert to ` ` (space) for writing.
    ( "${DATABASE_PASSWD}" | "${DATABASE_RELAY}" | "${DATABASE_VIRTUAL}" )
      echo "\s"
      ;;

    ( "${DATABASE_QUOTA}" )
      echo ":"
      ;;

    ( * )
      _exit_with_error "Unsupported DB '${DATABASE}'"
      ;;

    esac
}

#
# Validation Methods
#

function _db_has_entry_with_key
{
  local KEY=${1}
  local DATABASE=${2}

  # Fail early if the database file exists but has no content:
  [[ -s ${DATABASE} ]] || return 1

  # Due to usage in regex pattern, key needs to be escaped
  KEY=$(_escape "${KEY}")
  # DELIMITER avoids false-positives by ensuring an exact match for the key
  local DELIMITER
  DELIMITER=$(__db_get_delimiter_for "${DATABASE}")

  # NOTE:
  # --quiet --no-messages, only return a status code of success/failure.
  # --ignore-case as we don't want duplicate keys that vary by case.
  # --extended-regexp not used, most regex escaping should be forbidden.
  grep --quiet --no-messages --ignore-case "^${KEY}${DELIMITER}" "${DATABASE}"
}

function _db_should_exist_with_content
{
  local DATABASE=${1}

  [[ -f ${DATABASE} ]] || _exit_with_error "'${DATABASE}' does not exist"
  [[ -s ${DATABASE} ]] || _exit_with_error "'${DATABASE}' is empty, nothing to list"
}
