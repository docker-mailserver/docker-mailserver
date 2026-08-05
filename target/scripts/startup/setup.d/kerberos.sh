#!/bin/bash

function _setup_kerberos() {
  _log 'debug' 'Setting up KERBEROS'

  # Enable Kerberos PassDB (Authentication):
  # required fields:
  #
  # auth_gssapi_hostname = mail01.example.com
  # auth_krb5_keytab = /etc/dovecot/krb5.keytab
  # auth_realms = example.com
  # auth_default_realm = example.com

  sedfile -i -e '/\!include auth-kerberos\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf
  _replace_by_env_in_file 'KERBEROS_' '/etc/dovecot/conf.d/auth-kerberos.inc'

  return 0
}
