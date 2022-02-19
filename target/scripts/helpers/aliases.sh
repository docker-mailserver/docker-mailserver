#! /bin/bash
# Support for Postfix aliases

# NOTE: LDAP doesn't appear to use this, but the docs page: "Use Cases | Forward-Only Mail-Server with LDAP"
# does have an example where /etc/postfix/virtual is referenced in addition to ldap config for Postfix `main.cf:virtual_alias_maps`.
# `setup-stack.sh:_setup_ldap` does not seem to configure for `/etc/postfix/virtual however.`

# NOTE: `accounts.sh` and `relay.sh:_populate_relayhost_map` also process on `postfix-virtual.cf`.
function _handle_postfix_virtual_config
{
  : >/etc/postfix/virtual
  : >/etc/postfix/regexp

  if [[ -f /tmp/docker-mailserver/postfix-virtual.cf ]]
  then
    # fixing old virtual user file
    if grep -q ",$" /tmp/docker-mailserver/postfix-virtual.cf
    then
      sed -i -e "s|, |,|g" -e "s|,$||g" /tmp/docker-mailserver/postfix-virtual.cf
    fi

    cp -f /tmp/docker-mailserver/postfix-virtual.cf /etc/postfix/virtual

    # the `to` is important, don't delete it
    # shellcheck disable=SC2034
    while read -r FROM TO
    do
      UNAME=$(echo "${FROM}" | cut -d @ -f1)
      DOMAIN=$(echo "${FROM}" | cut -d @ -f2)

      # if they are equal it means the line looks like: "user1     other@domain.tld"
      [[ ${UNAME} != "${DOMAIN}" ]] && echo "${DOMAIN}" >>/tmp/vhost.tmp
    done < <(grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-virtual.cf || true)
  else
    _notify 'inf' "Warning '/tmp/docker-mailserver/postfix-virtual.cf' is not provided. No mail alias/forward created."
  fi
}

function _handle_postfix_regexp_config
{
  if [[ -f /tmp/docker-mailserver/postfix-regexp.cf ]]
  then
    _notify 'inf' "Adding regexp alias file postfix-regexp.cf"

    cp -f /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp

    if ! grep 'virtual_alias_maps.*pcre:/etc/postfix/regexp' /etc/postfix/main.cf
    then
      sed -i -E \
        's|virtual_alias_maps(.*)|virtual_alias_maps\1 pcre:/etc/postfix/regexp|g' \
        /etc/postfix/main.cf
    fi
  fi
}

function _handle_postfix_aliases_config
{
  _notify 'inf' 'Configuring root alias'

  echo "root: ${POSTMASTER_ADDRESS}" >/etc/aliases

  if [[ -f /tmp/docker-mailserver/postfix-aliases.cf ]]
  then
    cat /tmp/docker-mailserver/postfix-aliases.cf >>/etc/aliases
  else
    _notify 'inf' "'/tmp/docker-mailserver/postfix-aliases.cf' is not provided, it will be auto created."
    : >/tmp/docker-mailserver/postfix-aliases.cf
  fi

  postalias /etc/aliases
}

# Other scripts should call this method, rather than the ones above:
function _create_aliases
{
  _handle_postfix_virtual_config
  _handle_postfix_regexp_config
  _handle_postfix_aliases_config
}
export -f _create_aliases
