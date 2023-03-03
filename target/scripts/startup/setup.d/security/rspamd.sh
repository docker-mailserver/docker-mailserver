#!/bin/bash

function _setup_rspamd
{
  if [[ ${ENABLE_RSPAMD} -eq 1 ]]
  then
    _log 'warn' 'Rspamd integration is work in progress - expect (breaking) changes at any time'
    _log 'debug' 'Enabling and configuring Rspamd'

    __rspamd__preflight_checks
    __rspamd__adjust_postfix_configuration
    __rspamd__disable_default_modules
    __rspamd__handle_modules_configuration
  else
    _log 'debug' 'Rspamd is disabled'
  fi
}

# Just a helper to prepend the log messages with `(Rspamd setup)` so
# users know exactly where the message originated from.
#
# @param ${1} = log level
# @param ${2} = message
function __rspamd__log { _log "${1:-}" "(Rspamd setup) ${2:-}" ; }

# Run miscellaneous checks against the current configuration so we can
# properly handle integration into ClamAV, etc.
#
# This will also check whether Amavis is enabled and emit a warning as
# we discourage users from running Amavis & Rspamd at the same time.
function __rspamd__preflight_checks
{
  touch /var/lib/rspamd/stats.ucl

  if [[ ${ENABLE_AMAVIS} -eq 1 ]] || [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]]
  then
    __rspamd__log 'warn' 'Running Amavis/SA & Rspamd at the same time is discouraged'
  fi

  if [[ ${ENABLE_CLAMAV} -eq 1 ]]
  then
    __rspamd__log 'debug' 'Enabling ClamAV integration'
    sedfile -i -E 's|^(enabled).*|\1 = true;|g' /etc/rspamd/local.d/antivirus.conf
    # RSpamd uses ClamAV's UNIX socket, and to be able to read it, it must be in the same group
    usermod -a -G clamav _rspamd
  else
    __rspamd__log 'debug' 'Rspamd will not use ClamAV (which has not been enabled)'
  fi

  if [[ ${ENABLE_REDIS} -eq 1 ]]
  then
    __rspamd__log 'trace' 'Internal Redis is enabled, adding configuration'
    cat >/etc/rspamd/local.d/redis.conf << "EOF"
# documentation: https://rspamd.com/doc/configuration/redis.html

servers = "127.0.0.1:6379";
expand_keys = true;

EOF
  else
    __rspamd__log 'debug' 'Rspamd will not use internal Redis (which has been disabled)'
  fi
}

# Adjust Postfix's configuration files. Append Rspamd at the end of
# `smtpd_milters` in `main.cf`.
function __rspamd__adjust_postfix_configuration
{
  postconf 'rspamd_milter = inet:localhost:11332'

  # shellcheck disable=SC2016
  sed -i -E 's|^(smtpd_milters =.*)|\1 \$rspamd_milter|g' /etc/postfix/main.cf
}

# Helper for explicitly enabling or disabling a specific module.
#
# @param ${1} = module name
# @param ${2} = `true` when you want to enable the module (default),
#               `false` when you want to disable the module [OPTIONAL]
# @param ${3} = whether to use `local` (default) or `override` [OPTIONAL]
function __rspamd__enable_disable_module
{
  local MODULE=${1:?Module name must be provided}
  local ENABLE_MODULE=${2:-true}
  local LOCAL_OR_OVERRIDE=${3:-local}
  local MESSAGE='Enabling'

  if [[ ! ${ENABLE_MODULE} =~ ^(true|false)$ ]]
  then
    __rspamd__log 'warn' "__rspamd__enable_disable_module got non-boolean argument for deciding whether module should be enabled or not"
    return 1
  fi

  [[ ${ENABLE_MODULE} == true ]] || MESSAGE='Disabling'

  __rspamd__log 'trace' "${MESSAGE} module '${MODULE}'"
  cat >"/etc/rspamd/${LOCAL_OR_OVERRIDE}.d/${MODULE}.conf" << EOF
# documentation: https://rspamd.com/doc/modules/${MODULE}.html

enabled = ${ENABLE_MODULE};

EOF
}

