#! /bin/bash

# Used from /usr/local/bin/helpers/index.sh:
# _exit_with_error, _create_lock

# Collection of methods to manage Dovecot Quota support

# Set - Used by setquota:
function _quota_set_for_mail_account
{
  local MAIL_ACCOUNT=${1}
  local QUOTA=${2}

  local DATABASE_QUOTA='/tmp/docker-mailserver/dovecot-quotas.cf'
  _create_lock # Protect config file with lock to avoid race conditions
  touch "${DATABASE_QUOTA}"

  _db_add_or_replace_entry "${MAIL_ACCOUNT}" ':' "${QUOTA}" "${DATABASE_QUOTA}"
}

# Delete - Used by delquota:
function _quota_remove_for_mail_account
{
  local MAIL_ACCOUNT=${1}
  # Escaped value for use in regex pattern:
  local _MAIL_ACCOUNT_=$(_escape "${MAIL_ACCOUNT}")

  local DATABASE_QUOTA='/tmp/docker-mailserver/dovecot-quotas.cf'
  # If the account doesn't have a quota, don't return a failure status:
  _key_exists_in_db "${MAIL_ACCOUNT}" ':' "${DATABASE_QUOTA}" || return 0

  # Delete the entry for an account, return failure status if unsuccessful:
  sedfile --strict -i -e "/^${_MAIL_ACCOUNT_}:.*$/d" "${DATABASE_QUOTA}"
}

# List - Used by listmailuser:
function _quota_show_for
{
  [[ ${ENABLE_QUOTAS} -ne 1 ]] && return 0

  local ARG_MAIL_ACCOUNT=${1}

  local QUOTA_INFO
  # Matches a line where the 3rd column is `type='STORAGE'` - returning the next three column values:
  IFS=' ' read -r -a QUOTA_INFO <<< "$(doveadm quota get -u "${ARG_MAIL_ACCOUNT}" | tail +2 | awk '{ if ($3 == "STORAGE") { print $4" "$5" "$6 } }')"

  # Format the extracted quota storage columns:
  local CURRENT_SIZE="$(_bytes_to_human_readable_size "${QUOTA_INFO[0]}")"
  local SIZE_LIMIT="$(_bytes_to_human_readable_size "${QUOTA_INFO[1]}")"
  local PERCENT_USED="${QUOTA_INFO[2]}%"

  echo "( ${CURRENT_SIZE} / ${SIZE_LIMIT} ) [${PERCENT_USED}]"
}

function _bytes_to_human_readable_size
{
  # `-` represents a non-applicable value (eg: Like when `SIZE_LIMIT` is not set):
  if [[ ${1:-} == '-' ]]
  then
    echo '~'
  # Otherwise a value in KibiBytes (1024 bytes == 1k) is expected (Dovecots internal representation):
  elif [[ ${1:-} =~ ^[0-9]+$ ]]
  then
    # kibibytes to bytes, converted to approproate IEC unit (eg: MiB):
    echo $(( 1024 * ${1} )) | numfmt --to=iec
  else
    _exit_with_error "Supplied non-number argument '${1:-}' to '_bytes_to_human_readable_size()'"
  fi
}

# Input validation relies on the following to be defined before calling:
# - External var: QUOTA
# - External method: __usage
function _arg_expect_quota_valid_unit
{
  _quota_request_if_missing
  _quota_unit_is_valid
}

function _quota_request_if_missing
{
  if [[ -z ${QUOTA} ]]
  then
    read -r -p 'Enter quota (e.g. 10M): ' QUOTA
    echo
    [[ -z "${QUOTA}" ]] && _exit_with_error 'Quota must not be empty (use 0 for unlimited quota)'
  fi
}

function _quota_unit_is_valid
{
  if ! grep -qE "^([0-9]+(B|k|M|G|T)|0)\$" <<< "${QUOTA}"
  then
    __usage
    _exit_with_error 'Invalid quota format. e.g. 302M (B (byte), k (kilobyte), M (megabyte), G (gigabyte) or T (terabyte))'
  fi
}
