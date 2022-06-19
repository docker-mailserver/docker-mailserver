#! /bin/bash

# Used from /usr/local/bin/helpers/index.sh:
# _escape, _exit_with_error

# Some of these helpers rely on:
# - Exteral vars to be declared prior to calling them (MAIL_ALIAS, RECIPIENT).
# - Calling external method '__usage' as part of error handling.

# Collection of methods to operate on virtual alias database: `postfix-virtual.cf`.

# An alias may be any of `user@domain`, `user`, `@domain`.
# Recipients are local (internal services), hosted (managed accounts), remote (third-party MTA), or aliases,
# An alias may redirect mail to one or more recipients. If a recipient is an alias it will recursively resolve.
# NOTE: Support for recipients of the alias type may not be well supported by this project.

# Associate an alias to a recipient:
function _alias_add_for_recipient
{
  local MAIL_ALIAS=${1}
  local RECIPIENT=${2}

  local DATABASE_VIRTUAL='/tmp/docker-mailserver/postfix-virtual.cf'
  _db_entry_add_or_append "${DATABASE_VIRTUAL}" "${MAIL_ALIAS}" "${RECIPIENT}" \
    || _exit_with_error "'${MAIL_ALIAS}' is already an alias for recipient: '${RECIPIENT}'"
}

# Used by delalias + delmailuser
# Removes RECIPIENT from all aliases unless provided a target with MAIL_ALIAS:
# NOTE: If a matched alias has no additional recipients, it is also removed.
function _alias_remove_for_recipient
{
  local RECIPIENT=${1}
  local MAIL_ALIAS=${2}

  # If no specific alias was provided, match any alias key:
  [[ -z ${MAIL_ALIAS} ]] && MAIL_ALIAS='\S\+'

  local DATABASE_VIRTUAL='/tmp/docker-mailserver/postfix-virtual.cf'
  _db_entry_remove "${DATABASE_VIRTUAL}" "${MAIL_ALIAS}" "${RECIPIENT}"
}

# Returns a comma delimited list of aliases associated to a recipient (ideally the recipient is a mail account):
function _alias_list_for_account
{
  local MAIL_ACCOUNT=${1}
  local DATABASE_VIRTUAL='/tmp/docker-mailserver/postfix-virtual.cf'

  function _account_has_an_existing_alias
  {
    grep -qi "${MAIL_ACCOUNT}" "${DATABASE_VIRTUAL}" 2>/dev/null
  }

  if [[ -f ${DATABASE_VIRTUAL} ]] && _account_has_an_existing_alias
  then
    grep "${MAIL_ACCOUNT}" "${DATABASE_VIRTUAL}" | awk '{print $1;}' | sed ':a;N;$!ba;s/\n/, /g'
  fi
}

# Input validation:
function _arg_expect_alias_and_recipient
{
  [[ -z ${MAIL_ALIAS} ]] && { __usage ; _exit_with_error 'No alias specified' ; }
  [[ -z ${RECIPIENT} ]] && { __usage ; _exit_with_error 'No recipient specified' ; }
}
