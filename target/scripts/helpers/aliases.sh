#! /bin/bash
# Support for Postfix aliases

function _create_aliases
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

  if [[ -f /tmp/docker-mailserver/postfix-regexp.cf ]]
  then
    _notify 'inf' "Adding regexp alias file postfix-regexp.cf"

    cp -f /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp
    sed -i -E \
      's|virtual_alias_maps(.*)|virtual_alias_maps\1 pcre:/etc/postfix/regexp|g' \
      /etc/postfix/main.cf
  fi

  _notify 'inf' 'Configuring root alias'

  echo "root: ${POSTMASTER_ADDRESS}" > /etc/aliases

  if [[ -f /tmp/docker-mailserver/postfix-aliases.cf ]]
  then
    cat /tmp/docker-mailserver/postfix-aliases.cf >>/etc/aliases
  else
    _notify 'inf' "'/tmp/docker-mailserver/postfix-aliases.cf' is not provided, it will be auto created."
    : >/tmp/docker-mailserver/postfix-aliases.cf
  fi

  postalias /etc/aliases
}
