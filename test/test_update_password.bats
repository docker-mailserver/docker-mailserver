@test "checking user updating password for user in /tmp/docker-mailserver/postfix-accounts.cf" {
  docker exec mail /bin/sh -c "addmailuser user3@domain.tld mypassword"

  initialpass=$(run docker exec mail /bin/sh -c "grep user3@domain.tld -i /tmp/docker-mailserver/postfix-accounts.cf")
  sleep 2
  docker exec mail /bin/sh -c "updatemailuser user3@domain.tld mynewpassword"
  sleep 2
  changepass=$(run docker exec mail /bin/sh -c "grep user3@domain.tld -i /tmp/docker-mailserver/postfix-accounts.cf")


  if [ initialpass != changepass ]; then
    status="0"
  else
    status="1"
  fi
  [ "$status" -eq 0 ]
}
