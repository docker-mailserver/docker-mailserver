#! /bin/bash

DMS_DEBUG="${DMS_DEBUG:=0}"
SCRIPT_NAME="$(basename "$0")" # This becomes the sourcing script name (Example: check-for-changes.sh)
LOCK_ID="$(uuid)" # Used inside of lock files to identify them and prevent removal by other instances of docker-mailserver

# ? --------------------------------------------- BIN HELPER

function errex
{
  echo -e "Error :: ${*}\nAborting." >&2
  exit 1
}

# `dms_panic` methods are appropriate when the type of error is a not recoverable,
# or needs to be very clear to the user about misconfiguration.
#
# Method is called with args:
# PANIC_TYPE => (Internal value for matching). You should use the convenience methods below based on your panic type.
# PANIC_INFO => Provide your own message string to insert into the error message for that PANIC_TYPE.
# PANIC_SCOPE => Optionally provide a string for debugging to better identify/locate the source of the panic.
function dms_panic
{
  local PANIC_TYPE=${1}
  local PANIC_INFO=${2}
  local PANIC_SCOPE=${3} #optional

  local SHUTDOWN_MESSAGE

  case "${PANIC_TYPE}" in
    ( 'fail-init' ) # PANIC_INFO == <name of service or process that failed to start / initialize>
      SHUTDOWN_MESSAGE="Failed to start ${PANIC_INFO}!"
    ;;

    ( 'no-env' ) # PANIC_INFO == <ENV VAR name>
      SHUTDOWN_MESSAGE="Environment Variable: ${PANIC_INFO} is not set!"
    ;;

    ( 'no-file' ) # PANIC_INFO == <invalid filepath>
      SHUTDOWN_MESSAGE="File ${PANIC_INFO} does not exist!"
    ;;

    ( 'misconfigured' ) # PANIC_INFO == <something possibly misconfigured, eg an ENV var>
      SHUTDOWN_MESSAGE="${PANIC_INFO} appears to be misconfigured, please verify."
    ;;

    ( 'invalid-value' ) # PANIC_INFO == <an unsupported or invalid value, eg in a case match>
      SHUTDOWN_MESSAGE="Invalid value for ${PANIC_INFO}!"
    ;;

    ( * ) # `dms_panic` was called directly without a valid PANIC_TYPE
      SHUTDOWN_MESSAGE='Something broke :('
    ;;
  esac

  if [[ -n ${PANIC_SCOPE} ]]
  then
    _shutdown "${PANIC_SCOPE} | ${SHUTDOWN_MESSAGE}"
  else
    _shutdown "${SHUTDOWN_MESSAGE}"
  fi
}

# Convenience wrappers based on type:
function dms_panic__fail_init { dms_panic 'fail-init' "${1}" "${2}"; }
function dms_panic__no_env { dms_panic 'no-env' "${1}" "${2}"; }
function dms_panic__no_file { dms_panic 'no-file' "${1}" "${2}"; }
function dms_panic__misconfigured { dms_panic 'misconfigured' "${1}" "${2}"; }
function dms_panic__invalid_value { dms_panic 'invalid-value' "${1}" "${2}"; }

function escape
{
  echo "${1//./\\.}"
}

function create_lock
{
  LOCK_FILE="/tmp/docker-mailserver/${SCRIPT_NAME}.lock"
  while [[ -e "${LOCK_FILE}" ]]
  do
    _notify 'warn' "Lock file ${LOCK_FILE} exists. Another ${SCRIPT_NAME} execution is happening. Trying again shortly..."
    # Handle stale lock files left behind on crashes
    # or premature/non-graceful exits of containers while they're making changes
    if [[ -n "$(find "${LOCK_FILE}" -mmin +1 2>/dev/null)" ]]
    then
      _notify 'warn' "Lock file older than 1 minute. Removing stale lock file."
      rm -f "${LOCK_FILE}"
      _notify 'inf' "Removed stale lock ${LOCK_FILE}."
    fi
    sleep 5
  done
  trap remove_lock EXIT
  echo "${LOCK_ID}" > "${LOCK_FILE}"
}

function remove_lock
{
  LOCK_FILE="${LOCK_FILE:-"/tmp/docker-mailserver/${SCRIPT_NAME}.lock"}"
  [[ -z "${LOCK_ID}" ]] && errex "Cannot remove ${LOCK_FILE} as there is no LOCK_ID set"
  if [[ -e "${LOCK_FILE}" ]] && grep -q "${LOCK_ID}" "${LOCK_FILE}" # Ensure we don't delete a lock that's not ours
  then
    rm -f "${LOCK_FILE}"
    _notify 'inf' "Removed lock ${LOCK_FILE}."
  fi
}

