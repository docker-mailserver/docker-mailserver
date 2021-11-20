#! /bin/bash
# Support for SASL

function _sasl_passwd_create
{
  if [[ -n ${SASL_PASSWD} ]]
  then
    # create SASL password
    echo "${SASL_PASSWD}" > /etc/postfix/sasl_passwd
    _sasl_set_passwd_permissions
  else
    rm -f /etc/postfix/sasl_passwd
  fi
}

function _sasl_set_passwd_permissions
{
  if [[ -f /etc/postfix/sasl_passwd ]]
  then
    chown root:root /etc/postfix/sasl_passwd
    chmod 0600 /etc/postfix/sasl_passwd
  fi
}
