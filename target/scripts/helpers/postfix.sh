#! /bin/bash
# Support for Postfix features

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