# ? --------------------------------------------- IP & CIDR

function _mask_ip_digit
{
  if [[ ${1} -ge 8 ]]
  then
    MASK=255
  elif [[ ${1} -le 0 ]]
  then
    MASK=0
  else
    VALUES=(0 128 192 224 240 248 252 254 255)
    MASK=${VALUES[${1}]}
  fi

  local DVAL=${2}
  ((DVAL&=MASK))

  echo "${DVAL}"
}

# Transforms a specific IP with CIDR suffix
# like 1.2.3.4/16 to subnet with cidr suffix
# like 1.2.0.0/16.
# Assumes correct IP and subnet are provided.
function _sanitize_ipv4_to_subnet_cidr
{
  local DIGIT_PREFIX_LENGTH="${1#*/}"

  declare -a MASKED_DIGITS DIGITS
  IFS='.' ; read -r -a DIGITS < <(echo "${1%%/*}") ; unset IFS

  for ((i = 0 ; i < 4 ; i++))
  do
    MASKED_DIGITS[i]=$(_mask_ip_digit "${DIGIT_PREFIX_LENGTH}" "${DIGITS[i]}")
    DIGIT_PREFIX_LENGTH=$((DIGIT_PREFIX_LENGTH - 8))
  done

  echo "${MASKED_DIGITS[0]}.${MASKED_DIGITS[1]}.${MASKED_DIGITS[2]}.${MASKED_DIGITS[3]}/${1#*/}"
}
export -f _sanitize_ipv4_to_subnet_cidr

# ? --------------------------------------------- ACME

function _extract_certs_from_acme
{
  local CERT_DOMAIN=${1}
  if [[ -z "${CERT_DOMAIN}" ]]
  then
    _notify 'err' "_extract_certs_from_acme | CERT_DOMAIN is empty"
    return 1
  fi

  local KEY
  # shellcheck disable=SC2002
  KEY=$(cat /etc/letsencrypt/acme.json | python -c "
import sys,json
acme = json.load(sys.stdin)
for key, value in acme.items():
    certs = value['Certificates']
    if certs is not None:
        for cert in certs:
            if 'domain' in cert and 'key' in cert:
                if 'main' in cert['domain'] and cert['domain']['main'] == '${CERT_DOMAIN}' or 'sans' in cert['domain'] and '${CERT_DOMAIN}' in cert['domain']['sans']:
                    print cert['key']
                    break
")
  local CERT
  # shellcheck disable=SC2002
  CERT=$(cat /etc/letsencrypt/acme.json | python -c "
import sys,json
acme = json.load(sys.stdin)
for key, value in acme.items():
    certs = value['Certificates']
    if certs is not None:
        for cert in certs:
            if 'domain' in cert and 'certificate' in cert:
                if 'main' in cert['domain'] and cert['domain']['main'] == '${CERT_DOMAIN}' or 'sans' in cert['domain'] and '${CERT_DOMAIN}' in cert['domain']['sans']:
                    print cert['certificate']
                    break
")

  # Fail if KEY or CERT are empty:
  if [[ -z "${KEY}" ]]
  then
    _notify 'warn' "_extract_certs_from_acme | Unable to find key for '${CERT_DOMAIN}' in '/etc/letsencrypt/acme.json'"
    return 1
  fi
  if [[ -z "${CERT}" ]]
  then
    _notify 'warn' "_extract_certs_from_acme | Unable to find cert for '${CERT_DOMAIN}' in '/etc/letsencrypt/acme.json'"
    return 1
  fi

  if [[ ${SSL_DOMAIN} == "${CERT_DOMAIN}" ]]
  then
    CERT_DOMAIN=$(_strip_wildcard_prefix "${SSL_DOMAIN}")
  fi
  mkdir -p "/etc/letsencrypt/live/${CERT_DOMAIN}/"
  echo "${KEY}" | base64 -d > "/etc/letsencrypt/live/${CERT_DOMAIN}/key.pem" || exit 1
  echo "${CERT}" | base64 -d > "/etc/letsencrypt/live/${CERT_DOMAIN}/fullchain.pem" || exit 1

  _notify 'inf' "_extract_certs_from_acme | Certificate successfully extracted for '${CERT_DOMAIN}'"
}
export -f _extract_certs_from_acme

# Remove the `*.` prefix if it exists
function _strip_wildcard_prefix {
  local FQDN=${1}
    if [[ ${FQDN} =~ \*\. ]]
    then
      FQDN=$(echo "${1}" | cut -d '.' -f2-99)
    fi
  echo "${FQDN}"
}

# ? --------------------------------------------- Notifications

function _notify
{
  { [[ -z ${1:-} ]] || [[ -z ${2:-} ]] ; } && return 0

  local RESET LGREEN LYELLOW LRED RED LBLUE LGREY LMAGENTA

  RESET='\e[0m' ; LGREEN='\e[92m' ; LYELLOW='\e[93m'
  LRED='\e[31m' ; RED='\e[91m' ; LBLUE='\e[34m'
  LGREY='\e[37m' ; LMAGENTA='\e[95m'

  case "${1}" in
    'tasklog'  ) echo "-e${3:-}" "[ ${LGREEN}TASKLOG${RESET} ]  ${2}"  ;;
    'warn'     ) echo "-e${3:-}" "[ ${LYELLOW}WARNING${RESET} ]  ${2}" ;;
    'err'      ) echo "-e${3:-}" "[  ${LRED}ERROR${RESET}  ]  ${2}"    ;;
    'fatal'    ) echo "-e${3:-}" "[  ${RED}FATAL${RESET}  ]  ${2}"     ;;
    'inf'      ) [[ ${DMS_DEBUG} -eq 1 ]] && echo "-e${3:-}" "[[  ${LBLUE}INF${RESET}  ]]  ${2}" ;;
    'task'     ) [[ ${DMS_DEBUG} -eq 1 ]] && echo "-e${3:-}" "[[ ${LGREY}TASKS${RESET} ]]  ${2}" ;;
    *          ) echo "-e${3:-}" "[  ${LMAGENTA}UNKNOWN${RESET}  ]  ${2}" ;;
  esac

  return 0
}
export -f _notify

