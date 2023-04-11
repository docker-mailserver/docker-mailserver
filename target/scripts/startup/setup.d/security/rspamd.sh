#!/bin/bash

# Function called during global setup to handle the complete setup of Rspamd.
function _setup_rspamd
{
  if [[ ${ENABLE_RSPAMD} -eq 1 ]]
  then
    _log 'warn' 'Rspamd integration is work in progress - expect changes at any time'
    _log 'debug' 'Enabling and configuring Rspamd'

    __rspamd__run_early_setup_and_checks        # must run first
    __rspamd__setup_redis
    __rspamd__setup_postfix
    __rspamd__setup_clamav
    __rspamd__setup_default_modules
    __rspamd__setup_learning
    __rspamd__setup_greylisting
    __rspamd__handle_user_modules_adjustments   # must run last

    _log 'trace' 'Rspamd setup finished'
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

# Helper for explicitly enabling or disabling a specific module.
#
# @param ${1} = module name
# @param ${2} = `true` when you want to enable the module (default),
#               `false` when you want to disable the module [OPTIONAL]
# @param ${3} = whether to use `local` (default) or `override` [OPTIONAL]
function __rspamd__helper__enable_disable_module
{
  local MODULE=${1:?Module name must be provided}
  local ENABLE_MODULE=${2:-true}
  local LOCAL_OR_OVERRIDE=${3:-local}
  local MESSAGE='Enabling'

  if [[ ! ${ENABLE_MODULE} =~ ^(true|false)$ ]]
  then
    __rspamd__log 'warn' "__rspamd__helper__enable_disable_module got non-boolean argument for deciding whether module should be enabled or not"
    return 1
  fi

  [[ ${ENABLE_MODULE} == true ]] || MESSAGE='Disabling'

  __rspamd__log 'trace' "${MESSAGE} module '${MODULE}'"
  cat >"/etc/rspamd/${LOCAL_OR_OVERRIDE}.d/${MODULE}.conf" << EOF
# documentation: https://rspamd.com/doc/modules/${MODULE}.html

enabled = ${ENABLE_MODULE};

EOF
}

# Run miscellaneous early setup tasks and checks, such as creating files needed at runtime
# or checking for other anti-spam/anti-virus software.
function __rspamd__run_early_setup_and_checks
{
  mkdir -p /var/lib/rspamd/
  : >/var/lib/rspamd/stats.ucl

  if [[ ${ENABLE_AMAVIS} -eq 1 ]] || [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]]
  then
    __rspamd__log 'warn' 'Running Amavis/SA & Rspamd at the same time is discouraged'
  fi
}

# Sets up Redis. In case the user does not use a dedicated Redis instance, we
# supply a configuration for our local Redis instance which is started later.
function __rspamd__setup_redis
{
  if [[ ${ENABLE_RSPAMD_REDIS} -eq 1 ]]
  then
    __rspamd__log 'debug' 'Internal Redis is enabled, adding configuration'
    cat >/etc/rspamd/local.d/redis.conf << "EOF"
# documentation: https://rspamd.com/doc/configuration/redis.html

servers = "127.0.0.1:6379";
expand_keys = true;

EOF

    # Here we adjust the Redis default configuration that we supply to Redis
    # when starting it. Note that `/var/lib/redis/` is linked to
    # `/var/mail-state/redis/` (for persisting it) if `ONE_DIR=1`.
    sedfile -i -E                              \
      -e 's|^(bind).*|\1 127.0.0.1|g'          \
      -e 's|^(daemonize).*|\1 no|g'            \
      -e 's|^(port).*|\1 6379|g'               \
      -e 's|^(loglevel).*|\1 warning|g'        \
      -e 's|^(logfile).*|\1 ""|g'              \
      -e 's|^(dir).*|\1 /var/lib/redis|g'      \
      -e 's|^(dbfilename).*|\1 dms-dump.rdb|g' \
      /etc/redis/redis.conf
  else
    __rspamd__log 'debug' 'Rspamd will not use internal Redis (which has been disabled)'
  fi
}

# Adjust Postfix's configuration files. We only need to append Rspamd at the end of
# `smtpd_milters` in `/etc/postfix/main.cf`.
function __rspamd__setup_postfix
{
  __rspamd__log 'debug' "Adjusting Postfix's configuration"

  postconf 'rspamd_milter = inet:localhost:11332'
  # shellcheck disable=SC2016
  sed -i -E 's|^(smtpd_milters =.*)|\1 \$rspamd_milter|g' /etc/postfix/main.cf
}