# Disables certain modules by default. This can be overwritten by the user later.
# We disable the modules listed in `DISABLE_MODULES` as we believe these modules
# are not commonly used and the average user does not need them. As a consequence,
# disabling them saves resources.
function __rspamd__disable_default_modules
{
  local DISABLE_MODULES=(
    clickhouse
    elastic
    greylist
    neural
    reputation
    spamassassin
    url_redirector
    metric_exporter
  )

  for MODULE in "${DISABLE_MODULES[@]}"
  do
    __rspamd__enable_disable_module "${MODULE}" 'false'
  done
}

# Parses `RSPAMD_CUSTOM_COMMANDS_FILE` and executed the directives given by the file.
# To get a detailed explanation of the commands and how the file works, visit
# https://docker-mailserver.github.io/docker-mailserver/edge/config/security/rspamd/#with-the-help-of-a-custom-file
function __rspamd__handle_modules_configuration
{
  # Adds an option with a corresponding value to a module, or, in case the option
  # is already present, overwrites it.
  #
  # @param ${1} = file name in /etc/rspamd/override.d/
  # @param ${2} = module name as it should appear in the log
  # @patam ${3} = option name in the module
  # @param ${4} = value of the option
  #
  # ## Note
  #
  # While this function is currently bound to the scope of `__rspamd__handle_modules_configuration`,
  # it is written in a versatile way (taking 4 arguments instead of assuming `ARGUMENT2` / `ARGUMENT3`
  # are set) so that it may be used elsewhere if needed.
  function __add_or_replace
  {
    local MODULE_FILE=${1:?Module file name must be provided}
    local MODULE_LOG_NAME=${2:?Module log name must be provided}
    local OPTION=${3:?Option name must be provided}
    local VALUE=${4:?Value belonging to an option must be provided}
    # remove possible whitespace at the end (e.g., in case ${ARGUMENT3} is empty)
    VALUE=${VALUE% }

    local FILE="/etc/rspamd/override.d/${MODULE_FILE}"
    [[ -f ${FILE} ]] || touch "${FILE}"

    if grep -q -E "${OPTION}.*=.*" "${FILE}"
    then
      __rspamd__log 'trace' "Overwriting option '${OPTION}' with value '${VALUE}' for ${MODULE_LOG_NAME}"
      sed -i -E "s|([[:space:]]*${OPTION}).*|\1 = ${VALUE};|g" "${FILE}"
    else
      __rspamd__log 'trace' "Setting option '${OPTION}' for ${MODULE_LOG_NAME} to '${VALUE}'"
      echo "${OPTION} = ${VALUE};" >>"${FILE}"
    fi
  }

  local RSPAMD_CUSTOM_COMMANDS_FILE='/tmp/docker-mailserver/rspamd-modules.conf'
  if [[ -f "${RSPAMD_CUSTOM_COMMANDS_FILE}" ]]
  then
    __rspamd__log 'debug' "Found file 'rspamd-modules.conf' - parsing and applying it"

    while read -r COMMAND ARGUMENT1 ARGUMENT2 ARGUMENT3
    do
      case "${COMMAND}" in

        ('disable-module')
          __rspamd__enable_disable_module "${ARGUMENT1}" 'false' 'override'
          ;;

        ('enable-module')
          __rspamd__enable_disable_module "${ARGUMENT1}" 'true' 'override'
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
          echo "${ARGUMENT2} ${ARGUMENT3:-}" >>"/etc/rspamd/override.d/${ARGUMENT1}"
          ;;

        (*)
          __rspamd__log 'warn' "Command '${COMMAND}' is invalid"
          continue
          ;;

      esac
    done < <(_get_valid_lines_from_file "${RSPAMD_CUSTOM_COMMANDS_FILE}")
  fi
}
