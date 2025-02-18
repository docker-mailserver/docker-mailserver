#! /bin/bash

# shellcheck disable=SC2034 # VAR appears unused.

# Perform a specific command as the Rspamd user (`_rspamd`). This is useful
# in case you want to have correct permissions on newly created files or if
# you want to check whether Rspamd can perform a specific action.
#
# @flag ${1} = '--quiet' to indicate whether log should be disabled [OPTIONAL]
function __do_as_rspamd_user() {
  if [[ ${1:-} != '--quiet' ]]; then
    _log 'trace' "Running '${*}' as user '_rspamd'"
  else
    shift 1
  fi

  su _rspamd -s /bin/bash -c "${*} 2>${__RSPAMD_ERR_LOG_FILE:-/dev/null}"
}

# Create a temporary log file (with `mktemp`) that one can filter to search
# for error messages. This is required as `rspamadm` sometimes prints an error
# but does not exit with an error.
#
# The file created is managed in the ENV `__RSPAMD_ERR_LOG_FILE`. This ENV is
# meant for internal usage; do not use it on your scripts. The log file is cleaned
# up when the script exits.
function __create_rspamd_err_log() {
  _log 'trace' "Creating Rspamd error log"
  trap 'rm -f "${__RSPAMD_ERR_LOG_FILE}"' EXIT # cleanup when we exit
  __RSPAMD_ERR_LOG_FILE=$(__do_as_rspamd_user --quiet mktemp)
}

# Print the Rspamd temporary error log. This will succeed only when the log has been
# created before.
function __print_rspamd_err_log() {
  [[ -v __RSPAMD_ERR_LOG_FILE ]] && __do_as_rspamd_user cat "${__RSPAMD_ERR_LOG_FILE}"
}

# Print the Rspamd temporary error log. We use `grep` but with "fixed strings", which
# means the message you provide is evaluated as-is, not as a regular expression. This
# will succeed only when the log has been created before.
#
# @param ${1} = message to filter by
function __filter_rspamd_err_log() {
  if [[ -v __RSPAMD_ERR_LOG_FILE ]]; then
    __do_as_rspamd_user grep \
      --quiet \
      --ignore-case \
      --fixed-strings \
      "${1:?A message for filtering is required}" \
      "${__RSPAMD_ERR_LOG_FILE}"
  fi
}

# Calling this function brings common Rspamd-related environment variables
# into the current context. The environment variables are `readonly`, i.e.
# they cannot be modified. Use this function when you require common directory
# names, file names, etc.
function _rspamd_get_envs() {
  # If the variables are already set, we cannot set them again as they are declared
  # with `readonly`. Checking whether one is declared suffices, because either all
  # are declared at once, or none.
  if [[ ! -v RSPAMD_LOCAL_D ]]; then
    readonly RSPAMD_LOCAL_D='/etc/rspamd/local.d'
    readonly RSPAMD_OVERRIDE_D='/etc/rspamd/override.d'

    readonly RSPAMD_DMS_D='/tmp/docker-mailserver/rspamd'
    readonly RSPAMD_DMS_DKIM_D="${RSPAMD_DMS_D}/dkim"
    readonly RSPAMD_DMS_OVERRIDE_D="${RSPAMD_DMS_D}/override.d"

    readonly RSPAMD_DMS_CUSTOM_COMMANDS_F="${RSPAMD_DMS_D}/custom-commands.conf"
  fi
}

# Parses `RSPAMD_DMS_CUSTOM_COMMANDS_F` and executed the directives given by the file.
# To get a detailed explanation of the commands and how the file works, visit
# https://docker-mailserver.github.io/docker-mailserver/latest/config/security/rspamd/#with-the-help-of-a-custom-file
function _rspamd_handle_user_modules_adjustments() {
  # Adds an option with a corresponding value to a module, or, in case the option
  # is already present, overwrites it.
  #
  # @param ${1} = file name in ${RSPAMD_OVERRIDE_D}/
  # @param ${2} = module name as it should appear in the log
  # @param ${3} = option name in the module
  # @param ${4} = value of the option
  #
  # ## Note
  #
  # While this function is currently bound to the scope of `_rspamd_handle_user_modules_adjustments`,
  # it is written in a versatile way (taking 4 arguments instead of assuming `ARGUMENT2` / `ARGUMENT3`
  # are set) so that it may be used elsewhere if needed.
  function __add_or_replace() {
    local MODULE_FILE=${1:?Module file name must be provided}
    local MODULE_LOG_NAME=${2:?Module log name must be provided}
    local OPTION=${3:?Option name must be provided}
    local VALUE=${4:?Value belonging to an option must be provided}
    # remove possible whitespace at the end (e.g., in case ${ARGUMENT3} is empty)
    VALUE=${VALUE% }
    local FILE="${RSPAMD_OVERRIDE_D}/${MODULE_FILE}"

    readonly MODULE_FILE MODULE_LOG_NAME OPTION VALUE FILE

    [[ -f ${FILE} ]] || touch "${FILE}"

    if grep -q -E "${OPTION}.*=.*" "${FILE}"; then
      __rspamd__log 'trace' "Overwriting option '${OPTION}' with value '${VALUE}' for ${MODULE_LOG_NAME}"
      sed -i -E "s|([[:space:]]*${OPTION}).*|\1 = ${VALUE};|g" "${FILE}"
    else
      __rspamd__log 'trace' "Setting option '${OPTION}' for ${MODULE_LOG_NAME} to '${VALUE}'"
      echo "${OPTION} = ${VALUE};" >>"${FILE}"
    fi
  }

  if [[ -f "${RSPAMD_DMS_CUSTOM_COMMANDS_F}" ]]; then
    __rspamd__log 'debug' "Found file '${RSPAMD_DMS_CUSTOM_COMMANDS_F}' - parsing and applying it"

    local COMMAND ARGUMENT1 ARGUMENT2 ARGUMENT3
    while read -r COMMAND ARGUMENT1 ARGUMENT2 ARGUMENT3; do
      case "${COMMAND}" in
        ('disable-module')
          __rspamd__helper__enable_disable_module "${ARGUMENT1}" 'false' 'override'
          ;;

        ('enable-module')
          __rspamd__helper__enable_disable_module "${ARGUMENT1}" 'true' 'override'
          ;;

        ('set-option-for-module')
          __add_or_replace "${ARGUMENT1}.conf" "module '${ARGUMENT1}'" "${ARGUMENT2}" "${ARGUMENT3}"
          ;;

        ('set-option-for-controller')
          __add_or_replace 'worker-controller.inc' 'controller worker' "${ARGUMENT1}" "${ARGUMENT2} ${ARGUMENT3}"
          ;;

        ('set-option-for-proxy')
          __add_or_replace 'worker-proxy.inc' 'proxy worker' "${ARGUMENT1}" "${ARGUMENT2} ${ARGUMENT3}"
          ;;

        ('set-common-option')
          __add_or_replace 'options.inc' 'common options' "${ARGUMENT1}" "${ARGUMENT2} ${ARGUMENT3}"
          ;;

        ('add-line')
          __rspamd__log 'trace' "Adding complete line to '${ARGUMENT1}'"
          echo "${ARGUMENT2}${ARGUMENT3+ ${ARGUMENT3}}" >>"${RSPAMD_OVERRIDE_D}/${ARGUMENT1}"
          ;;

        (*)
          __rspamd__log 'warn' "Command '${COMMAND}' is invalid"
          continue
          ;;
      esac
    done < <(_get_valid_lines_from_file "${RSPAMD_DMS_CUSTOM_COMMANDS_F}")
  fi
}
