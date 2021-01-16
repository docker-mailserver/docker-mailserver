#! /bin/bash

DMS_DEBUG="${DMS_DEBUG:=0}"

# ? ––––––––––––––––––––––––––––––––––––––––––––– BIN HELPER

function errex
{
  echo "${@}" 1>&2
  exit 1
}

function escape
{
  echo "${1//./\\.}"
}

# ? ––––––––––––––––––––––––––––––––––––––––––––– IP & CIDR

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

# ? ––––––––––––––––––––––––––––––––––––––––––––– ACME

function _extract_certs_from_acme
{
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
                if 'main' in cert['domain'] and cert['domain']['main'] == '${1}' or 'sans' in cert['domain'] and '${1}' in cert['domain']['sans']:
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
                if 'main' in cert['domain'] and cert['domain']['main'] == '${1}' or 'sans' in cert['domain'] and '${1}' in cert['domain']['sans']:
                    print cert['certificate']
                    break
")

  if [[ -n "${KEY}${CERT}" ]]
  then
    mkdir -p "/etc/letsencrypt/live/${HOSTNAME}/"

    echo "${KEY}" | base64 -d >/etc/letsencrypt/live/"${HOSTNAME}"/key.pem || exit 1
    echo "${CERT}" | base64 -d >/etc/letsencrypt/live/"${HOSTNAME}"/fullchain.pem || exit 1
    echo "Cert found in /etc/letsencrypt/acme.json for ${1}"

    return 0
  else
    return 1
  fi
}
export -f _extract_certs_from_acme

# ? ––––––––––––––––––––––––––––––––––––––––––––– Notifications

function _notify
{
  local FINAL_MSG=''
  local MSG="${2:-}"
  local TYPE="${1:-}"

  case "${TYPE}" in
    'none'    ) FINAL_MSG=' ' ;;
    'tasklog' ) FINAL_MSG="[ \e[0;92mTASKLOG\e[0m ]  ${MSG}" ;; # light green
    'warn'    ) FINAL_MSG="[ \e[0;93mWARNING\e[0m ]  ${MSG}" ;; # light yellow
    'err'     ) FINAL_MSG="[  \e[0;31mERROR\e[0m  ]  ${MSG}" ;; # light red
    'fatal'   ) FINAL_MSG="[  \e[0;91mFATAL\e[0m  ]  ${MSG}" ;; # red
    'inf'     ) [[ ${DMS_DEBUG} -eq 1 ]] && FINAL_MSG="[[ \e[0;34mINFO\e[0m ]]   ${MSG}" ;; # light blue
    'task'    ) [[ ${DMS_DEBUG} -eq 1 ]] && FINAL_MSG="[[ \e[0;37mTASK\e[0m ]]   ${MSG}" ;; # light grey
    *         ) ;;
  esac

  [[ -n ${FINAL_MSG} ]] && echo "-e${3:-}" "${FINAL_MSG}"
}
export -f _notify

# ? ––––––––––––––––––––––––––––––––––––––––––––– Relay Host Map

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
  } | while read -r domain
  do
    # domain not already present *and* not ignored
    if ! grep -q -e "^@${domain}\b" /etc/postfix/relayhost_map && ! grep -qs -e "^\s*@${domain}\s*$" /tmp/docker-mailserver/postfix-relaymap.cf
    then
      _notify 'inf' "Adding relay mapping for ${domain}"
      echo "@${domain}    [${RELAY_HOST}]:${RELAY_PORT}" >> /etc/postfix/relayhost_map
    fi
  done
}
export -f _populate_relayhost_map

# ? ––––––––––––––––––––––––––––––––––––––––––––– File Checksums

# file storing the checksums of the monitored files.
# shellcheck disable=SC2034
CHKSUM_FILE=/tmp/docker-mailserver-config-chksum

# Compute checksums of monitored files.
function _monitored_files_checksums
{
  (
    cd /tmp/docker-mailserver || exit 1
    exec sha512sum 2>/dev/null -- \
      postfix-accounts.cf \
      postfix-virtual.cf \
      postfix-aliases.cf \
      dovecot-quotas.cf \
      /etc/letsencrypt/acme.json \
      "/etc/letsencrypt/live/${HOSTNAME}/key.pem" \
      "/etc/letsencrypt/live/${HOSTNAME}/privkey.pem" \
      "/etc/letsencrypt/live/${HOSTNAME}/fullchain.pem"
  )
}
export -f _monitored_files_checksums
