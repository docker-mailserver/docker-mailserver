#!/bin/bash

function _escape() {
  echo "${1//./\\.}"
}

# Replaces a string so that it can be used inside the `sed` regex segment safely.
# WARNING: Only for use with `sed -E` / `sed -r` due to escaping additional tokens,
# which are valid tokens when escaped in basic regex mode.
#
# @param ${1} = string to escape
# @output     = prints the escaped string
function _escape_for_sed() {
  # Escapes all special tokens:
  # - `/` should represent the sed delimiter (caution when using sed with a non-default delimiter).
  # - `]` should be the first char, while `.` must not be the 2nd.
  # - Within the `[ ... ]` scope, no escaping is needed regardless of basic vs extended regexp mode.
  local REGEX_BASIC='][/\$*.^'
  # In this mode (`-E` / `-r`), these tokens no longer require a preceding `\`, so must also be escaped:
  local REGEX_EXTENDED='|?)(}{+'
  # The replacement segment is compatible but most tokens do not require escaping.
  # `&` is a token for this segment, and is compatible with escaping in the regex segment:
  local TOKEN_REPLACEMENT='&'
  local REGEX_SEGMENT="${REGEX_BASIC}${REGEX_EXTENDED}${TOKEN_REPLACEMENT}"

  # Output: `\\` prepends a `\` to a token matched by the regex segment (`&`)
  local PREPEND_ESCAPE='\\&'

  # Full sed expression: sed -E 's/[][/\$*.^|?)(}{+&]/\\&/g'
  sed -E "s/[${REGEX_SEGMENT}]/${PREPEND_ESCAPE}/g" <<< "${1:?String to escape for sed is required}"
}

# Returns input after filtering out lines that are:
# empty, white-space, comments (`#` as the first non-whitespace character)
function _get_valid_lines_from_file() {
  _convert_crlf_to_lf_if_necessary "${1}"
  _append_final_newline_if_missing "${1}"

  grep --extended-regexp --invert-match "^\s*$|^\s*#" "${1}" || true
}

# This is to sanitize configs from users that unknowingly introduced CRLF:
function _convert_crlf_to_lf_if_necessary() {
  if [[ $(file "${1}") =~ 'CRLF' ]]; then
    _log 'warn' "File '${1}' contains CRLF line-endings"

    if [[ -w ${1} ]]; then
      _log 'debug' 'Converting CRLF to LF'
      sed -i 's|\r||g' "${1}"
    else
      _log 'warn' "File '${1}' is not writable - cannot change CRLF to LF"
    fi
  fi
}

# This is to sanitize configs from users that unknowingly removed the end-of-file LF:
function _append_final_newline_if_missing() {
  # Correctly detect a missing final newline and fix it:
  # https://stackoverflow.com/questions/38746/how-to-detect-file-ends-in-newline#comment82380232_25749716
  # https://unix.stackexchange.com/questions/31947/how-to-add-a-newline-to-the-end-of-a-file/441200#441200
  # https://unix.stackexchange.com/questions/159557/how-to-non-invasively-test-for-write-access-to-a-file
  if [[ $(tail -c1 "${1}" | wc -l) -eq 0 ]]; then
    # Avoid fixing when the destination is read-only:
    if [[ -w ${1} ]]; then
      printf '\n' >> "${1}"

      _log 'info' "File '${1}' was missing a final newline - this has been fixed"
    else
      _log 'warn' "File '${1}' is missing a final newline - it is not writable, hence it was not fixed - the last line will not be processed!"
    fi
  fi
}

# Provide the name of an environment variable to this function
# and it will return its value stored in /etc/dms-settings
function _get_dms_env_value() {
  if [[ -f /etc/dms-settings ]]; then
    grep "^${1}=" /etc/dms-settings | cut -d "'" -f 2
  else
    _log 'warn' "Call to '_get_dms_env_value' but '/etc/dms-settings' is not present"
    return 1
  fi
}

# TODO: `chown -R 5000:5000 /var/mail` has existed since the projects first commit.
# It later received a depth guard to apply the fix only when it's relevant for a dir.
# Assess if this still appropriate, it appears to be problematic for some LDAP users.
#
# `helpers/accounts.sh:_create_accounts` (mkdir, cp) appears to be the only writer to
# /var/mail folders (used during startup and change detection handling).
function _chown_var_mail_if_necessary() {
  # fix permissions, but skip this if 3 levels deep the user id is already set
  if find /var/mail -maxdepth 3 -a \( \! -user "${DMS_VMAIL_UID}" -o \! -group "${DMS_VMAIL_GID}" \) | read -r; then
    _log 'trace' 'Fixing /var/mail permissions'
    chown -R "${DMS_VMAIL_UID}:${DMS_VMAIL_GID}" /var/mail || return 1
  fi
}

