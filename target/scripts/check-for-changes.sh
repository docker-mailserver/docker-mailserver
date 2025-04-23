#!/bin/bash

# TODO: Adapt for compatibility with LDAP
# Only the cert renewal change detection may be relevant for LDAP?

# CHKSUM_FILE global is imported from this file:
# shellcheck source=./helpers/index.sh
source /usr/local/bin/helpers/index.sh

_log 'debug' 'Starting changedetector'

# ATTENTION: Do not remove!
# This script requires some environment variables to be properly set.
# POSTMASTER_ADDRESS (for helpers/alias.sh) is read from /etc/dms-settings
# shellcheck source=/dev/null
source /etc/dms-settings

# HOSTNAME and DOMAINNAME are used by helpers/ssl.sh and _monitored_files_checksums
# These are not stored in /etc/dms-settings
# TODO: It is planned to stop overriding HOSTNAME and replace that
# usage with DMS_HOSTNAME, which should remove the need to call this:
_obtain_hostname_and_domainname

# This is a helper to properly set all Rspamd-related environment variables
# correctly and in one place.
_rspamd_get_envs

# verify checksum file exists; must be prepared by start-mailserver.sh
if [[ ! -f ${CHKSUM_FILE} ]]; then
  _exit_with_error "'${CHKSUM_FILE}' is missing" 0
fi

_log 'trace' "Using postmaster address '${POSTMASTER_ADDRESS}'"

_log 'debug' "Changedetector is ready"

function _check_for_changes() {
  # get chksum and check it, no need to lock config yet
  _monitored_files_checksums >"${CHKSUM_FILE}.new"
  cmp --silent -- "${CHKSUM_FILE}" "${CHKSUM_FILE}.new"

  # cmp return codes
  # 0 – files are identical
  # 1 – files differ
  # 2 – inaccessible or missing argument
  if [[ ${?} -eq 1 ]]; then
    _log 'info' 'Change detected'
    _create_lock # Shared config safety lock

    local CHANGED
    CHANGED=$(_get_changed_files "${CHKSUM_FILE}" "${CHKSUM_FILE}.new")
    _handle_changes

    _remove_lock
    _log 'debug' 'Completed handling of detected change'

    # mark changes as applied
    mv "${CHKSUM_FILE}.new" "${CHKSUM_FILE}"
  fi
}

function _handle_changes() {
  # Variable to identify any config updates dependent upon vhost changes.
  local VHOST_UPDATED=0
  # These two configs are the source for /etc/postfix/vhost (managed mail domains)
  if [[ ${CHANGED} =~ ${DMS_DIR}/postfix-(accounts|virtual).cf ]]; then
    _log 'trace' 'Regenerating vhosts (Postfix)'
    # Regenerate via `helpers/postfix.sh`:
    _create_postfix_vhost

    VHOST_UPDATED=1
  fi

  _ssl_changes
  _postfix_dovecot_changes
  _rspamd_changes

  _log 'debug' 'Reloading services due to detected changes'

  [[ ${ENABLE_AMAVIS} -eq 1 ]] && _reload_amavis
  _reload_postfix
  [[ ${SMTP_ONLY} -ne 1 ]] && dovecot reload
}

function _get_changed_files() {
  local CHKSUM_CURRENT=${1}
  local CHKSUM_NEW=${2}

  # Diff the two files for lines that don't match or differ from lines in CHKSUM_FILE
  # grep -Fxvf
  #   -f use CHKSUM_FILE lines as input patterns to match for
  #   -F The patterns to match are treated as strings only, not treated as regex syntax
  #   -x (match whole lines only)
  #   -v invert the matching so only non-matches are output
  # Extract file paths by truncating the matched content hash and white-space from lines:
  # sed -r 's/^\S+[[:space:]]+//'
  grep -Fxvf "${CHKSUM_CURRENT}" "${CHKSUM_NEW}" | sed -r 's/^\S+[[:space:]]+//'
}

function _reload_amavis() {
  # /etc/postfix/vhost was updated, amavis must refresh it's config by
  # reading this file again in case of new domains, otherwise they will be ignored.
  if [[ ${VHOST_UPDATED} -eq 1 ]]; then
    amavisd reload
  fi
}

