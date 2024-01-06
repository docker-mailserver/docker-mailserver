#!/bin/bash

function _setup_oauth2() {
  _log 'debug' 'Setting up OAUTH2'

  # Enable OAuth2 PassDB (Authentication):
  sedfile -i -e '/\!include auth-oauth2\.conf\.ext/s/^#//' /etc/dovecot/conf.d/10-auth.conf
  _replace_by_env_in_file 'OAUTH2_' '/etc/dovecot/dovecot-oauth2.conf.ext'

  return 0
}
