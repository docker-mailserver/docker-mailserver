load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Postscreen] '
CONTAINER1_NAME='dms-test_postscreen_enforce'
CONTAINER2_NAME='dms-test_postscreen_sender'

function setup() {
  CONTAINER1_IP=$(_get_container_ip ${CONTAINER1_NAME})
}

function setup_file() {
  export CONTAINER_NAME

  CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env POSTSCREEN_ACTION=enforce
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  # A standard DMS instance to send mail from:
  # NOTE: None of DMS is actually used for this (just bash + nc).
  CONTAINER_NAME=${CONTAINER2_NAME}
  _init_with_defaults
  # No need to wait for DMS to be ready for this container:
  _common_container_create
  run docker start "${CONTAINER_NAME}"
  assert_success

  # Set default implicit container fallback for helpers:
  CONTAINER_NAME=${CONTAINER1_NAME}
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
}

@test "should fail login when talking out of turn" {
  _run_in_container_explicit "${CONTAINER2_NAME}" bash -c "nc ${CONTAINER1_IP} 25 < /tmp/docker-mailserver-test/auth/smtp-auth-login.txt"
  assert_success
  assert_output --partial '502 5.5.2 Error: command not recognized'

  # Expected postscreen log entry:
  _run_in_container cat /var/log/mail/mail.log
  assert_output --partial 'COMMAND PIPELINING'
}

@test "should successfully login (respecting postscreen_greet_wait time)" {
  # NOTE: Sometimes fails on first attempt (trying too soon?),
  # Instead of a `run` + asserting partial, Using repeat + internal grep match:
  _repeat_until_success_or_timeout 10 _should_wait_turn_speaking_smtp \
    "${CONTAINER2_NAME}" \
    "${CONTAINER1_IP}" \
    '/tmp/docker-mailserver-test/auth/smtp-auth-login.txt' \
    'Authentication successful'

  # Expected postscreen log entry:
  _run_in_container cat /var/log/mail/mail.log
  assert_output --partial 'PASS NEW'
}

# When postscreen is active, it prevents the usual method of piping a file through nc:
# (Won't work: _run_in_container_explicit "${CLIENT_CONTAINER_NAME}" bash -c "nc ${TARGET_CONTAINER_IP} 25 < ${SMTP_TEMPLATE}")
# The below workaround respects `postscreen_greet_wait` time (default 6 sec), talking to the mail-server in turn:
# https://www.postfix.org/postconf.5.html#postscreen_greet_wait
function _should_wait_turn_speaking_smtp() {
  local CLIENT_CONTAINER_NAME=$1
  local TARGET_CONTAINER_IP=$2
  local SMTP_TEMPLATE=$3
  local EXPECTED=$4

  local UGLY_WORKAROUND='exec 3<>/dev/tcp/'"${TARGET_CONTAINER_IP}"'/25 && \
    while IFS= read -r cmd; do \
      head -1 <&3; \
      [[ ${cmd} == "EHLO"* ]] && sleep 6; \
      echo ${cmd} >&3; \
    done < '"${SMTP_TEMPLATE}"

  docker exec "${CLIENT_CONTAINER_NAME}" bash -c "${UGLY_WORKAROUND}" | grep "${EXPECTED}"
}
