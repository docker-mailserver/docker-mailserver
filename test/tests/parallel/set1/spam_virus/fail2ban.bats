load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

TEST_NAME_PREFIX='Fail2Ban:'
CONTAINER1_NAME='dms-test_fail2ban'
CONTAINER2_NAME='dms-test_fail2ban_fail-auth-mailer'

function get_container2_ip() {
  docker inspect --format '{{ .NetworkSettings.IPAddress }}' "${CONTAINER2_NAME}"
}

function setup_file() {
  export CONTAINER_NAME

  CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_FAIL2BAN=1
    --env POSTSCREEN_ACTION=ignore
    --cap-add=NET_ADMIN
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
  )
  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  wait_for_smtp_port_in_container "${CONTAINER_NAME}"

  # Create a container which will send wrong authentications and should get banned
  CONTAINER_NAME=${CONTAINER2_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(--env MAIL_FAIL2BAN_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' ${CONTAINER1_NAME})")
  init_with_defaults
  common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  # Set default implicit container fallback for helpers:
  CONTAINER_NAME=${CONTAINER1_NAME}
}

function teardown_file() {
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}"
}

@test "${TEST_NAME_PREFIX} Fail2Ban is running" {
  run check_if_process_is_running 'fail2ban-server'
  assert_success
}

@test "${TEST_NAME_PREFIX} localhost is not banned because ignored" {
  _run_in_container fail2ban-client status postfix-sasl
  assert_success
  refute_output --regexp '.*IP list:.*127\.0\.0\.1.*'

  _run_in_container grep 'ignoreip = 127.0.0.1/8' /etc/fail2ban/jail.conf
  assert_success
}

@test "${TEST_NAME_PREFIX} fail2ban-fail2ban.cf overrides" {
  _run_in_container fail2ban-client get loglevel
  assert_success
  assert_output --partial 'DEBUG'
}

@test "${TEST_NAME_PREFIX} fail2ban-jail.cf overrides" {
  for FILTER in 'dovecot' 'postfix' 'postfix-sasl'
  do
    _run_in_container fail2ban-client get "${FILTER}" bantime
    assert_output 1234

    _run_in_container fail2ban-client get "${FILTER}" findtime
    assert_output 321

    _run_in_container fail2ban-client get "${FILTER}" maxretry
    assert_output 2

    _run_in_container fail2ban-client -d
    assert_output --partial "['set', 'dovecot', 'addaction', 'nftables-multiport']"
    assert_output --partial "['set', 'postfix', 'addaction', 'nftables-multiport']"
    assert_output --partial "['set', 'postfix-sasl', 'addaction', 'nftables-multiport']"
  done
}

# NOTE: This test case is fragile if other test cases were to be run concurrently
@test "${TEST_NAME_PREFIX} ban ip on multiple failed login" {
  # can't pipe the file as usual due to postscreen
  # respecting postscreen_greet_wait time and talking in turn):

  # shellcheck disable=SC1004
  for _ in {1,2}
  do
    docker exec "${CONTAINER2_NAME}" /bin/bash -c \
    'exec 3<>/dev/tcp/${MAIL_FAIL2BAN_IP}/25 && \
    while IFS= read -r cmd; do \
      head -1 <&3; \
      [[ ${cmd} == "EHLO"* ]] && sleep 6; \
      echo ${cmd} >&3; \
    done < "/tmp/docker-mailserver-test/auth/smtp-auth-login-wrong.txt"'
  done

  sleep 5

  # Checking that CONTAINER2_IP is banned in "${CONTAINER1_NAME}"
  CONTAINER2_IP=$(get_container2_ip)
  _run_in_container fail2ban-client status postfix-sasl
  assert_success
  assert_output --partial "${CONTAINER2_IP}"

  # Checking that CONTAINER2_IP is banned by nftables
  _run_in_container bash -c 'nft list set inet f2b-table addr-set-postfix-sasl'
  assert_success
  assert_output --partial "elements = { ${CONTAINER2_IP} }"
}

