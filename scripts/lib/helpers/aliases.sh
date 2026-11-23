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
    cp -f "${DATABASE_VIRTUAL}" /etc/postfix/virtual
    __add_identity_aliases_for_catch_all_domains
  else
    _log 'debug' "'${DATABASE_VIRTUAL}' not provided - no mail alias/forward created"
  fi
}

# Postfix resolves `virtual_alias_maps` before `virtual_mailbox_maps`. A catch-all alias (`@example.com`)
# therefore also captures mail for the accounts of that domain, unless each account is an alias to itself.
# https://github.com/docker-mailserver/docker-mailserver/issues/4856
#
# These identity aliases are only written to `/etc/postfix/virtual` and never to `postfix-virtual.cf`:
# - `setup alias add` rejects them on purpose (an alias and account sharing an address caused forwarding problems).
# - Quota dummy accounts (`accounts.sh:_create_dovecot_alias_dummy_accounts`) and `setup alias list` stay unaffected.
#
# An account that is explicitly listed in `postfix-virtual.cf` keeps the entry of the user.
# NOTE: Expects `/etc/postfix/virtual` to be a fresh copy of `postfix-virtual.cf` (see `_handle_postfix_virtual_config`).
function __add_identity_aliases_for_catch_all_domains() {
  local DATABASE_ACCOUNTS='/tmp/docker-mailserver/postfix-accounts.cf'
  local DATABASE_VIRTUAL='/tmp/docker-mailserver/postfix-virtual.cf'

  # LDAP does not use `postfix-accounts.cf`, a stale file must not change how its catch-all behaves:
  [[ ${ACCOUNT_PROVISIONER} == 'FILE' ]] || return 0
  [[ -f ${DATABASE_ACCOUNTS} ]] || return 0

  # The copy might lack a final newline, which would merge the first appended line into the last one:
  _append_final_newline_if_missing /etc/postfix/virtual

  # A single `awk` pass over both files is the upgrade path should this become noticeable at startup.
  local MAIL_ACCOUNT
  while IFS='|' read -r MAIL_ACCOUNT _; do
    if _db_has_entry_with_key "@${MAIL_ACCOUNT#*@}" "${DATABASE_VIRTUAL}" \
    && ! _db_has_entry_with_key "${MAIL_ACCOUNT}" "${DATABASE_VIRTUAL}"; then
      _log 'debug' "Adding identity alias for '${MAIL_ACCOUNT}' as its domain has a catch-all alias"
      echo "${MAIL_ACCOUNT} ${MAIL_ACCOUNT}" >>/etc/postfix/virtual
    fi
  done < <(_get_valid_lines_from_file "${DATABASE_ACCOUNTS}")
}

# TODO: Investigate why this file is always created, nothing seems to append only the cp below?
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