# Also note that changes are performed in place and are not atomic
# We should fix that and write to temporary files, stop, swap and start
function _postfix_dovecot_changes() {
  local DMS_DIR=/tmp/docker-mailserver

  # Regenerate accounts via `helpers/accounts.sh`:
  # - dovecot-quotas.cf used by _create_accounts + _create_dovecot_alias_dummy_accounts
  # - postfix-virtual.cf used by _create_dovecot_alias_dummy_accounts (only when ENABLE_QUOTAS=1)
  if [[ ${CHANGED} =~ ${DMS_DIR}/postfix-accounts.cf ]] \
  || [[ ${CHANGED} =~ ${DMS_DIR}/postfix-virtual.cf  ]] \
  || [[ ${CHANGED} =~ ${DMS_DIR}/postfix-aliases.cf  ]] \
  || [[ ${CHANGED} =~ ${DMS_DIR}/dovecot-quotas.cf   ]] \
  || [[ ${CHANGED} =~ ${DMS_DIR}/dovecot-masters.cf  ]]
  then
    _log 'trace' 'Regenerating accounts (Dovecot + Postfix)'
    [[ ${SMTP_ONLY} -ne 1 ]] && _create_accounts
  fi

  # Regenerate relay config via `helpers/relay.sh`:
  # - postfix-sasl-password.cf used by _relayhost_sasl
  # - _populate_relayhost_map relies on:
  #   - postfix-relaymap.cf
  if [[ ${VHOST_UPDATED} -eq 1 ]] \
  || [[ ${CHANGED} =~ ${DMS_DIR}/postfix-relaymap.cf      ]] \
  || [[ ${CHANGED} =~ ${DMS_DIR}/postfix-sasl-password.cf ]]
  then
    _log 'trace' 'Regenerating relay config (Postfix)'
    _process_relayhost_configs
  fi

  # Regenerate system + virtual account aliases via `helpers/aliases.sh`:
  [[ ${CHANGED} =~ ${DMS_DIR}/postfix-virtual.cf ]] && _handle_postfix_virtual_config
  [[ ${CHANGED} =~ ${DMS_DIR}/postfix-regexp.cf  ]] && _handle_postfix_regexp_config
  [[ ${CHANGED} =~ ${DMS_DIR}/postfix-aliases.cf ]] && _handle_postfix_aliases_config

  # Legacy workaround handled here, only seems necessary for _create_accounts:
  # - `helpers/accounts.sh` logic creates folders/files with wrong ownership.
  _chown_var_mail_if_necessary
}

function _ssl_changes() {
  local REGEX_NEVER_MATCH='(?\!)'

  # _setup_ssl is required for:
  # manual - copy to internal DMS_TLS_PATH (/etc/dms/tls) that Postfix and Dovecot are configured to use.
  # acme.json - presently uses /etc/letsencrypt/live/<FQDN> instead of DMS_TLS_PATH,
  # path may change requiring Postfix/Dovecot config update.
  if [[ ${SSL_TYPE} == 'manual' ]]; then
    # only run the SSL setup again if certificates have really changed.
    if [[ ${CHANGED} =~ ${SSL_CERT_PATH:-${REGEX_NEVER_MATCH}} ]]     \
    || [[ ${CHANGED} =~ ${SSL_KEY_PATH:-${REGEX_NEVER_MATCH}} ]]      \
    || [[ ${CHANGED} =~ ${SSL_ALT_CERT_PATH:-${REGEX_NEVER_MATCH}} ]] \
    || [[ ${CHANGED} =~ ${SSL_ALT_KEY_PATH:-${REGEX_NEVER_MATCH}} ]]
    then
      _log 'debug' 'Manual certificates have changed - extracting certificates'
      _setup_ssl
    fi
  # `acme.json` is only relevant to Traefik, and is where it stores the certificates it manages.
  # When a change is detected it's assumed to be a possible cert renewal that needs to be
  # extracted for `docker-mailserver` services to adjust to.
  elif [[ ${CHANGED} =~ /etc/letsencrypt/acme.json ]]; then
    _log 'debug' "'/etc/letsencrypt/acme.json' has changed - extracting certificates"
    _setup_ssl

    # Prevent an unnecessary change detection from the newly extracted cert files by updating their hashes in advance:
    local CERT_DOMAIN ACME_CERT_DIR
    CERT_DOMAIN=$(_find_letsencrypt_domain)
    ACME_CERT_DIR="/etc/letsencrypt/live/${CERT_DOMAIN}"

    sed -i "\|${ACME_CERT_DIR}|d" "${CHKSUM_FILE}.new"
    sha512sum "${ACME_CERT_DIR}"/*.pem >> "${CHKSUM_FILE}.new"
  fi

  # If monitored certificate files in /etc/letsencrypt/live have changed and no `acme.json` is in use,
  # They presently have no special handling other than to trigger a change that will restart Postfix/Dovecot.
}

function _rspamd_changes() {
  # RSPAMD_DMS_D='/tmp/docker-mailserver/rspamd'
  if [[ ${CHANGED} =~ ${RSPAMD_DMS_D}/.* ]]; then

    # "${RSPAMD_DMS_D}/override.d"
    if [[ ${CHANGED} =~ ${RSPAMD_DMS_OVERRIDE_D}/.* ]]; then
      _log 'trace' 'Rspamd - Copying configuration overrides'
      rm "${RSPAMD_OVERRIDE_D}"/*
      cp "${RSPAMD_DMS_OVERRIDE_D}"/* "${RSPAMD_OVERRIDE_D}"
    fi

    # "${RSPAMD_DMS_D}/custom-commands.conf"
    if [[ ${CHANGED} =~ ${RSPAMD_DMS_CUSTOM_COMMANDS_F} ]]; then
      _log 'trace' 'Rspamd - Generating new configuration from custom commands'
      _rspamd_handle_user_modules_adjustments
    fi

    # "${RSPAMD_DMS_D}/dkim"
    if [[ ${CHANGED} =~ ${RSPAMD_DMS_DKIM_D} ]]; then
      _log 'trace' 'Rspamd - DKIM files updated'
    fi

    _log 'debug' 'Rspamd configuration has changed - restarting service'
    supervisorctl restart rspamd
  fi
}

while true; do
  _check_for_changes
  sleep "${DMS_CONFIG_POLL:-2}"
done

exit 0