function _require_n_parameters_or_print_usage() {
  local COUNT
  COUNT=${1}
  shift

  [[ ${1:-} == 'help' ]]  && { __usage ; exit 0 ; }
  [[ ${#} -lt ${COUNT} ]] && { __usage ; exit 1 ; }
  return 0
}

# NOTE: Postfix commands that read `main.cf` will stall execution,
# until the config file has not be written to for at least 2 seconds.
# After we modify the config explicitly, we can safely assume (reasonably)
# that the write stream has completed, and it is safe to read the config.
# https://github.com/docker-mailserver/docker-mailserver/issues/2985
function _adjust_mtime_for_postfix_maincf() {
  if [[ $(( $(date '+%s') - $(stat -c '%Y' '/etc/postfix/main.cf') )) -lt 2 ]]; then
    touch -d '2 seconds ago' /etc/postfix/main.cf
  fi
}

function _reload_postfix() {
  _adjust_mtime_for_postfix_maincf
  postfix reload
}

# Replaces values in configuration files given a set of specific environment
# variables. The environment variables follow a naming pattern, whereby every
# variable that is taken into account has a given prefix. The new value in the
# configuration will be the one the environment variable had at the time of
# calling this function.
#
# @option --shutdown-on-error = shutdown in case an error is detected
# @param ${1} = Prefix for selecting environment variables
# @param ${2} = File in which substitutions should take place
# @param ${3} = The key/value assignment operator used (default: `=`) [OPTIONAL]
#
# ## Example
#
# If you want to set a new value for `readme_directory` in Postfix's `main.cf`,
# you can set the environment variable `POSTFIX_README_DIRECTORY='/new/dir/'`
# (`POSTFIX_` is an arbitrary prefix, you can choose the one you like),
# and then call this function:
# `_replace_by_env_in_file 'POSTFIX_' '/etc/postfix/main.cf`
#
# ## Panics
#
# This function will panic, i.e. shut down the whole container, if:
#
# 1. No first and second argument is supplied
# 2. The second argument is a path to a file that does not exist
function _replace_by_env_in_file() {
  if [[ -z ${1+set} ]]; then
    _dms_panic__invalid_value 'first argument unset' 'utils.sh:_replace_by_env_in_file'
  elif [[ -z ${2+set} ]]; then
    _dms_panic__invalid_value 'second argument unset' 'utils.sh:_replace_by_env_in_file'
  elif [[ ! -f ${2} ]]; then
    _dms_panic__invalid_value "file '${2}' does not exist" 'utils.sh:_replace_by_env_in_file'
  fi

  local ENV_PREFIX=${1} CONFIG_FILE=${2}
  local KV_DELIMITER=${3:-'='}
  local ESCAPED_VALUE ESCAPED_KEY

  while IFS="${KV_DELIMITER}" read -r KEY VALUE; do
    KEY=${KEY#"${ENV_PREFIX}"} # strip prefix
    ESCAPED_KEY=$(_escape_for_sed "${KEY,,}")
    ESCAPED_VALUE=$(_escape_for_sed "${VALUE}")
    _log 'trace' "Setting value of '${KEY}' in '${CONFIG_FILE}' to '${VALUE}'"
    sedfile -i -E "s#^(${ESCAPED_KEY}[[:space:]]*${KV_DELIMITER}[[:space:]]*).*#\1${ESCAPED_VALUE}#gi" "${CONFIG_FILE}"
  done < <(env | grep "^${ENV_PREFIX}")
}

# Check if an environment variable's value is zero or one. This aids in checking variables
# that act as "booleans" for enabling or disabling a service, configuration option, etc.
#
# This function will log a warning and return with exit code 1 in case the variable's value
# is not zero or one.
#
# @param ${1} = name of the ENV variable to check
function _env_var_expect_zero_or_one() {
  local ENV_VAR_NAME=${1:?ENV var name must be provided to _env_var_expect_zero_or_one}

  if [[ ! -v ${ENV_VAR_NAME} ]]; then
    _log 'warn' "'${ENV_VAR_NAME}' is not set, but was expected to be"
    return 1
  fi

  if [[ ! ${!ENV_VAR_NAME} =~ ^(0|1)$ ]]; then
    _log 'warn' "The value of '${ENV_VAR_NAME}' (= '${!ENV_VAR_NAME}') is not 0 or 1, but was expected to be"
    return 1
  fi

  return 0
}

# Check if an environment variable's value is an integer.
#
# This function will log a warning and return with exit code 1 in case the variable's value
# is not an integer.
#
# @param ${1} = name of the ENV variable to check
function _env_var_expect_integer() {
  local ENV_VAR_NAME=${1:?ENV var name must be provided to _env_var_expect_integer}

  [[ ${!ENV_VAR_NAME} =~ ^-?[0-9][0-9]*$ ]] && return 0
  _log 'warn' "The value of '${ENV_VAR_NAME}' is not an integer ('${!ENV_VAR_NAME}'), but was expected to be"
  return 1
}
