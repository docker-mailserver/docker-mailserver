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

# NOTE: This would not be required if not using extended regexp?
# Presently used to escape delimiter value '|' only.
# If the delimiter is the expected character, it will be prefixed with `\`:
function _escape_delimiter {
  sed -E 's/^[|]$/\\&/' <<< "${1}"
}

# NOTE:
# - Due to usage in regex pattern, key needs to be escaped.
# - DELIMITER avoids false-positives by ensuring an exact match for the key.
function _key_exists_in_db
{
  local KEY=$(_escape "${1}")
  local DELIMITER=$(_escape_delimiter "${2}")
  local DATABASE=${3}

  # If the database file exists but has no content fail early:
  [[ -s ${DATABASE} ]] || return 1

  # NOTE:
  # - Quiet to not output matches, only return a status code of success/failure.
  # - Case-insensitive as we don't want duplicate keys that vary by case.
  # - Extended Regexp syntax is more consistent to handle.
  grep --quiet --ignore-case --extended-regexp \
    "^${KEY}${DELIMITER}" "${DATABASE}" 2>/dev/null
}

# Used by addrelayhost, addsaslpassword, excluderelaydomain
function _db_add_or_replace_entry
{
  local KEY=${1}
  local DELIMITER=${2}
  local VALUE=${3}
  local DATABASE=${4}

  local ENTRY="${KEY}${DELIMITER}${VALUE}"
  # Replace value for an existing key, or add a new key->value entry:
  if _key_exists_in_db "${KEY}" "${DELIMITER}" "${DATABASE}"
  then
    KEY=$(_escape "${KEY}")
    DELIMITER=$(_escape_delimiter "${DELIMITER}")
    sed -i -E "s/^${KEY}${DELIMITER}.*/${ENTRY}/" "${DATABASE}"
  else
    echo "${ENTRY}" >>"${DATABASE}"
  fi
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

function _account_already_exists
{
  local DATABASE=${DATABASE:-'/tmp/docker-mailserver/postfix-accounts.cf'}
  _key_exists_in_db "${MAIL_ACCOUNT}" '|' "${DATABASE}"
}

function _account_should_already_exist
{
  ! _account_already_exists && _exit_with_error "'${MAIL_ACCOUNT}' does not exist"
}

function _account_should_not_exist_yet
{
  _account_already_exists && _exit_with_error "'${MAIL_ACCOUNT}' already exists"
}

function _arg_expect_mail_account
{
  [[ -z ${MAIL_ACCOUNT} ]] && { __usage ; _exit_with_error "No username specified" ; }
}

function _arg_expect_mail_account_has_local_and_domain_parts
{
  _arg_expect_mail_account
  [[ ${MAIL_ACCOUNT} =~ .*\@.* ]] || { __usage ; _exit_with_error "Username must include the domain" ; }
}

function _arg_expected_domain
{
  [[ -z ${DOMAIN} ]] && { __usage ; _exit_with_error 'No domain specified' ; }
}
