#!/bin/bash

# This file is executed during startup of DMS. Hence, the `index.sh` helper has already
# been sourced, and thus, all helper functions from `rspamd.sh` are available.

# Function called during global setup to handle the complete setup of Rspamd. Functions
# with a single `_` prefix are sourced from the `rspamd.sh` helper.
function _setup_rspamd() {
  if _env_var_expect_zero_or_one 'ENABLE_RSPAMD' && [[ ${ENABLE_RSPAMD} -eq 1 ]]; then
    _log 'debug' 'Enabling and configuring Rspamd'
    __rspamd__log 'trace' '----------  Setup started  ----------'

    _rspamd_get_envs                          # must run first
    __rspamd__run_early_setup_and_checks      # must run second
    __rspamd__setup_logfile
    __rspamd__setup_redis
    __rspamd__setup_postfix
    __rspamd__setup_clamav
    __rspamd__setup_default_modules
    __rspamd__setup_learning
    __rspamd__setup_greylisting
    __rspamd__setup_hfilter_group
    __rspamd__setup_neural
    __rspamd__setup_check_authenticated
    _rspamd_handle_user_modules_adjustments   # must run last

    # only performing checks, no further setup handled from here onwards
    __rspamd__check_dkim_permissions

    __rspamd__log 'trace' '----------  Setup finished  ----------'
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
function __rspamd__helper__enable_disable_module() {
  local MODULE=${1:?Module name must be provided}
  local ENABLE_MODULE=${2:-true}
  local LOCAL_OR_OVERRIDE=${3:-local}
  local MESSAGE='Enabling'

  readonly MODULE ENABLE_MODULE LOCAL_OR_OVERRIDE

  if [[ ! ${ENABLE_MODULE} =~ ^(true|false)$ ]]; then
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
function __rspamd__run_early_setup_and_checks() {
  mkdir -p /var/lib/rspamd/
  : >/var/lib/rspamd/stats.ucl

  # Copy if directory exists and is not empty
  if [[ -d ${RSPAMD_DMS_OVERRIDE_D} ]] && [[ -z $(find "${RSPAMD_DMS_OVERRIDE_D}" -maxdepth 0 -empty) ]]; then
    cp "${RSPAMD_DMS_OVERRIDE_D}/"* "${RSPAMD_OVERRIDE_D}"
  fi

  if [[ ${ENABLE_AMAVIS} -eq 1 ]] || [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]]; then
    __rspamd__log 'warn' 'Running Amavis/SA & Rspamd at the same time is discouraged'
  fi

  if [[ ${ENABLE_OPENDKIM} -eq 1 ]]; then
    __rspamd__log 'warn' 'Running OpenDKIM & Rspamd at the same time is discouraged - we recommend Rspamd for DKIM checks (enabled with Rspamd by default) & signing'
  fi

  if [[ ${ENABLE_OPENDMARC} -eq 1 ]]; then
    __rspamd__log 'warn' 'Running OpenDMARC & Rspamd at the same time is discouraged - we recommend Rspamd for DMARC checks (enabled with Rspamd by default)'
  fi

  if [[ ${ENABLE_POLICYD_SPF} -eq 1 ]]; then
    __rspamd__log 'warn' 'Running policyd-spf & Rspamd at the same time is discouraged - we recommend Rspamd for SPF checks (enabled with Rspamd by default)'
  fi

  if [[ ${ENABLE_POSTGREY} -eq 1 ]] && [[ ${RSPAMD_GREYLISTING} -eq 1 ]]; then
    __rspamd__log 'warn' 'Running Postgrey & Rspamd at the same time is discouraged - we recommend Rspamd for greylisting'
  fi
}

# Keep in sync with `target/scripts/startup/setup.d/log.sh:_setup_logrotate()`
function __rspamd__setup_logfile() {
  cat >/etc/logrotate.d/rspamd << EOF
/var/log/mail/rspamd.log
{
  compress
  copytruncate
  delaycompress
  rotate ${LOGROTATE_COUNT}
  ${LOGROTATE_INTERVAL}
}
EOF
}

# Sets up Redis. In case the user does not use a dedicated Redis instance, we
# supply a configuration for our local Redis instance which is started later.
function __rspamd__setup_redis() {
  if _env_var_expect_zero_or_one 'ENABLE_RSPAMD_REDIS' && [[ ${ENABLE_RSPAMD_REDIS} -eq 1 ]]; then
    __rspamd__log 'debug' 'Internal Redis is enabled, adding configuration'
    cat >"${RSPAMD_LOCAL_D}/redis.conf" << "EOF"
# documentation: https://rspamd.com/doc/configuration/redis.html

servers = "127.0.0.1:6379";
expand_keys = true;

EOF

    # We do not use `{{HOSTNAME}}` but only `{{COMPRESS}}` to better support
    # Kubernetes, see https://github.com/orgs/docker-mailserver/discussions/3922
    cat >"${RSPAMD_LOCAL_D}/history_redis.conf" << "EOF"
# documentation: https://rspamd.com/doc/modules/history_redis.html

key_prefix = "rs_history{{COMPRESS}}";

EOF

    # Here we adjust the Redis default configuration that we supply to Redis when starting it.
    # NOTE: `/var/lib/redis/` is symlinked to `/var/mail-state/redis/` when DMS is started
    # with a volume mounted to `/var/mail-state/` for data persistence.
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
function __rspamd__setup_postfix() {
  __rspamd__log 'debug' "Adjusting Postfix's configuration"

  postconf 'rspamd_milter = inet:localhost:11332'
  # shellcheck disable=SC2016
  _add_to_or_update_postfix_main 'smtpd_milters' '$rspamd_milter'
}

# If ClamAV is enabled, we will integrate it into Rspamd.
function __rspamd__setup_clamav() {
  if _env_var_expect_zero_or_one 'ENABLE_CLAMAV' && [[ ${ENABLE_CLAMAV} -eq 1 ]]; then
    __rspamd__log 'debug' 'Enabling ClamAV integration'
    sedfile -i -E 's|^(enabled).*|\1 = true;|g' "${RSPAMD_LOCAL_D}/antivirus.conf"
    # Rspamd uses ClamAV's UNIX socket, and to be able to read it, it must be in the same group
    usermod -a -G clamav _rspamd

    if [[ ${CLAMAV_MESSAGE_SIZE_LIMIT} != '25M' ]]; then
      local SIZE_IN_BYTES
      SIZE_IN_BYTES=$(numfmt --from=si "${CLAMAV_MESSAGE_SIZE_LIMIT}")
      __rspamd__log 'trace' "Adjusting maximum size for ClamAV to ${SIZE_IN_BYTES} bytes (${CLAMAV_MESSAGE_SIZE_LIMIT})"
      sedfile -i -E "s|(.*max_size =).*|\1 ${SIZE_IN_BYTES};|" "${RSPAMD_LOCAL_D}/antivirus.conf"
    fi
  else
    __rspamd__log 'debug' 'Rspamd will not use ClamAV (which has not been enabled)'
  fi
}

# Disables certain modules by default. This can be overwritten by the user later.
# We disable the modules listed in `DISABLE_MODULES` as we believe these modules
# are not commonly used and the average user does not need them. As a consequence,
# disabling them saves resources.
function __rspamd__setup_default_modules() {
  __rspamd__log 'debug' 'Disabling default modules'

  # This array contains all the modules we disable by default. They
  # can be re-enabled later (in `__rspamd__handle_user_modules_adjustments`)
  # with `rspamd-modules.conf`.
  local DISABLE_MODULES=(
    clickhouse
    elastic
    reputation
    spamassassin
    url_redirector
    metric_exporter
  )

  readonly -a DISABLE_MODULES
  local MODULE
  for MODULE in "${DISABLE_MODULES[@]}"; do
    __rspamd__helper__enable_disable_module "${MODULE}" 'false'
  done
}

# This function sets up intelligent learning of Junk, by
#
# 1. enabling auto-learn for the classifier-bayes module
# 2. setting up sieve scripts that detect when a user is moving e-mail
#    from or to the "Junk" folder, and learning them as ham or spam.
function __rspamd__setup_learning() {
  if _env_var_expect_zero_or_one 'RSPAMD_LEARN' && [[ ${RSPAMD_LEARN} -eq 1 ]]; then
    __rspamd__log 'debug' 'Setting up intelligent learning of spam and ham'

    local SIEVE_PIPE_BIN_DIR='/usr/lib/dovecot/sieve-pipe'
    readonly SIEVE_PIPE_BIN_DIR
    ln -s "$(type -f -P rspamc)" "${SIEVE_PIPE_BIN_DIR}/rspamc"

    sedfile -i -E 's|(mail_plugins =.*)|\1 imap_sieve|' /etc/dovecot/conf.d/20-imap.conf
    sedfile -i -E '/^}/d' /etc/dovecot/conf.d/90-sieve.conf
    cat >>/etc/dovecot/conf.d/90-sieve.conf << EOF

  # From anywhere to Junk
  imapsieve_mailbox1_name = Junk
  imapsieve_mailbox1_causes = COPY APPEND
  imapsieve_mailbox1_before = file:${SIEVE_PIPE_BIN_DIR}/learn-spam.sieve

  # From Junk to Inbox
  imapsieve_mailbox2_name = INBOX
  imapsieve_mailbox2_from = Junk
  imapsieve_mailbox2_causes = COPY APPEND
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

# Sets up greylisting with the greylisting module (see
# https://rspamd.com/doc/modules/greylisting.html).
function __rspamd__setup_greylisting() {
  if _env_var_expect_zero_or_one 'RSPAMD_GREYLISTING' && [[ ${RSPAMD_GREYLISTING} -eq 1 ]]; then
    __rspamd__log 'debug' 'Enabling greylisting'
    sedfile -i -E "s|(enabled =).*|\1 true;|g" "${RSPAMD_LOCAL_D}/greylist.conf"
  else
    __rspamd__log 'debug' 'Greylisting is disabled'
  fi
}

# This function handles setup of the Hfilter module (see
# https://www.rspamd.com/doc/modules/hfilter.html). This module is mainly
# used for hostname checks, and whether or not a reverse-DNS check
# succeeds.
function __rspamd__setup_hfilter_group() {
  local MODULE_FILE="${RSPAMD_LOCAL_D}/hfilter_group.conf"
  readonly MODULE_FILE
  if _env_var_expect_zero_or_one 'RSPAMD_HFILTER' && [[ ${RSPAMD_HFILTER} -eq 1 ]]; then
    __rspamd__log 'debug' 'Hfilter (group) module is enabled'
    # Check if we received a number first
    if _env_var_expect_integer 'RSPAMD_HFILTER_HOSTNAME_UNKNOWN_SCORE' \
    && [[ ${RSPAMD_HFILTER_HOSTNAME_UNKNOWN_SCORE} -ne 6 ]]; then
      __rspamd__log 'trace' "Adjusting score for 'HFILTER_HOSTNAME_UNKNOWN' in Hfilter group module to ${RSPAMD_HFILTER_HOSTNAME_UNKNOWN_SCORE}"
      sed -i -E \
        "s|(.*score =).*(# __TAG__HFILTER_HOSTNAME_UNKNOWN)|\1 ${RSPAMD_HFILTER_HOSTNAME_UNKNOWN_SCORE}; \2|g" \
        "${MODULE_FILE}"
    else
      __rspamd__log 'trace' "Not adjusting score for 'HFILTER_HOSTNAME_UNKNOWN' in Hfilter group module"
    fi
  else
    __rspamd__log 'debug' 'Disabling Hfilter (group) module'
    rm -f "${MODULE_FILE}"
  fi
}


# This function handles setup of the neural module (see
# https://www.rspamd.com/doc/modules/neural.html). This module is experimental
# but can enhance anti-spam scoring possibly.
function __rspamd__setup_neural() {
  if _env_var_expect_zero_or_one 'RSPAMD_NEURAL' && [[ ${RSPAMD_NEURAL} -eq 1 ]]; then
    __rspamd__log 'debug' 'Enabling Neural module'
    __rspamd__log 'warn' 'The Neural module is still experimental (in Rspamd) and hence not tested in DMS'
  else
    __rspamd__log 'debug' 'Neural module is disabled'
    rm -f "${RSPAMD_LOCAL_D}/neural.conf"
    rm -f "${RSPAMD_LOCAL_D}/neural_group.conf"
    __rspamd__helper__enable_disable_module 'neural' 'false'
  fi
}


# If 'RSPAMD_CHECK_AUTHENTICATED' is enabled, then content checks for all users, i.e.
# also for authenticated users, are performed.
#
# The default that DMS ships does not check authenticated users. In case the checks are
# enabled, this function will remove the part of the Rspamd configuration that disables
# checks for authenticated users.
function __rspamd__setup_check_authenticated() {
  local MODULE_FILE="${RSPAMD_LOCAL_D}/settings.conf"
  readonly MODULE_FILE
  if _env_var_expect_zero_or_one 'RSPAMD_CHECK_AUTHENTICATED' \
  && [[ ${RSPAMD_CHECK_AUTHENTICATED} -eq 0 ]]; then
    __rspamd__log 'debug' 'Content checks for authenticated users are disabled'
  else
    __rspamd__log 'debug' 'Enabling content checks for authenticated users'
    sed -i -E \
      '/DMS::SED_TAG::1::START/{:a;N;/DMS::SED_TAG::1::END/!ba};/authenticated/d' \
      "${MODULE_FILE}"
  fi
}

# This function performs a simple check on the queried rspamd DKIM configuration:
# - Acquire all private key file locations and check whether they exist and can be accessed by Rspamd.
# - We are not checking paths that contain the '$' symbol.
function __rspamd__check_dkim_permissions() {
  local KEY_FILE
  while read -r KEY_FILE; do
    if [[ -f ${KEY_FILE} ]]; then
      __rspamd__log 'trace' "Checking DKIM file '${KEY_FILE}'"
      # See https://serverfault.com/a/829314 for an explanation on `-exec false {} +`
      # We additionally resolve symbolic links to check the permissions of the actual files
      if find "$(realpath -L "${KEY_FILE}")" \( -user _rspamd -or -group _rspamd -or -perm -o=r \) \
        -exec false {} +; then
        __rspamd__log 'warn' "Rspamd DKIM private key file '${KEY_FILE}' does not appear to have correct permissions/ownership for Rspamd to use it"
      else
        __rspamd__log 'trace' "DKIM file '${KEY_FILE}' permissions and ownership appear correct"
      fi
    else
      __rspamd__log 'warn' "Rspamd DKIM private key file '${KEY_FILE}' is configured for usage, but does not appear to exist"
    fi
  done < <(rspamadm configdump dkim_signing | grep 'path =' | grep -v -F '$' | awk '{print $3}' | tr -d ';"')
}
