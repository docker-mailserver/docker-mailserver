load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking postscreen" {
  # Getting mail container IP
  MAIL_POSTSCREEN_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' mail_postscreen)
  echo $MAIL_POSTSCREEN_IP
  # talk too fast:
  docker run --rm -e MAIL_FAIL2BAN_IP=$MAIL_FAIL2BAN_IP -v "$(pwd)/test":/tmp/docker-mailserver-test tvial/docker-mailserver:testing /bin/sh -c "nc $MAIL_POSTSCREEN_IP 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt"

  sleep 5

  run docker exec mail_postscreen grep 'COMMAND PIPELINING' /var/log/mail/mail.log
  assert_success

  # positive test. (respecting postscreen_greet_wait time and talking in turn):
  for i in {1,2}; do
    docker run --rm -e MAIL_FAIL2BAN_IP=$MAIL_FAIL2BAN_IP -v "$(pwd)/test":/tmp/docker-mailserver-test tvial/docker-mailserver:testing /bin/bash -c \
    'exec 3<>/dev/tcp/'$MAIL_POSTSCREEN_IP'/25 && \
    while IFS= read -r cmd; do \
      head -1 <&3; \
      [[ "$cmd" == "EHLO"* ]] && sleep 6; \
      echo $cmd >&3; \
    done < "/tmp/docker-mailserver-test/auth/smtp-auth-login.txt"'
  done

  sleep 5

  run docker exec mail_postscreen grep 'PASS NEW ' /var/log/mail/mail.log
  assert_success
}
