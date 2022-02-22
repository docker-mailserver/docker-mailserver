#! /bin/bash

# shellcheck source=../helpers/index.sh
source /usr/local/bin/helpers/index.sh

function _generate_secret { ( umask 0077 ; dd if=/dev/urandom bs=24 count=1 2>/dev/null | base64 -w0 > "${1}" ; ) ; }

_obtain_hostname_and_domainname

if [[ -n "${SRS_DOMAINNAME}" ]]
then
  NEW_DOMAIN_NAME="${SRS_DOMAINNAME}"
else
  NEW_DOMAIN_NAME="${DOMAINNAME}"
fi

sed -i -e "s/localdomain/${NEW_DOMAIN_NAME}/g" /etc/default/postsrsd

POSTSRSD_SECRET_FILE='/etc/postsrsd.secret'
POSTSRSD_STATE_DIR='/var/mail-state/etc-postsrsd'
POSTSRSD_STATE_SECRET_FILE="${POSTSRSD_STATE_DIR}/postsrsd.secret"

if [[ -n ${SRS_SECRET} ]]
then
  ( umask 0077 ; echo "${SRS_SECRET}" | tr ',' '\n' > "${POSTSRSD_SECRET_FILE}" ; )
else
  if [[ ${ONE_DIR} -eq 1 ]]
  then
    if [[ ! -f ${POSTSRSD_STATE_SECRET_FILE} ]]
    then
      install -d -m 0775 "${POSTSRSD_STATE_DIR}"
      _generate_secret "${POSTSRSD_STATE_SECRET_FILE}"
    fi

    install -m 0400 "${POSTSRSD_STATE_SECRET_FILE}" "${POSTSRSD_SECRET_FILE}"
  elif [[ ! -f ${POSTSRSD_SECRET_FILE} ]]
  then
    _generate_secret "${POSTSRSD_SECRET_FILE}"
  fi
fi

if [[ -n ${SRS_EXCLUDE_DOMAINS} ]]
then
  sed -i -e "s/^#\?SRS_EXCLUDE_DOMAINS=.*$/SRS_EXCLUDE_DOMAINS=${SRS_EXCLUDE_DOMAINS}/g" /etc/default/postsrsd
fi

/etc/init.d/postsrsd start
