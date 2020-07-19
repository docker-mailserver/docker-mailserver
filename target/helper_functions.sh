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
print ''
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
print ''
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