@test "${TEST_NAME_PREFIX} unban ip works" {
  CONTAINER2_IP=$(get_container2_ip)
  _run_in_container fail2ban-client set postfix-sasl unbanip "${CONTAINER2_IP}"
  assert_success
  sleep 5

  # Checking that CONTAINER2_IP is unbanned in "${CONTAINER1_NAME}"
  _run_in_container fail2ban-client status postfix-sasl
  assert_success
  refute_output --partial "${CONTAINER2_IP}"

  # Checking that CONTAINER2_IP is unbanned by nftables
  _run_in_container bash -c 'nft list set inet f2b-table addr-set-postfix-sasl'
  refute_output --partial "${CONTAINER2_IP}"
}

@test "${TEST_NAME_PREFIX} bans work properly (single IP)" {
  _run_in_container fail2ban ban 192.0.66.7
  assert_success
  assert_output 'Banned custom IP: 1'

  _run_in_container fail2ban
  assert_success
  assert_output --regexp 'Banned in custom:.*192\.0\.66\.7'

  _run_in_container nft list set inet f2b-table addr-set-custom
  assert_success
  assert_output --partial 'elements = { 192.0.66.7 }'

  _run_in_container fail2ban unban 192.0.66.7
  assert_success
  assert_output --partial 'Unbanned IP from custom: 1'

  _run_in_container nft list set inet f2b-table addr-set-custom
  refute_output --partial '192.0.66.7'
}

@test "${TEST_NAME_PREFIX} bans work properly (subnet)" {
  _run_in_container fail2ban ban 192.0.66.0/24
  assert_success
  assert_output 'Banned custom IP: 1'

  _run_in_container fail2ban
  assert_success
  assert_output --regexp 'Banned in custom:.*192\.0\.66\.0/24'

  _run_in_container nft list set inet f2b-table addr-set-custom
  assert_success
  assert_output --partial 'elements = { 192.0.66.0/24 }'

  _run_in_container fail2ban unban 192.0.66.0/24
  assert_success
  assert_output --partial 'Unbanned IP from custom: 1'

  _run_in_container nft list set inet f2b-table addr-set-custom
  refute_output --partial '192.0.66.0/24'
}

@test "${TEST_NAME_PREFIX} FAIL2BAN_BLOCKTYPE is really set to drop" {
  # ban IPs here manually so we can be sure something is inside the jails
  for JAIL in dovecot postfix-sasl custom; do
    _run_in_container fail2ban-client set "${JAIL}" banip 192.33.44.55
    assert_success
  done

  _run_in_container nft list table inet f2b-table
  assert_success
  assert_output --partial 'tcp dport { 110, 143, 465, 587, 993, 995, 4190 } ip saddr @addr-set-dovecot drop'
  assert_output --partial 'tcp dport { 25, 110, 143, 465, 587, 993, 995 } ip saddr @addr-set-postfix-sasl drop'
  assert_output --partial 'tcp dport { 25, 110, 143, 465, 587, 993, 995, 4190 } ip saddr @addr-set-custom drop'

  # unban the IPs previously banned to get a clean state again
  for JAIL in dovecot postfix-sasl custom; do
    _run_in_container fail2ban-client set "${JAIL}" unbanip 192.33.44.55
    assert_success
  done
}

@test "${TEST_NAME_PREFIX} setup.sh fail2ban" {
  _run_in_container fail2ban-client set dovecot banip 192.0.66.4
  _run_in_container fail2ban-client set dovecot banip 192.0.66.5

  sleep 10

  # Originally: run ./setup.sh -c "${CONTAINER1_NAME}" fail2ban
  _run_in_container setup fail2ban
  assert_output --regexp '^Banned in dovecot:.*192\.0\.66\.4'
  assert_output --regexp '^Banned in dovecot:.*192\.0\.66\.5'

  _run_in_container setup fail2ban unban 192.0.66.4
  assert_output --partial "Unbanned IP from dovecot: 1"

  _run_in_container setup fail2ban
  assert_output --regexp '^Banned in dovecot:.*192\.0\.66\.5'

  _run_in_container setup fail2ban unban 192.0.66.5
  assert_output --partial 'Unbanned IP from dovecot: 1'

  _run_in_container setup fail2ban unban
  assert_output --partial 'You need to specify an IP address: Run'
}

@test "${TEST_NAME_PREFIX} restart of Fail2Ban" {
  _run_in_container pkill fail2ban
  assert_success

  run_until_success_or_timeout 10 check_if_process_is_running 'fail2ban-server'
}
