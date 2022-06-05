load 'test_helper/common'

setup() {
  # Getting mail container IP
  MAIL_POSTSCREEN_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' mail_postscreen)
}

setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)

  docker run -d --name mail_postscreen \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e POSTSCREEN_ACTION=enforce \
    --cap-add=NET_ADMIN \
    -h mail.my-domain.com -t "${NAME}"

  docker run --name mail_postscreen_sender \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -d "${NAME}" \
    tail -f /var/log/faillog

  wait_for_smtp_port_in_container mail_postscreen
}

teardown_file() {
  docker rm -f mail_postscreen mail_postscreen_sender
}

@test "checking postscreen: talk too fast" {
  docker exec mail_postscreen_sender /bin/sh -c "nc ${MAIL_POSTSCREEN_IP} 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt"

  repeat_until_success_or_timeout 10 run docker exec mail_postscreen grep 'COMMAND PIPELINING' /var/log/mail/mail.log
  assert_success
}

@test "checking postscreen: positive test (respecting postscreen_greet_wait time and talking in turn)" {
  for _ in {1,2}; do
    # shellcheck disable=SC1004
    docker exec mail_postscreen_sender /bin/bash -c \
    'exec 3<>/dev/tcp/'"${MAIL_POSTSCREEN_IP}"'/25 && \
    while IFS= read -r cmd; do \
      head -1 <&3; \
      [[ ${cmd} == "EHLO"* ]] && sleep 6; \
      echo ${cmd} >&3; \
    done < "/tmp/docker-mailserver-test/auth/smtp-auth-login.txt"'
  done

  repeat_until_success_or_timeout 10 run docker exec mail_postscreen grep 'PASS NEW ' /var/log/mail/mail.log
  assert_success
}
