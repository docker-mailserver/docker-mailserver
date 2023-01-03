load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

TEST_NAME_PREFIX='Postscreen:'
CONTAINER1_NAME='dms-test_postscreen_enforce'
CONTAINER2_NAME='dms-test_postscreen_sender'

function setup() {
  MAIL_POSTSCREEN_IP=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "${CONTAINER1_NAME}")
}

function setup_file() {
  local CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env POSTSCREEN_ACTION=enforce
    --cap-add=NET_ADMIN
  )
  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  wait_for_smtp_port_in_container "${CONTAINER_NAME}"

  local CONTAINER_NAME=${CONTAINER2_NAME}
  init_with_defaults
  common_container_setup
  wait_for_smtp_port_in_container "${CONTAINER_NAME}"
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
}

@test "${TEST_NAME_PREFIX} talk too fast" {
  run docker exec "${CONTAINER2_NAME}" /bin/sh -c "nc ${MAIL_POSTSCREEN_IP} 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt"
  assert_success

  repeat_until_success_or_timeout 10 run docker exec "${CONTAINER1_NAME}" grep 'COMMAND PIPELINING' /var/log/mail/mail.log
  assert_success
}

@test "${TEST_NAME_PREFIX} positive test (respecting postscreen_greet_wait time and talking in turn)" {
  for _ in {1,2}; do
    # shellcheck disable=SC1004
    docker exec "${CONTAINER2_NAME}" /bin/bash -c \
    'exec 3<>/dev/tcp/'"${MAIL_POSTSCREEN_IP}"'/25 && \
    while IFS= read -r cmd; do \
      head -1 <&3; \
      [[ ${cmd} == "EHLO"* ]] && sleep 6; \
      echo ${cmd} >&3; \
    done < "/tmp/docker-mailserver-test/auth/smtp-auth-login.txt"'
  done

  repeat_until_success_or_timeout 10 run docker exec "${CONTAINER1_NAME}" grep 'PASS NEW ' /var/log/mail/mail.log
  assert_success
}
