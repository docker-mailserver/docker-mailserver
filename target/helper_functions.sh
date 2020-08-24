#!/bin/bash

# expects mask prefix length and the digit
function _mask_ip_digit() {
  if [[ $1 -ge 8 ]]; then
    MASK=255
  else
    if [[ $1 -le 0 ]]; then
      MASK=0
    else
      VALUES=('0' '128' '192' '224' '240' '248' '252' '254' '255')
      MASK=${VALUES[$1]}
    fi
  fi
  echo $(($2 & $MASK))
}

# transforms a specific ip with CIDR suffix like 1.2.3.4/16
# to subnet with cidr suffix like 1.2.0.0/16
function _sanitize_ipv4_to_subnet_cidr() {
  IP=${1%%/*}
  PREFIX_LENGTH=${1#*/}

  # split IP by . into digits
  DIGITS=(${IP//./ })

  # mask digits according to prefix length
  MASKED_DIGITS=()
  DIGIT_PREFIX_LENGTH="$PREFIX_LENGTH"
  for DIGIT in "${DIGITS[@]}"; do
    MASKED_DIGITS+=($(_mask_ip_digit $DIGIT_PREFIX_LENGTH $DIGIT))
    DIGIT_PREFIX_LENGTH=$(($DIGIT_PREFIX_LENGTH - 8))
  done

  # output masked ip plus prefix length
  echo ${MASKED_DIGITS[0]}.${MASKED_DIGITS[1]}.${MASKED_DIGITS[2]}.${MASKED_DIGITS[3]}/$PREFIX_LENGTH
}

# extracts certificates from acme.json and returns 0 if found
function extractCertsFromAcmeJson() {
  WHAT=$1

  KEY=$(cat /etc/letsencrypt/acme.json | python -c "
import sys,json
acme = json.load(sys.stdin)
for key, value in acme.items():
    certs = value['Certificates']
    for cert in certs:
        if 'domain' in cert and 'key' in cert:
            if 'main' in cert['domain'] and cert['domain']['main'] == '$WHAT' or 'sans' in cert['domain'] and '$WHAT' in cert['domain']['sans']:
                print cert['key']
                break
")
  CERT=$(cat /etc/letsencrypt/acme.json | python -c "
import sys,json
acme = json.load(sys.stdin)
for key, value in acme.items():
    certs = value['Certificates']
    for cert in certs:
        if 'domain' in cert and 'certificate' in cert:
            if 'main' in cert['domain'] and cert['domain']['main'] == '$WHAT' or 'sans' in cert['domain'] and '$WHAT' in cert['domain']['sans']:
                print cert['certificate']
                break
")

  if [[ -n "${KEY}${CERT}" ]]; then
    mkdir -p /etc/letsencrypt/live/"$HOSTNAME"/
    echo $KEY | base64 -d >/etc/letsencrypt/live/"$HOSTNAME"/key.pem || exit 1
    echo $CERT | base64 -d >/etc/letsencrypt/live/"$HOSTNAME"/fullchain.pem || exit 1
    echo "Cert found in /etc/letsencrypt/acme.json for $WHAT"
    return 0
  else
    return 1
  fi
}

declare -A DEFAULT_VARS
DEFAULT_VARS["DMS_DEBUG"]="${DMS_DEBUG:="0"}"

function notify () {
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
    'taskgrp')
      msg="${c_bold}${notification_msg}${c_reset}"
      ;;
    'task')
      if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
        msg="  ${notification_msg}${c_reset}"
      fi
      ;;
    'inf')
      if [[ ${DEFAULT_VARS["DMS_DEBUG"]} == 1 ]]; then
        msg="${c_green}  * ${notification_msg}${c_reset}"
      fi
      ;;
    'started')
      msg="${c_green} ${notification_msg}${c_reset}"
      ;;
    'warn')
      msg="${c_brown}  * ${notification_msg}${c_reset}"
      ;;
    'err')
      msg="${c_red}  * ${notification_msg}${c_reset}"
      ;;
    'fatal')
      msg="${c_red}Error: ${notification_msg}${c_reset}"
      ;;
    *)
      msg=""
      ;;
  esac

  case "${notification_format}" in
    'n')
      options="-ne"
      ;;
    *)
      options="-e"
      ;;
  esac

  [[ ! -z "${msg}" ]] && echo $options "${msg}"
}

# setup /etc/postfix/relayhost_map
# --
# @domain1.com        [smtp.mailgun.org]:587
# @domain2.com        [smtp.mailgun.org]:587
# @domain3.com        [smtp.mailgun.org]:587
function populate_relayhost_map() {
  echo -n > /etc/postfix/relayhost_map
  chown root:root /etc/postfix/relayhost_map
  chmod 0600 /etc/postfix/relayhost_map

  if [ -f /tmp/docker-mailserver/postfix-relaymap.cf ]; then
    notify 'inf' "Adding relay mappings from postfix-relaymap.cf"
    # Keep lines which are not a comment *and* have a destination.
    sed -n '/^\s*[^#[:space:]]\S*\s\+\S/p' /tmp/docker-mailserver/postfix-relaymap.cf \
        >> /etc/postfix/relayhost_map
  fi
  {
    # Note: Won't detect domains when lhs has spaces (but who does that?!).
    sed -n '/^\s*[^#[:space:]]/ s/^[^@|]*@\([^|]\+\)|.*$/\1/p' /tmp/docker-mailserver/postfix-accounts.cf
    [ -f /tmp/docker-mailserver/postfix-virtual.cf ] &&
      sed -n '/^\s*[^#[:space:]]/ s/^\s*[^@[:space:]]*@\(\S\+\)\s.*/\1/p' /tmp/docker-mailserver/postfix-virtual.cf
  } | while read domain; do
    if ! grep -q -e "^@${domain}\b" /etc/postfix/relayhost_map &&
       ! grep -qs -e "^\s*@${domain}\s*$" /tmp/docker-mailserver/postfix-relaymap.cf; then
      # Domain not already present *and* not ignored.
      notify 'inf' "Adding relay mapping for ${domain}"
      echo "@${domain}    [$RELAY_HOST]:$RELAY_PORT" >> /etc/postfix/relayhost_map
    fi
  done
}

# File storing the checksums of the monitored files.
CHKSUM_FILE=/tmp/docker-mailserver-config-chksum

# Compute checksums of monitored files.
function monitored_files_checksums() {
  (
    cd /tmp/docker-mailserver
    # (2>/dev/null to ignore warnings about files that don't exist)
    exec sha512sum 2>/dev/null -- \
           postfix-accounts.cf \
           postfix-virtual.cf \
           postfix-aliases.cf \
           dovecot-quotas.cf \
           /etc/letsencrypt/acme.json \
           "/etc/letsencrypt/live/$HOSTNAME/key.pem" \
           "/etc/letsencrypt/live/$HOSTNAME/fullchain.pem"
  )
  return 0
}
