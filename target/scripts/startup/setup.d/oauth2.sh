#!/bin/bash

function _setup_oauth2() {
  _log 'debug' 'Setting up OAUTH2'

  # Enable OAuth2 PassDB (Authentication):
  cp /etc/dovecot/features/auth-oauth2.conf /etc/dovecot/features.d/auth-oauth2.conf
  sedfile -i -E \
    "s|( *introspection_url =)|\1 ${OAUTH2_INTROSPECTION_URL}|" \
    /etc/dovecot/features.d/auth-oauth2.conf

  return 0
}
