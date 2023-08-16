#!/bin/bash
# Support for Postfix aliases

# NOTE: LDAP doesn't appear to use this, but the docs page: "Use Cases | Forward-Only Mail-Server with LDAP"
# does have an example where /etc/postfix/virtual is referenced in addition to ldap config for Postfix `main.cf:virtual_alias_maps`.
# `setup-stack.sh:_setup_ldap` does not seem to configure for `/etc/postfix/virtual however.`

# NOTE: `accounts.sh` and `relay.sh:_populate_relayhost_map` also process on `postfix-virtual.cf`.
function _handle_postfix_virtual_config() {
  : >/etc/postfix/virtual

  local DATABASE_VIRTUAL=/tmp/docker-mailserver/postfix-virtual.cf

  if [[ -f ${DATABASE_VIRTUAL} ]]; then
    # fixing old virtual user file
    if grep -q ",$" "${DATABASE_VIRTUAL}"; then
      sed -i -e "s|, |,|g" -e "s|,$||g" "${DATABASE_VIRTUAL}"
    fi

    cp -f "${DATABASE_VIRTUAL}" /etc/postfix/virtual
  else
    _log 'debug' "'${DATABASE_VIRTUAL}' not provided - no mail alias/forward created"
  fi
}

function _handle_postfix_regexp_config() {
  : >/etc/postfix/regexp

  if [[ -f /tmp/docker-mailserver/postfix-regexp.cf ]]; then
    _log 'trace' "Adding regexp alias file postfix-regexp.cf"

    cp -f /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp
    _add_to_or_update_postfix_main 'virtual_alias_maps' 'pcre:/etc/postfix/regexp'
  fi
}

function _handle_postfix_aliases_config() {
  _log 'trace' 'Configuring root alias'

  echo "root: ${POSTMASTER_ADDRESS}" >/etc/aliases

  local DATABASE_ALIASES='/tmp/docker-mailserver/postfix-aliases.cf'
  [[ -f ${DATABASE_ALIASES} ]] && cat "${DATABASE_ALIASES}" >>/etc/aliases

  _adjust_mtime_for_postfix_maincf
  postalias /etc/aliases
}

# Other scripts should call this method, rather than the ones above:
function _create_aliases() {
  _handle_postfix_virtual_config
  _handle_postfix_regexp_config
  _handle_postfix_aliases_config
}