# If ClamAV is enabled, we will integrate it into Rspamd.
function __rspamd__setup_clamav
{
  if [[ ${ENABLE_CLAMAV} -eq 1 ]]
  then
    __rspamd__log 'debug' 'Enabling ClamAV integration'
    sedfile -i -E 's|^(enabled).*|\1 = true;|g' /etc/rspamd/local.d/antivirus.conf
    # Rspamd uses ClamAV's UNIX socket, and to be able to read it, it must be in the same group
    usermod -a -G clamav _rspamd
  else
    __rspamd__log 'debug' 'Rspamd will not use ClamAV (which has not been enabled)'
  fi
}

# Disables certain modules by default. This can be overwritten by the user later.
# We disable the modules listed in `DISABLE_MODULES` as we believe these modules
# are not commonly used and the average user does not need them. As a consequence,
# disabling them saves resources.
function __rspamd__setup_default_modules
{
  __rspamd__log 'debug' 'Disabling default modules'

  local DISABLE_MODULES=(
    clickhouse
    elastic
    neural
    reputation
    spamassassin
    url_redirector
    metric_exporter
  )

  for MODULE in "${DISABLE_MODULES[@]}"
  do
    __rspamd__helper__enable_disable_module "${MODULE}" 'false'
  done
}

# This function sets up intelligent learning of Junk, by
#
# 1. enabling auto-learn for the classifier-bayes module
# 2. setting up sieve scripts that detect when a user is moving e-mail
#    from or to the "Junk" folder, and learning them as ham or spam.
function __rspamd__setup_learning
{
  if [[ ${RSPAMD_LEARN} -eq 1 ]]
  then
    __rspamd__log 'debug' 'Setting up intelligent learning of spam and ham'

    local SIEVE_PIPE_BIN_DIR='/usr/lib/dovecot/sieve-pipe'
    ln -s "$(type -f -P rspamc)" "${SIEVE_PIPE_BIN_DIR}/rspamc"

    sedfile -i -E 's|(mail_plugins =.*)|\1 imap_sieve|' /etc/dovecot/conf.d/20-imap.conf
    sedfile -i -E '/^}/d' /etc/dovecot/conf.d/90-sieve.conf
    cat >>/etc/dovecot/conf.d/90-sieve.conf << EOF

  # From elsewhere to Junk folder
  imapsieve_mailbox1_name = Junk
  imapsieve_mailbox1_causes = COPY
  imapsieve_mailbox1_before = file:${SIEVE_PIPE_BIN_DIR}/learn-spam.sieve

  # From Junk folder to elsewhere
  imapsieve_mailbox2_name = *
  imapsieve_mailbox2_from = Junk
  imapsieve_mailbox2_causes = COPY
  imapsieve_mailbox2_before = file:${SIEVE_PIPE_BIN_DIR}/learn-ham.sieve
}
EOF

    cat >"${SIEVE_PIPE_BIN_DIR}/learn-spam.sieve" << EOF
require ["vnd.dovecot.pipe", "copy", "imapsieve"];
pipe :copy "rspamc" ["-h", "127.0.0.1:11334", "learn_spam"];
EOF

    cat >"${SIEVE_PIPE_BIN_DIR}/learn-ham.sieve" << EOF
require ["vnd.dovecot.pipe", "copy", "imapsieve"];
pipe :copy "rspamc" ["-h", "127.0.0.1:11334", "learn_ham"];
EOF

    sievec "${SIEVE_PIPE_BIN_DIR}/learn-spam.sieve"
    sievec "${SIEVE_PIPE_BIN_DIR}/learn-ham.sieve"
  else
    __rspamd__log 'debug' 'Intelligent learning of spam and ham is disabled'
  fi
}

# Sets up greylisting based on the environment variable RSPAMD_GREYLISTING.
function __rspamd__setup_greylisting
{
  if [[ ${RSPAMD_GREYLISTING} -eq 1 ]]
  then
    __rspamd__log 'debug' 'Enabling greylisting'
    sedfile -i -E "s|(enabled =).*|\1 true;|g" /etc/rspamd/local.d/greylist.conf
  else
    __rspamd__log 'debug' 'Greylisting is disabled'
  fi
}

# Parses `RSPAMD_CUSTOM_COMMANDS_FILE` and executed the directives given by the file.
# To get a detailed explanation of the commands and how the file works, visit
# https://docker-mailserver.github.io/docker-mailserver/edge/config/security/rspamd/#with-the-help-of-a-custom-file
function __rspamd__handle_user_modules_adjustments
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
  # While this function is currently bound to the scope of `__rspamd__handle_user_modules_adjustments`,
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
