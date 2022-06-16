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

  # Escaped values for use in regex patterns:
  _MAIL_ALIAS_=$(_escape "${MAIL_ALIAS}")
  _RECIPIENT_=$(_escape "${RECIPIENT}")

  function _recipient_already_mapped_to_alias
  {
    # Presumably intended to account for white-space or other aliases inbetween?
    # Why are only these values considered valid?
    local VALID_CONTENT='[a-zA-Z@.\ ]*'
    local MATCH_PATTERN="^${_MAIL_ALIAS_}${VALID_CONTENT}${_RECIPIENT_}"

    grep -qi "${MATCH_PATTERN}" "${DATABASE_VIRTUAL}" 2>/dev/null
  }

  function _alias_already_exists
  {
    _key_exists_in_db "${_MAIL_ALIAS_}" '\s' "${DATABASE_VIRTUAL}"
  }

  _recipient_already_mapped_to_alias && _exit_with_error "'${MAIL_ALIAS}' is already an alias for ${RECIPIENT}'"

  if _alias_already_exists
  then
    # Append recipient to existing alias entry:
    sed -i "/${MAIL_ALIAS}/s/$/,${RECIPIENT}/" "${DATABASE_VIRTUAL}"
  else
    echo "${MAIL_ALIAS} ${RECIPIENT}" >>"${DATABASE_VIRTUAL}"
  fi
}

# Used by delalias + delmailuser
# Removes a recipient from a specific alias (`MAIL_ALIAS`), otherwise all aliases:
# NOTE: If a matched alias has no additional recipients, it is also removed.
function _alias_remove_for_recipient
{
  local RECIPIENT=${1}
  local MAIL_ALIAS=${2}

  # Escaped value for use in regex pattern:
  local _MAIL_ALIAS_=$(_escape "${MAIL_ALIAS}")
  local _RECIPIENT_=$(_escape "${RECIPIENT}")

  # If no specific alias was provided, match any alias key:
  [[ -z _MAIL_ALIAS_ ]] _MAIL_ALIAS_='\S+'

  local DATABASE_VIRTUAL='/tmp/docker-mailserver/postfix-virtual.cf'
  [[ -s ${DATABASE_VIRTUAL} ]] || exit 0

  sed -i -r \
    -e "/^${_MAIL_ALIAS_}\s+${_RECIPIENT_}$/d"  \
    -e "/^${_MAIL_ALIAS_}/s/,${_RECIPIENT_}//g" \
    -e "/^${_MAIL_ALIAS_}/s/${_RECIPIENT_},//g" \
    "${DATABASE_VIRTUAL}"
}

# Returns a comma delimited list of aliases associated to a recipient (ideally the recipient is a mail account):
function _alias_list_for_account
{
  local ARG_MAIL_ACCOUNT=${1}
  local DATABASE_VIRTUAL='/tmp/docker-mailserver/postfix-virtual.cf'

  function _account_has_an_existing_alias
  {
    grep -qi "${ARG_MAIL_ACCOUNT}" "${DATABASE_VIRTUAL}" 2>/dev/null
  }

  if [[ -f ${DATABASE_VIRTUAL} ]] && _account_has_an_existing_alias
  then
    grep "${ARG_MAIL_ACCOUNT}" "${DATABASE_VIRTUAL}" | awk '{print $1;}' | sed ':a;N;$!ba;s/\n/, /g'
  fi
}

# Input validation:
function _arg_expect_alias_and_recipient
{
  [[ -z ${MAIL_ALIAS} ]] && { __usage ; _exit_with_error 'No alias specified' ; }
  [[ -z ${RECIPIENT} ]] && { __usage ; _exit_with_error 'No recipient specified' ; }
}
