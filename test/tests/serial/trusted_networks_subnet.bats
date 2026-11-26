load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[DMS_TRUSTED_NETWORKS] '
CONTAINER1_NAME='dms-test_trusted_networks_subnet'
CONTAINER2_NAME='dms-test_trusted_networks_subnet_sender'
CONTAINER3_NAME='dms-test_trusted_networks_none'
NETWORK1_NAME='dms-test_trusted_networks_1'
NETWORK2_NAME='dms-test_trusted_networks_2'

function setup_file() {
  docker network create --driver bridge "${NETWORK1_NAME}"
  docker network create --driver bridge "${NETWORK2_NAME}"

  local COMMON_ARGUMENTS=(
    --env SMTP_ONLY=1
    # The mail log assertions rely on the Amavis hand-off, Rspamd would classify the test mail as spam.
    --env ENABLE_AMAVIS=1
    --env OVERRIDE_HOSTNAME=mail.my-domain.com
  )

  # Use two networks (the default one of the container and a second one) to recreate the problematic case
  # where trusting only the network of the first interface would not help. `docker create` accepts a single
  # `--network` only, so the container is connected to the second network before it is started.
  export CONTAINER_NAME=${CONTAINER1_NAME}
  _init_with_defaults
  local CONTAINER1_ARGUMENTS=(
    "${COMMON_ARGUMENTS[@]}"
    --env DMS_TRUSTED_NETWORKS=subnet
    --network "${NETWORK1_NAME}"
  )
  _common_container_create 'CONTAINER1_ARGUMENTS'
  docker network connect "${NETWORK2_NAME}" "${CONTAINER_NAME}"
  _common_container_start
  _wait_for_finished_setup_in_container "${CONTAINER_NAME}"
  _wait_for_smtp_port_in_container

  # Sends mail to the first container from the second network
  export CONTAINER_NAME=${CONTAINER2_NAME}
  _init_with_defaults
  local CONTAINER2_ARGUMENTS=(
    "${COMMON_ARGUMENTS[@]}"
    --env DMS_TRUSTED_NETWORKS=subnet
    --network "${NETWORK2_NAME}"
  )
  _common_container_setup 'CONTAINER2_ARGUMENTS'

  # Enforces authentication, even for local connections
  export CONTAINER_NAME=${CONTAINER3_NAME}
  _init_with_defaults
  local CONTAINER3_ARGUMENTS=(
    "${COMMON_ARGUMENTS[@]}"
    --env DMS_TRUSTED_NETWORKS=none
  )
  _common_container_setup 'CONTAINER3_ARGUMENTS'
  _wait_for_smtp_port_in_container
}

function teardown_file() {
  docker logs "${CONTAINER1_NAME}"
  docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}" "${CONTAINER3_NAME}"
  docker network rm "${NETWORK1_NAME}" "${NETWORK2_NAME}"
}

@test 'subnet: the subnets of all networks of the container are trusted' {
  local IPNET1 IPNET2
  IPNET1=$(docker network inspect --format '{{(index .IPAM.Config 0).Subnet}}' "${NETWORK1_NAME}")
  IPNET2=$(docker network inspect --format '{{(index .IPAM.Config 0).Subnet}}' "${NETWORK2_NAME}")

  _run_in_container_explicit "${CONTAINER1_NAME}" /bin/sh -c "postconf | grep '^mynetworks ='"
  assert_output --partial "${IPNET1}"
  assert_output --partial "${IPNET2}"

  _run_in_container_explicit "${CONTAINER1_NAME}" /bin/sh -c 'postconf smtp_host_lookup=no'
  assert_success

  _reload_postfix "${CONTAINER1_NAME}"

  # we should be able to send from the other container on the second network!
  local CONTAINER_NAME=${CONTAINER2_NAME}
  _send_raw_transaction_smtp 'emails/nc_raw/smtp-only.txt' "${CONTAINER1_NAME} 25"
  assert_output --partial '250 2.0.0 Ok: queued as '

  _repeat_in_container_until_success_or_timeout 60 "${CONTAINER1_NAME}" \
    /bin/sh -c 'grep -cE "to=<user2\@external.tld>.*status\=sent" /var/log/mail/mail.log'
}

@test 'none: authentication is required' {
  _run_in_container_explicit "${CONTAINER3_NAME}" /bin/sh -c 'postconf smtp_host_lookup=no'
  assert_success

  _reload_postfix "${CONTAINER3_NAME}"

  # the mailserver should require authentication and a protocol error should occur when using TLS
  local CONTAINER_NAME=${CONTAINER3_NAME}
  _send_raw_transaction 'emails/nc_raw/smtp-only.txt' 'localhost 25'
  assert_output --partial '550 5.5.1 Protocol error'
}
