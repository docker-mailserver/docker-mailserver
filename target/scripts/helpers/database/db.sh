#!/bin/bash

# Matches relative path to this scripts parent directory,
# Must be defined above any function that would source relative to it:
# shellcheck source-path=target/scripts/helpers/database

DMS_CONFIG='/tmp/docker-mailserver'
# Modifications are supported for the following databases:
#
# Accounts and Aliases (The 'virtual' kind):
DATABASE_ACCOUNTS="${DMS_CONFIG}/postfix-accounts.cf"
DATABASE_DOVECOT_MASTERS="${DMS_CONFIG}/dovecot-masters.cf"
DATABASE_VIRTUAL="${DMS_CONFIG}/postfix-virtual.cf"
# Dovecot Quota support:
DATABASE_QUOTA="${DMS_CONFIG}/dovecot-quotas.cf"
# Relay-Host support:
DATABASE_PASSWD="${DMS_CONFIG}/postfix-sasl-password.cf"
DATABASE_RELAY="${DMS_CONFIG}/postfix-relaymap.cf"

# Individual scripts with convenience methods to manage operations easier:
function _db_import_scripts() {
  # This var is stripped by shellcheck from source paths below,
  # like the shellcheck source-path above, it shouold match this scripts
  # parent directory, with the rest of the relative path in the source lines:
  local PATH_TO_SCRIPTS='/usr/local/bin/helpers/database'

  source "${PATH_TO_SCRIPTS}/manage/dovecot-quotas.sh"
  source "${PATH_TO_SCRIPTS}/manage/postfix-accounts.sh"
  source "${PATH_TO_SCRIPTS}/manage/postfix-virtual.sh"
}
_db_import_scripts

function _db_entry_add_or_append  { _db_operation 'append'  "${@}" ; } # Only used by addalias
function _db_entry_add_or_replace { _db_operation 'replace' "${@}" ; }
function _db_entry_remove         { _db_operation 'remove'  "${@}" ; }

function _db_operation() {
  local DB_ACTION=${1}
  local DATABASE=${2}
  local KEY=${3}
  # Optional arg:
  local VALUE=${4}

  # K_DELIMITER provides a match boundary to avoid accidentally matching substrings:
  local K_DELIMITER KEY_LOOKUP
  K_DELIMITER=$(__db_get_delimiter_for "${DATABASE}")
  # Due to usage in regex pattern, KEY needs to be escaped:
  KEY_LOOKUP="$(_escape "${KEY}")${K_DELIMITER}"

  # Support for adding or replacing an entire entry (line):
  # White-space delimiter should be written into DATABASE as 'space' character:
  local V_DELIMITER="${K_DELIMITER}"
  [[ ${V_DELIMITER} == '\s' ]] && V_DELIMITER=' '
  local ENTRY="${KEY}${V_DELIMITER}${VALUE}"

  # Support for 'append' + 'remove' operations on value lists:
  # NOTE: Presently only required for `postfix-virtual.cf`.
  local _VALUE_
  _VALUE_=$(_escape "${VALUE}")
  # `postfix-virtual.cf` is using `,` for delimiting a list of recipients:
  [[ ${DATABASE} == "${DATABASE_VIRTUAL}" ]] && V_DELIMITER=','

  # Perform requested operation:
  if _db_has_entry_with_key "${KEY}" "${DATABASE}"; then
    # Find entry for key and return status code:
    case "${DB_ACTION}" in
      ( 'append' )
        __db_list_already_contains_value && return 1

        sedfile --strict -i "/^${KEY_LOOKUP}/s/$/${V_DELIMITER}${VALUE}/" "${DATABASE}"
        ;;

      ( 'replace' )
        ENTRY=$(__escape_sed_replacement "${ENTRY}")
        sedfile --strict -i "s/^${KEY_LOOKUP}.*/${ENTRY}/" "${DATABASE}"
        ;;

      ( 'remove' )
        if [[ -z ${VALUE} ]]; then # Remove entry for KEY:
          sedfile --strict -i "/^${KEY_LOOKUP}/d" "${DATABASE}"
        else # Remove target VALUE from entry:
          __db_list_already_contains_value || return 0

          # The delimiter between key and first value may differ from
          # the delimiter between multiple values (value list):
          local LEFT_DELIMITER="\(${K_DELIMITER}\|${V_DELIMITER}\)"
          # If an entry for KEY contains an exact match for VALUE:
          # - If VALUE is the only value => Remove entry (line)
          # - If VALUE is the last value => Remove VALUE
          # - Otherwise => Collapse value to LEFT_DELIMITER (\1)
          sedfile --strict -i \
            -e "/^${KEY_LOOKUP}\+${_VALUE_}$/d" \
            -e "/^${KEY_LOOKUP}/s/${V_DELIMITER}${_VALUE_}$//g" \
            -e "/^${KEY_LOOKUP}/s/${LEFT_DELIMITER}${_VALUE_}${V_DELIMITER}/\1/g" \
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
        [[ ! -d ${DMS_CONFIG} ]] && mkdir -p "${DMS_CONFIG}"
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
function __db_list_already_contains_value() {
  # Avoids accidentally matching a substring (case-insensitive acceptable):
  # 1. Extract the current value of the entry (`\1`),
  # 2. Value list support: Split values into separate lines (`\n`+`g`) at V_DELIMITER,
  # 3. Check each line for an exact match of the target VALUE
  sed -ne "s/^${KEY_LOOKUP}\+\(.*\)/\1/p" "${DATABASE}" \
    | sed -e "s/${V_DELIMITER}/\n/g" \
    | grep -qi "^${_VALUE_}$"
}


# Internal method for: _db_operation + _db_has_entry_with_key
# References global vars `DATABASE_*`:
function __db_get_delimiter_for() {
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

# sed replacement feature needs to be careful of content containing `/` and `&`,
# `\` can escape these (`/` exists in postfix-account.cf base64 encoded pw hash),
# But otherwise care should be taken with `\`, which should be forbidden for input here?
# NOTE: Presently only `.` is escaped with `\` via `_escape`.
function __escape_sed_replacement() {
  # Matches any `/` or `&`, and escapes them with `\` (`\\\1`):
  sed 's/\([/&]\)/\\\1/g' <<< "${ENTRY}"
}

#
# Validation Methods
#

function _db_has_entry_with_key() {
  local KEY=${1}
  local DATABASE=${2}

  # Fail early if the database file exists but has no content:
  [[ -s ${DATABASE} ]] || return 1

  # K_DELIMITER provides a match boundary to avoid accidentally matching substrings:
  local K_DELIMITER KEY_LOOKUP
  K_DELIMITER=$(__db_get_delimiter_for "${DATABASE}")
  # Due to usage in regex pattern, KEY needs to be escaped:
  KEY_LOOKUP="$(_escape "${KEY}")${K_DELIMITER}"

  # NOTE:
  # --quiet --no-messages, only return a status code of success/failure.
  # --ignore-case as we don't want duplicate keys that vary by case.
  # --extended-regexp not used, most regex escaping should be forbidden.
  grep --quiet --no-messages --ignore-case "^${KEY_LOOKUP}" "${DATABASE}"
}

function _db_should_exist_with_content() {
  local DATABASE=${1}

  [[ -f ${DATABASE} ]] || _exit_with_error "'${DATABASE}' does not exist"
  [[ -s ${DATABASE} ]] || _exit_with_error "'${DATABASE}' is empty, nothing to list"
}
