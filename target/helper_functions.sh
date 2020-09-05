#!/bin/bash

# version  0.1.1
#
# Provides varous helpers.


# ? IP and CIDR -------------------------------------------


function _mask_ip_digit()
{
  if [[ ${1} -ge 8 ]]
  then
    MASK=255
  elif [[ ${1} -le 0 ]]
  then
    MASK=0
  else
    VALUES=(0 128 192 224 240 248 252 254 255)
    MASK=${VALUES[$1]}
  fi

  local DVAL=${2}
  ((DVAL&=MASK))

  echo "$DVAL"
}

# Transforms a specific IP with CIDR suffix
# like 1.2.3.4/16 to subnet with cidr suffix
# like 1.2.0.0/16.
# Assumes correct IP and subnet are provided.
function _sanitize_ipv4_to_subnet_cidr()
{
  local DIGIT_PREFIX_LENGTH="${1#*/}"

  declare -a DIGITS
  IFS='.' ; read -r -a DIGITS < <(echo "${1%%/*}")
  unset IFS

  declare -a MASKED_DIGITS

  for ((i = 0 ; i < 4 ; i++))
  do
    MASKED_DIGITS[i]=$(_mask_ip_digit "$DIGIT_PREFIX_LENGTH" "${DIGITS[i]}")
    DIGIT_PREFIX_LENGTH=$((DIGIT_PREFIX_LENGTH - 8))
  done

  echo "${MASKED_DIGITS[0]}.${MASKED_DIGITS[1]}.${MASKED_DIGITS[2]}.${MASKED_DIGITS[3]}/${1#*/}"
}
export -f _sanitize_ipv4_to_subnet_cidr


# ? ACME certs --------------------------------------------


function _extract_certs_from_acme()
{
  local KEY
  # shellcheck disable=SC2002
  KEY=$(cat /etc/letsencrypt/acme.json | python -c "
import sys,json
acme = json.load(sys.stdin)
for key, value in acme.items():
    certs = value['Certificates']
    for cert in certs:
        if 'domain' in cert and 'key' in cert:
            if 'main' in cert['domain'] and cert['domain']['main'] == '$1' or 'sans' in cert['domain'] and '$1' in cert['domain']['sans']:
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
    for cert in certs:
        if 'domain' in cert and 'certificate' in cert:
            if 'main' in cert['domain'] and cert['domain']['main'] == '$1' or 'sans' in cert['domain'] and '$1' in cert['domain']['sans']:
                print cert['certificate']
                break
")

  if [[ -n "${KEY}${CERT}" ]]
  then
    mkdir -p "/etc/letsencrypt/live/${HOSTNAME}/"

    echo "$KEY" | base64 -d >/etc/letsencrypt/live/"$HOSTNAME"/key.pem || exit 1
    echo "$CERT" | base64 -d >/etc/letsencrypt/live/"$HOSTNAME"/fullchain.pem || exit 1
    echo "Cert found in /etc/letsencrypt/acme.json for $1"

    return 0
  else
    return 1
  fi
}
export -f _extract_certs_from_acme


# ? Notification ------------------------------------------


declare -A DEFAULT_VARS
DEFAULT_VARS["DMS_DEBUG"]="${DMS_DEBUG:="0"}"

function _notify()
{
  c_red="\e[0;31m"
  c_green="\e[0;32m"
  c_brown="\e[0;33m"
  c_blue="\e[0;34m"
  c_bold="\033[1m"
  c_reset="\e[0m"

  notification_type=$1
  notification_msg=$2
  notification_format=$3
  msg=""

  case "${notification_type}" in
    'taskgrp' ) msg="${c_bold}${notification_msg}${c_reset}" ;;
    'task'    )
      if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]
      then
        msg="  ${notification_msg}${c_reset}"
      fi
      ;;
    'inf'     )
      if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]
      then
        msg="${c_green}  * ${notification_msg}${c_reset}"
      fi
      ;;
    'started' ) msg="${c_green} ${notification_msg}${c_reset}" ;;
    'warn'    ) msg="${c_brown} Warning ${notification_msg}${c_reset}" ;;
    'err'     ) msg="${c_blue} Error ${notification_msg}${c_reset}" ;;
    'fatal'   ) msg="${c_red} Fatal Error: ${notification_msg}${c_reset}" ;;
    *         ) msg="" ;;
  esac

  case "${notification_format}" in
    'n' ) options="-ne" ;;
    *   ) options="-e" ;;
  esac

  [[ -n "${msg}" ]] && echo $options "${msg}"
}
export -f _notify


# ? Relay Host Map ----------------------------------------


# setup /etc/postfix/relayhost_map
# --
# @domain1.com        [smtp.mailgun.org]:587
# @domain2.com        [smtp.mailgun.org]:587
# @domain3.com        [smtp.mailgun.org]:587
function _populate_relayhost_map()
{
  echo -n > /etc/postfix/relayhost_map
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
      echo "@${domain}    [$RELAY_HOST]:$RELAY_PORT" >> /etc/postfix/relayhost_map
    fi
  done
}
export -f _populate_relayhost_map


# ? File checksums ----------------------------------------


# file storing the checksums of the monitored files.
# shellcheck disable=SC2034
CHKSUM_FILE=/tmp/docker-mailserver-config-chksum

# Compute checksums of monitored files.
function _monitored_files_checksums()
{
  (
    cd /tmp/docker-mailserver || exit 1
    exec sha512sum 2>/dev/null -- \
      postfix-accounts.cf \
      postfix-virtual.cf \
      postfix-aliases.cf \
      dovecot-quotas.cf \
      /etc/letsencrypt/acme.json \
      "/etc/letsencrypt/live/$HOSTNAME/key.pem" \
      "/etc/letsencrypt/live/$HOSTNAME/fullchain.pem"
  )
}
export -f _monitored_files_checksums
