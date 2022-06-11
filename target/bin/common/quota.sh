#! /bin/bash

# Used from /usr/local/bin/helpers/index.sh:
# _exit_with_error, _create_lock

# Collection of methods to manage Dovecot Quota support

# Set:
function _quota_set_for_mail_account
{
  local ARG_MAIL_ACCOUNT=${1}
  local ARG_QUOTA=${2}

  local DATABASE_QUOTA='/tmp/docker-mailserver/dovecot-quotas.cf'
  _create_lock # Protect config file with lock to avoid race conditions
  touch "${DATABASE_QUOTA}"

  # Replace any existing quota applied by removing it first, then adding it back:
  _quota_remove_for_mail_account "${ARG_MAIL_ACCOUNT}"
  echo "${ARG_MAIL_ACCOUNT}:${ARG_QUOTA}" >>"${DATABASE_QUOTA}"
}

# Delete:
function _quota_remove_for_mail_account
{
  local ARG_MAIL_ACCOUNT=${1}

  local DATABASE_QUOTA='/tmp/docker-mailserver/dovecot-quotas.cf'
  [[ -s ${DATABASE_QUOTA} ]] || exit 0

  sed -i -e "/^${ARG_MAIL_ACCOUNT}:.*$/d" "${DATABASE_QUOTA}"
}

# List:
function _quota_show_for
{
  [[ ${ENABLE_QUOTAS} -ne 1 ]] && return 0

  local ARG_MAIL_ACCOUNT=${1}

  local QUOTA_INFO
  # Match line with 3rd column of type='STORAGE', and retrieves the next three column values:
  IFS=' ' read -r -a QUOTA_INFO <<< "$(doveadm quota get -u "${ARG_MAIL_ACCOUNT}" | tail +2 | awk '{ if ($3 == "STORAGE") { print $4" "$5" "$6 } }')"

  # Extracted quota storage columns:
  local CURRENT_SIZE="$(_bytes_to_human_readable_size "${QUOTA_INFO[0]}")"
  local SIZE_LIMIT="$(_bytes_to_human_readable_size "${QUOTA_INFO[1]}")"
  local PERCENT_USED="${QUOTA_INFO[2]}%"

  echo "( ${CURRENT_SIZE} / ${SIZE_LIMIT} ) [${PERCENT_USED}]"
}

function _bytes_to_human_readable_size
{
  # '-' is a non-applicable value,
  # such as SIZE_LIMIT not being configured:
  if [[ ${1:-} == '-' ]]
  then
    echo '~'
  # Otherwise a value of bytes is expected:
  elif [[ ${1:-} =~ ^[0-9]+$ ]]
  then
    echo $(( 1024 * ${1} )) | numfmt --to=iec
  else
    _exit_with_error "Supplied non-number argument '${1:-}' to '_bytes_to_human_readable_size()'"
  fi
}

# Input validation:
# - External var: QUOTA
# - External method: __usage
function _validate_parameter_quota
{
  _quota_request_if_missing
  _quota_unit_is_valid
}

function _quota_request_if_missing
{
  if [[ -z ${QUOTA} ]]
  then
    read -r -s 'Enter quota (e.g. 10M): ' QUOTA
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