# ? --------------------------------------------- Relay Host Map

# setup /etc/postfix/relayhost_map
# --
# @domain1.com        [smtp.mailgun.org]:587
# @domain2.com        [smtp.mailgun.org]:587
# @domain3.com        [smtp.mailgun.org]:587
function _populate_relayhost_map
{
  : >/etc/postfix/relayhost_map
  chown root:root /etc/postfix/relayhost_map
  chmod 0600 /etc/postfix/relayhost_map

  if [[ -f /tmp/docker-mailserver/postfix-relaymap.cf ]]
  then
    _notify 'inf' "Adding relay mappings from postfix-relaymap.cf"
    # keep lines which are not a comment *and* have a destination.
    sed -n '/^\s*[^#[:space:]]\S*\s\+\S/p' /tmp/docker-mailserver/postfix-relaymap.cf >> /etc/postfix/relayhost_map
  fi

  {
    # note: won't detect domains when lhs has spaces (but who does that?!)
    sed -n '/^\s*[^#[:space:]]/ s/^[^@|]*@\([^|]\+\)|.*$/\1/p' /tmp/docker-mailserver/postfix-accounts.cf

    [ -f /tmp/docker-mailserver/postfix-virtual.cf ] && sed -n '/^\s*[^#[:space:]]/ s/^\s*[^@[:space:]]*@\(\S\+\)\s.*/\1/p' /tmp/docker-mailserver/postfix-virtual.cf
  } | while read -r DOMAIN
  do
    # DOMAIN not already present *and* not ignored
    if ! grep -q -e "^@${DOMAIN}\b" /etc/postfix/relayhost_map && ! grep -qs -e "^\s*@${DOMAIN}\s*$" /tmp/docker-mailserver/postfix-relaymap.cf
    then
      _notify 'inf' "Adding relay mapping for ${DOMAIN}"
      # shellcheck disable=SC2153
      echo "@${DOMAIN}    [${RELAY_HOST}]:${RELAY_PORT}" >> /etc/postfix/relayhost_map
    fi
  done
}
export -f _populate_relayhost_map

# ? --------------------------------------------- File Checksums

# file storing the checksums of the monitored files.
# shellcheck disable=SC2034
CHKSUM_FILE=/tmp/docker-mailserver-config-chksum

