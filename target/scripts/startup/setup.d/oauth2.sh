#!/bin/bash

function _setup_oauth2() {
  _log 'debug' 'Setting up OAUTH2'

  # Enable OAuth2 PassDB (Authentication):
  sedfile -i -e '/\!include auth-oauth2\.conf\.ext/s/^#//' /etc/dovecot/conf.d/10-auth.conf
  sedfile -i -E \
    "s|( *introspection_url =)|\1 ${OAUTH2_INTROSPECTION_URL}|" \
    /etc/dovecot/conf.d/auth-oauth2.conf.ext

  return 0
}
