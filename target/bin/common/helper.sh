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

function _db_add_or_replace_entry
{
  local KEY=${1}
  local VALUE=${2}
  local DATABASE=${3}

  # Replace value for an existing key, or add new key->value entry:
  if grep -qi "^${KEY}" "${DATABASE}" 2>/dev/null
  then
    sed -i "s|^${KEY}.*|${VALUE}|" "${DATABASE}"
  else
    echo -e "${VALUE}" >>"${DATABASE}"
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
  # Escaped value for use in regex pattern:
  local _MAIL_ACCOUNT_=$(_escape "${MAIL_ACCOUNT}")

  # `|` is a delimter between the account identity (_MAIL_ACCOUNT_) and the hashed password
  grep -qi "^${_MAIL_ACCOUNT_}|" "${DATABASE}" 2>/dev/null
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
