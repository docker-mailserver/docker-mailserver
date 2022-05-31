#! /bin/bash

# Returns a list of changed files, each line is a value pair of:
# <SHA-512 content hash> <changed file path>
# NOTE: check-for-changes.sh is the only consumer.
function _monitored_files_checksums
{
  local DMS_DIR=/tmp/docker-mailserver
  [[ -d ${DMS_DIR} ]] || return 1

  # If a wildcard path pattern (or an empty ENV) would yield an invalid path
  # or no results, `shopt -s nullglob` prevents it from being added.
  shopt -s nullglob
  declare -a STAGING_FILES CHANGED_FILES

  STAGING_FILES=(
    "${DMS_DIR}/postfix-accounts.cf"
    "${DMS_DIR}/postfix-virtual.cf"
    "${DMS_DIR}/postfix-aliases.cf"
    "${DMS_DIR}/dovecot-quotas.cf"
    "${DMS_DIR}/dovecot-masters.cf"
  )

  if [[ ${SSL_TYPE:-} == 'manual' ]]
  then
    # When using "manual" as the SSL type,
    # the following variables may contain the certificate files
    STAGING_FILES+=(
      "${SSL_CERT_PATH:-}"
      "${SSL_KEY_PATH:-}"
      "${SSL_ALT_CERT_PATH:-}"
      "${SSL_ALT_KEY_PATH:-}"
    )
  elif [[ ${SSL_TYPE:-} == 'letsencrypt' ]]
  then
    # React to any cert changes within the following LetsEncrypt locations:
    STAGING_FILES+=(
      /etc/letsencrypt/acme.json
      /etc/letsencrypt/live/"${SSL_DOMAIN}"/*.pem
      /etc/letsencrypt/live/"${HOSTNAME}"/*.pem
      /etc/letsencrypt/live/"${DOMAINNAME}"/*.pem
    )
  fi

  for FILE in "${STAGING_FILES[@]}"
  do
    [[ -f "${FILE}" ]] && CHANGED_FILES+=("${FILE}")
  done

  sha512sum -- "${CHANGED_FILES[@]}"
}
