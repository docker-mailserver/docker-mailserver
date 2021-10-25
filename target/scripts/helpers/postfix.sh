#! /bin/bash
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
function _create_postfix_vhost
{
  if [[ -f /tmp/vhost.tmp ]]
  then
    sort < /tmp/vhost.tmp | uniq > /etc/postfix/vhost
    rm /tmp/vhost.tmp
  elif [[ ! -f /etc/postfix/vhost ]]
  then
    touch /etc/postfix/vhost
  fi
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
# /etc/aliases is handled by `alias.sh` and uses `postalias` to update the Postfix alias database. No need for `postmap`
# http://www.postfix.org/postalias.1.html