# Compute checksums of monitored files.
function _monitored_files_checksums
{
  # If there is no /etc/letsencrypt/live/*, cmp throws:
  # "cmp: EOF on /tmp/docker-mailserver-config-chksum.new after byte 596, line 4"
  shopt -s nullglob
  DYNAMIC_FILES=
  for FILE in /etc/letsencrypt/live/"${SSL_DOMAIN}"/*.pem /etc/letsencrypt/live/"${HOSTNAME}"/*.pem /etc/letsencrypt/live/"${DMS_HOSTNAME_DOMAIN}"/*.pem
  do
    DYNAMIC_FILES="${DYNAMIC_FILES} ${FILE}"
  done
  (
    cd /tmp/docker-mailserver || exit 1
    exec sha512sum 2>/dev/null -- \
      postfix-accounts.cf \
      postfix-virtual.cf \
      postfix-aliases.cf \
      dovecot-quotas.cf \
      /etc/letsencrypt/acme.json \
      "${DYNAMIC_FILES}"
  )
}
export -f _monitored_files_checksums

# ? --------------------------------------------- General

# Outputs the DNS label count (delimited by `.`) for the given input string.
# Useful for determining an FQDN like `mail.example.com` (3), vs `example.com` (2).
function _get_label_length
{
  local INPUT=${1}
  awk -F '.' '{ print NF }' <<< "${INPUT}"
}

function _obtain_hostname_and_domainname
{
  # This is where we modify it for all our scripts and subprocesses called that intereact with it.
  # Normally this value would match the output of `hostname` that mirrors `/proc/sys/kernel/hostname`,
  # However for legacy reasons, the system ENV `HOSTNAME` was overrided here with `hostname -f` instead.
  #
  # TODO: Consider changing to `DMS_FQDN`, a more accurate name, and removing the `export`, assuming no
  # subprocess like postconf would be called that would access the hostname via `HOSTNAME`.
  # TODO: `OVERRIDE_HOSTNAME` was introduced for non-Docker runtimes that could not configure an explicit hostname.
  # k8s was the particular runtime in 2017. This does not update `/etc/hosts` or other locations, thus risking
  # inconsistency with expected behaviour. Investigate if it's safe to remove support.
  export HOSTNAME="${OVERRIDE_HOSTNAME:-"$(hostname -f)"}"

  # If misconfigured, `hostname -f` which derives it's value from `/etc/hosts` or DNS query,
  # will result in an error that returns an empty value. This warrants a panic.
  if [[ -z ${HOSTNAME} ]]
  then
    dms_panic__misconfigured 'obtain_hostname' '/etc/hosts'
  fi

  # If the `HOSTNAME` is more than 2 labels long (eg: mail.example.com),
  # We take the FQDN from it minus the 1st label (aka short hostname, `hostname -s`).
  #
  # TODO: For some reason we're explicitly separating out a domain name from our FQDN,
  # `hostname -d` was probably not the correct command for this intention either.
  # Needs further investigation for relevance, and if `/etc/hosts` is important for consumers
  # of this variable or if a more deterministic approach with `cut` should be relied on.
  if [[ $(_get_label_length "${HOSTNAME}") -gt 2 ]]
  then
    if [[ -n ${OVERRIDE_HOSTNAME} ]]
    then
      # Emulates the intended behaviour of `hostname -d`
      DMS_HOSTNAME_DOMAIN="$(echo "${HOSTNAME}" | cut -d '.' -f2-99)"
    else
      # Operates on FQDN returned from `/etc/hosts` or DNS query,
      # Note if you want the `domainname`, use a command of the same name,
      # Or cat /proc/sys/kernel/domainname
      # Our usage of `domainname` is under consideration as legacy, and
      # discouraged going forward. In future docs should drop any mention of it.

      #shellcheck disable=SC2034
      DMS_HOSTNAME_DOMAIN="$(hostname -d)"
    fi
  fi

  # Otherwise we assign the same value (eg: example.com).
  # Not an else condition, in the event that `hostname -d` fails.
  DMS_HOSTNAME_DOMAIN="${DMS_HOSTNAME_DOMAIN:-"${HOSTNAME}"}"
}

# Call this method when you want to panic (emit a 'FATAL' log level error, and exit uncleanly).
# `dms_panic` methods should be preferred if your failure type is supported.
function _shutdown
{
  local FATAL_ERROR_MESSAGE=$1

  _notify 'fatal' "${FATAL_ERROR_MESSAGE}"
  _notify 'err' "Shutting down.."
  kill 1
}
