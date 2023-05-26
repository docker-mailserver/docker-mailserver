#!/bin/bash

# This helper supports the changedetector service. Used by:
# - check-for-changes.sh
# - test/test_helper/common.bash:wait_for_changes_to_be_detected_in_container()
# - test/test_helper.bats
# - start-mailserver.sh --> setup-stack.sh:_setup (to initialize the CHKSUM_FILE state)

# Global checksum file used to track when monitored files have changed in content:
# shellcheck disable=SC2034
CHKSUM_FILE=/tmp/docker-mailserver-config-chksum

# Once container startup scripts complete, take a snapshot of
# the config state via storing a list of files content hashes.
function _prepare_for_change_detection() {
  _log 'debug' 'Setting up configuration checksum file'

  _log 'trace' "Creating '${CHKSUM_FILE}'"
  _monitored_files_checksums >"${CHKSUM_FILE}"
}

# Returns a list of changed files, each line is a value pair of:
# <SHA-512 content hash> <changed file path>
function _monitored_files_checksums() {
  # If a wildcard path pattern (or an empty ENV) would yield an invalid path
  # or no results, `shopt -s nullglob` prevents it from being added.
  shopt -s nullglob
  declare -a STAGING_FILES CHANGED_FILES

  # Supported user provided configs:
  local DMS_DIR=/tmp/docker-mailserver
  if [[ -d ${DMS_DIR} ]]; then
    STAGING_FILES+=(
      "${DMS_DIR}/postfix-accounts.cf"
      "${DMS_DIR}/postfix-virtual.cf"
      "${DMS_DIR}/postfix-regexp.cf"
      "${DMS_DIR}/postfix-aliases.cf"
      "${DMS_DIR}/postfix-relaymap.cf"
      "${DMS_DIR}/postfix-sasl-password.cf"
      "${DMS_DIR}/dovecot-quotas.cf"
      "${DMS_DIR}/dovecot-masters.cf"
    )
  fi

  # SSL certs:
  if [[ ${SSL_TYPE:-} == 'manual' ]]; then
    # When using "manual" as the SSL type,
    # the following variables may contain the certificate files
    STAGING_FILES+=(
      "${SSL_CERT_PATH:-}"
      "${SSL_KEY_PATH:-}"
      "${SSL_ALT_CERT_PATH:-}"
      "${SSL_ALT_KEY_PATH:-}"
    )
  elif [[ ${SSL_TYPE:-} == 'letsencrypt' ]]; then
    # React to any cert changes within the following LetsEncrypt locations:
    STAGING_FILES+=(
      /etc/letsencrypt/acme.json
      /etc/letsencrypt/live/"${SSL_DOMAIN}"/*.pem
      /etc/letsencrypt/live/"${HOSTNAME}"/*.pem
      /etc/letsencrypt/live/"${DOMAINNAME}"/*.pem
    )
  fi

  # If the file actually exists, add to CHANGED_FILES
  # and generate a content hash entry:
  for FILE in "${STAGING_FILES[@]}"; do
    [[ -f "${FILE}" ]] && CHANGED_FILES+=("${FILE}")
  done

  if [[ -n ${CHANGED_FILES:-} ]]; then
    sha512sum -- "${CHANGED_FILES[@]}"
  fi
}
