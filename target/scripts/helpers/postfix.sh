#!/bin/bash
# Support for Postfix features

# Docs - virtual_mailbox_domains (Used in /etc/postfix/main.cf):
# http://www.postfix.org/ADDRESS_CLASS_README.html#virtual_mailbox_class
# http://www.postfix.org/VIRTUAL_README.html
# > If you omit this setting then Postfix will reject mail (relay access denied) or will not be able to deliver it.
# > NEVER list a virtual MAILBOX domain name as a `mydestination` domain!
# > NEVER list a virtual MAILBOX domain name as a virtual ALIAS domain!
#
# > Execute the command "postmap /etc/postfix/virtual" after changing the virtual file,
# > execute "postmap /etc/postfix/vmailbox" after changing the vmailbox file,
# > and execute the command "postfix reload" after changing the main.cf file.
#
# - virtual_alias_domains is not used by docker-mailserver at present, although LDAP docs reference it.
# - `postmap` only seems relevant when the lookup type is one of these `file_type` values: http://www.postfix.org/postmap.1.html
#   Should not be a concern for most types used by `docker-mailserver`: texthash, ldap, pcre, tcp, unionmap, unix.
#   The only other type in use by `docker-mailserver` is the hash type for /etc/aliases, which `postalias` handles.

function _create_postfix_vhost() {
  # `main.cf` configures `virtual_mailbox_domains = /etc/postfix/vhost`
  # NOTE: Amavis also consumes this file.
  local DATABASE_VHOST='/etc/postfix/vhost'
  local TMP_VHOST='/tmp/vhost.postfix.tmp'

  _vhost_collect_postfix_domains
  _create_vhost
}

# Filter unique values into a proper DATABASE_VHOST config:
function _create_vhost() {
  : >"${DATABASE_VHOST}"

  if [[ -f ${TMP_VHOST} ]]; then
    sort < "${TMP_VHOST}" | uniq >>"${DATABASE_VHOST}"
    rm "${TMP_VHOST}"
  fi
}

# Collects domains from configs (DATABASE_) into TMP_VHOST
function _vhost_collect_postfix_domains() {
  local DATABASE_ACCOUNTS='/tmp/docker-mailserver/postfix-accounts.cf'
  local DATABASE_VIRTUAL='/tmp/docker-mailserver/postfix-virtual.cf'
  local DOMAIN UNAME

  # getting domains FROM mail accounts
  if [[ -f ${DATABASE_ACCOUNTS} ]]; then
    while IFS=$'|' read -r LOGIN _; do
      DOMAIN=$(echo "${LOGIN}" | cut -d @ -f2)
      echo "${DOMAIN}" >>"${TMP_VHOST}"
    done < <(_get_valid_lines_from_file "${DATABASE_ACCOUNTS}")
  fi

  # getting domains FROM mail aliases
  if [[ -f ${DATABASE_VIRTUAL} ]]; then
    while read -r FROM _; do
      UNAME=$(echo "${FROM}" | cut -d @ -f1)
      DOMAIN=$(echo "${FROM}" | cut -d @ -f2)

      # if they are equal it means the line looks like: "user1     other@domain.tld"
      [[ ${UNAME} != "${DOMAIN}" ]] && echo "${DOMAIN}" >>"${TMP_VHOST}"
    done < <(_get_valid_lines_from_file "${DATABASE_VIRTUAL}")
  fi

  _vhost_ldap_support
}

# Add DOMAINNAME (not an ENV, set by `helpers/dns.sh`) to vhost.
# NOTE: `setup-stack.sh:_setup_ldap` has related logic:
# - `main.cf:mydestination` setting removes `$mydestination` as an LDAP bugfix.
# - `main.cf:virtual_mailbox_domains` uses `/etc/postfix/vhost`, but may
#   conditionally include a 2nd table (ldap:/etc/postfix/ldap-domains.cf).
function _vhost_ldap_support() {
  [[ ${ACCOUNT_PROVISIONER} == 'LDAP' ]] && echo "${DOMAINNAME}" >>"${TMP_VHOST}"
}

# Docs - Postfix lookup table files:
# http://www.postfix.org/DATABASE_README.html
#
# Types used in scripts or config: ldap, texthash, hash, pcre, tcp, unionmap, unix
# ldap type changes are network based, no `postfix reload` required.
# texthash type is read into memory when Postfix process starts, requires `postfix reload` to apply changes.
# texthash type does not require running `postmap` after changes are made, other types might.
#
# Examples of different types actively used:
# setup-stack.sh:_setup_spoof_protection uses texthash + hash + pcre, and conditionally unionmap
# main.cf:
# - alias_maps and alias_database both use hash:/etc/aliases
# - virtual_mailbox_maps and virtual_alias_maps use texthash
# - `alias.sh` may append pcre:/etc/postfix/regexp to virtual_alias_maps in `main.cf`
#
# /etc/aliases is handled by `alias.sh` and uses `postalias` to update the Postfix alias database. No need for `postmap`.
# http://www.postfix.org/postalias.1.html

# Add a key with a value to Postfix's main configuration file
# or update an existing key. An already existing key can be updated
# by either appending to the existing value (default) or by prepending.
#
# @param ${1} = key name in Postfix's main configuration file
# @param ${2} = new value (appended or prepended)
# @param ${3} = action "append" (default) or "prepend" [OPTIONAL]
function _add_to_or_update_postfix_main() {
  local KEY=${1:?Key name is required}
  local NEW_VALUE=${2:?New value is required}
  local ACTION=${3:-append}
  local CURRENT_VALUE

  # Get current value from /etc/postfix/main.cf
  _adjust_mtime_for_postfix_maincf
  CURRENT_VALUE=$(postconf -h "${KEY}" 2>/dev/null)

  # If key does not exist or value is empty, add it - otherwise update with ACTION:
  if [[ -z ${CURRENT_VALUE} ]]; then
    postconf "${KEY} = ${NEW_VALUE}"
  else
    # If $NEW_VALUE is already present --> nothing to do, skip.
    if [[ " ${CURRENT_VALUE} " == *" ${NEW_VALUE} "* ]]; then
      return 0
    fi

    case "${ACTION}" in
      ('append')
        postconf "${KEY} = ${CURRENT_VALUE} ${NEW_VALUE}"
        ;;
      ('prepend')
        postconf "${KEY} = ${NEW_VALUE} ${CURRENT_VALUE}"
        ;;
      (*)
        _log 'error' "Action '${3}' in _add_to_or_update_postfix_main is unknown"
        return 1
        ;;
    esac
  fi
}
