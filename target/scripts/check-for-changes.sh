#! /bin/bash

# TODO: Adapt for compatibility with LDAP
# Only the cert renewal change detection may be relevant for LDAP?

# CHKSUM_FILE global is imported from this file:
# shellcheck source=./helpers/index.sh
source /usr/local/bin/helpers/index.sh

# This script requires some environment variables to be properly set. This
# includes POSTMASTER_ADDRESS (for alias (re-)generation), HOSTNAME and
# DOMAINNAME (in ssl.sh).
# shellcheck source=/dev/null
source /etc/dms-settings

_log_with_date 'debug' 'Starting changedetector'

# TODO in the future, when we do not use HOSTNAME but DMS_HOSTNAME everywhere,
# TODO we can delete this call as we needn't calculate the names twice
# ATTENTION: Do not remove!
#            This script requies HOSTNAME and DOMAINNAME
#            to be properly set.
_obtain_hostname_and_domainname

if ! cd /tmp/docker-mailserver &>/dev/null
then
  _exit_with_error "Could not change into '/tmp/docker-mailserver/' directory" 0
fi

# check postfix-accounts.cf exist else break
if [[ ! -f postfix-accounts.cf ]]
then
  _exit_with_error "'/tmp/docker-mailserver/postfix-accounts.cf' is missing" 0
fi

# verify checksum file exists; must be prepared by start-mailserver.sh
if [[ ! -f ${CHKSUM_FILE} ]]
then
  _exit_with_error "'/tmp/docker-mailserver/${CHKSUM_FILE}' is missing" 0
fi

REGEX_NEVER_MATCH="(?\!)"

_log_with_date 'trace' "Using postmaster address '${POSTMASTER_ADDRESS}'"

# Change detection delayed during startup to avoid conflicting writes
sleep 10

_log_with_date 'debug' "Chagedetector is ready"

function _check_for_changes
{
  # get chksum and check it, no need to lock config yet
  _monitored_files_checksums >"${CHKSUM_FILE}.new"
  cmp --silent -- "${CHKSUM_FILE}" "${CHKSUM_FILE}.new"

  # cmp return codes
  # 0 – files are identical
  # 1 – files differ
  # 2 – inaccessible or missing argument
  if [[ ${?} -eq 1 ]]
  then
    _log_with_date 'info' 'Change detected'
    _create_lock # Shared config safety lock
    local CHANGED
    CHANGED=$(grep -Fxvf "${CHKSUM_FILE}" "${CHKSUM_FILE}.new" | sed 's/^[^ ]\+  //')

    # TODO Perform updates below conditionally too
    # Also note that changes are performed in place and are not atomic
    # We should fix that and write to temporary files, stop, swap and start

    # _setup_ssl is required for:
    # manual - copy to internal DMS_TLS_PATH (/etc/dms/tls) that Postfix and Dovecot are configured to use.
    # acme.json - presently uses /etc/letsencrypt/live/<FQDN> instead of DMS_TLS_PATH,
    # path may change requiring Postfix/Dovecot config update.
    if [[ ${SSL_TYPE} == 'manual' ]]
    then
      # only run the SSL setup again if certificates have really changed.
      if [[ ${CHANGED} =~ ${SSL_CERT_PATH:-${REGEX_NEVER_MATCH}} ]]     \
      || [[ ${CHANGED} =~ ${SSL_KEY_PATH:-${REGEX_NEVER_MATCH}} ]]      \
      || [[ ${CHANGED} =~ ${SSL_ALT_CERT_PATH:-${REGEX_NEVER_MATCH}} ]] \
      || [[ ${CHANGED} =~ ${SSL_ALT_KEY_PATH:-${REGEX_NEVER_MATCH}} ]]
      then
        _log_with_date 'debug' 'Manual certificates have changed - extracting certificates'
        _setup_ssl
      fi
    # `acme.json` is only relevant to Traefik, and is where it stores the certificates it manages.
    # When a change is detected it's assumed to be a possible cert renewal that needs to be
    # extracted for `docker-mailserver` services to adjust to.
    elif [[ ${CHANGED} =~ /etc/letsencrypt/acme.json ]]
    then
      _log_with_date 'debug' "'/etc/letsencrypt/acme.json' has changed - extracting certificates"
      _setup_ssl

      # Prevent an unnecessary change detection from the newly extracted cert files by updating their hashes in advance:
      local CERT_DOMAIN
      CERT_DOMAIN=$(_find_letsencrypt_domain)
      ACME_CERT_DIR="/etc/letsencrypt/live/${CERT_DOMAIN}"

      sed -i "\|${ACME_CERT_DIR}|d" "${CHKSUM_FILE}.new"
      sha512sum "${ACME_CERT_DIR}"/*.pem >> "${CHKSUM_FILE}.new"
    fi

    # If monitored certificate files in /etc/letsencrypt/live have changed and no `acme.json` is in use,
    # They presently have no special handling other than to trigger a change that will restart Postfix/Dovecot.

    # regenerate postfix accounts
    [[ ${SMTP_ONLY} -ne 1 ]] && _create_accounts

    _rebuild_relayhost

    # regenerate postix aliases
    _create_aliases

    # regenerate /etc/postfix/vhost
    # NOTE: If later adding support for LDAP with change detection and this method is called,
    # be sure to mimic `setup-stack.sh:_setup_ldap` which appends to `/tmp/vhost.tmp`.
    _create_postfix_vhost

    if find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | read -r
    then
      chown -R 5000:5000 /var/mail
    fi

    _log_with_date 'debug' 'Restarting services due to detected changes'

    supervisorctl restart postfix

    # prevent restart of dovecot when smtp_only=1
    [[ ${SMTP_ONLY} -ne 1 ]] && supervisorctl restart dovecot

    _remove_lock
    _log_with_date 'debug' 'Completed handling of detected change'
  fi

  # mark changes as applied
  mv "${CHKSUM_FILE}.new" "${CHKSUM_FILE}"
}

while true
do
  _check_for_changes
  sleep 2
done

exit 0
