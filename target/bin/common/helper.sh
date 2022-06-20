#! /bin/bash

# Used from /usr/local/bin/helpers/index.sh:
# _exit_with_error

# Some of these helpers rely on:
# - Exteral vars to be declared prior to calling them (MAIL_ACCOUNT, PASSWD, DATABASE).
# - Calling external method '__usage' as part of error handling.

# NOTE: Caller should have defined a `_list_format_entry` method prior:
function _list_entries
{
  local DATABASE=${1}
  _check_database_has_content "${DATABASE}"

  local ENTRY_TO_DISPLAY
  while read -r LINE
  do
    ENTRY_TO_DISPLAY=$(_list_format_entry "${LINE}")

    echo -e "* ${ENTRY_TO_DISPLAY}\n"
  done < <(_get_valid_lines_from_file "${DATABASE}")
}

function _check_database_has_content
{
  local DATABASE=${1}

  [[ -f ${DATABASE} ]] || _exit_with_error "'${DATABASE}' does not exist"
  [[ -s ${DATABASE} ]] || _exit_with_error "'${DATABASE}' is empty, nothing to list"
}

# Accounts and Aliases (Virtual kind):
DATABASE_ACCOUNTS='/tmp/docker-mailserver/postfix-accounts.cf'
DATABASE_DOVECOT_MASTERS='/tmp/docker-mailserver/dovecot-masters.cf'
DATABASE_VIRTUAL='/tmp/docker-mailserver/postfix-virtual.cf'
# Dovecot Quota support:
DATABASE_QUOTA='/tmp/docker-mailserver/dovecot-quotas.cf'
# Relay-Host support:
DATABASE_PASSWD='/tmp/docker-mailserver/postfix-sasl-password.cf'
DATABASE_RELAY='/tmp/docker-mailserver/postfix-relaymap.cf'

function _db_get_delimiter_for
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

# NOTE:
# - Due to usage in regex pattern, key needs to be escaped.
# - DELIMITER avoids false-positives by ensuring an exact match for the key.
function _key_exists_in_db
{
  local KEY=${1}
  local DATABASE=${2}
  KEY=$(_escape "${KEY}")

  # If the database file exists but has no content fail early:
  [[ -s ${DATABASE} ]] || return 1

  local DELIMITER
  DELIMITER=$(_db_get_delimiter_for "${DATABASE}")

  # NOTE:
  # --quiet --no-messages, only return a status code of success/failure.
  # --ignore-case as we don't want duplicate keys that vary by case.
  # --extended-regexp not used, most regex escaping should be forbidden.
  grep --quiet --no-messages --ignore-case "^${KEY}${DELIMITER}" "${DATABASE}"
}

function _db_entry_add_or_append  { _db_operation 'append'  "${@}" ; } # Only used by addalias
function _db_entry_add_or_replace { _db_operation 'replace' "${@}" ; }
function _db_entry_remove         { _db_operation 'remove'  "${@}" ; }

function _db_operation
{
  local DB_ACTION=${1}
  local DATABASE=${2}
  local KEY=${2}
  local VALUE=${3}

  local DELIMITER
  DELIMITER=$(_db_get_delimiter_for "${DATABASE}")

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
  if _key_exists_in_db "${KEY}" "${DATABASE}"
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

      ( * ) # Should only fail for developer using this API:
        _exit_with_error "Unsupported DB operation: '${DB_ACTION}'"
        ;;

    esac
  fi
}

# Internal method for `_db_operation`:
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

### Password Methods ###

function _password_request_if_missing
{
  if [[ -z ${PASSWD} ]]
  then
    read -r -s -p 'Enter Password: ' PASSWD
    echo
    [[ -z ${PASSWD} ]] && _exit_with_error 'Password must not be empty'
  fi
}

function _password_hash
{
  local MAIL_ACCOUNT=${1}
  local PASSWD=${2}

  doveadm pw -s SHA512-CRYPT -u "${MAIL_ACCOUNT}" -p "${PASSWD}"
}

### Validation Methods ###

function _arg_expected_domain
{
  [[ -z ${DOMAIN} ]] && { __usage ; _exit_with_error 'No domain specified' ; }
}
