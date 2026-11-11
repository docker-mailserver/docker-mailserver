load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

# Docs: https://docker-mailserver.github.io/docker-mailserver/edge/config/environment/#dms_trusted_networks

BATS_TEST_NAME_PREFIX='[Network - Trusted networks] '

function teardown() { _default_teardown ; }

# Regression test for https://github.com/docker-mailserver/docker-mailserver/issues/4634
#
# DMS used to look up an IPv4 address of the container for any value, and failed to start without one (e.g. in an
# IPv6-only network). Not every Docker host supports IPv6 networks, but a container without any network interface
# besides `lo` has the very same trait: there is no IPv4 address at `eth0`.
@test "should start without an IPv4 address when no network is trusted (default)" {
  export CONTAINER_NAME='dms-test_trusted-networks_no-ipv4-address'

  # Without a network, Docker does not add the hostname to `/etc/hosts`, so `hostname -f` could not resolve it.
  local CUSTOM_SETUP_ARGUMENTS=(
    --network none
    --env OVERRIDE_HOSTNAME=mail.example.test
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container

  _run_in_container postconf -h mynetworks
  assert_success
  assert_output ''
}

@test "should trust the container itself for 'host'" {
  export CONTAINER_NAME='dms-test_trusted-networks_host'

  local CUSTOM_SETUP_ARGUMENTS=(
    --env DMS_TRUSTED_NETWORKS=host
    --env ENABLE_OPENDKIM=1
    --env ENABLE_OPENDMARC=1
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  local CONTAINER_IP
  CONTAINER_IP=$(_get_container_ip)

  _run_in_container postconf -h mynetworks
  assert_success
  assert_output --partial "${CONTAINER_IP}/32"

  _run_in_container grep -Fx "${CONTAINER_IP}/32" /etc/opendmarc/ignore.hosts
  assert_success
  _run_in_container grep -Fx "${CONTAINER_IP}/32" /etc/opendkim/TrustedHosts
  assert_success
}

# OpenDKIM and OpenDMARC match the text form of the client address (lower case, compressed IPv6) with a prefix length
# against their lists, so the configured ranges have to be normalized, not just copied.
@test "should trust a list of CIDR ranges, normalized for Postfix, OpenDKIM and OpenDMARC" {
  export CONTAINER_NAME='dms-test_trusted-networks_cidr-list'

  local CUSTOM_SETUP_ARGUMENTS=(
    --env DMS_TRUSTED_NETWORKS='192.0.2.77/24, 2001:DB8:0::5/32 198.51.100.0/24'
    --env ENABLE_OPENDKIM=1
    --env ENABLE_OPENDMARC=1
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container postconf -h mynetworks
  assert_success
  assert_output --partial '192.0.2.0/24'
  assert_output --partial '[2001:db8::]/32'
  assert_output --partial '198.51.100.0/24'

  local FILE NETWORK
  for FILE in /etc/opendmarc/ignore.hosts /etc/opendkim/TrustedHosts; do
    for NETWORK in '192.0.2.0/24' '2001:db8::/32' '198.51.100.0/24'; do
      _run_in_container grep -Fx "${NETWORK}" "${FILE}"
      assert_success
    done

    _run_in_container grep -F -e '192.0.2.77' -e 'DB8' "${FILE}"
    assert_failure
  done
}

@test "should refuse to start when the value is neither a keyword nor a CIDR range" {
  export CONTAINER_NAME='dms-test_trusted-networks_invalid-value'

  local CUSTOM_SETUP_ARGUMENTS=(--env DMS_TRUSTED_NETWORKS='static:all')
  _init_with_defaults
  _common_container_create 'CUSTOM_SETUP_ARGUMENTS'
  _common_container_start

  _repeat_until_success_or_timeout 60 bash -c "docker logs ${CONTAINER_NAME} 2>&1 | grep -F \"Invalid value for DMS_TRUSTED_NETWORKS ('static:all'\""
  _repeat_until_success_or_timeout 60 bash -c "[[ \$(docker inspect -f '{{.State.Running}}' ${CONTAINER_NAME}) == 'false' ]]"
}

@test "should log an error for the replaced ENV 'PERMIT_DOCKER' and the removed ENV 'NETWORK_INTERFACE'" {
  export CONTAINER_NAME='dms-test_trusted-networks_legacy-env'

  local CUSTOM_SETUP_ARGUMENTS=(
    --env PERMIT_DOCKER=container
    --env NETWORK_INTERFACE=eth0
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  run docker logs "${CONTAINER_NAME}"
  assert_output --partial "'PERMIT_DOCKER' has been replaced by 'DMS_TRUSTED_NETWORKS'"
  assert_output --partial "'NETWORK_INTERFACE' has been removed"

  # The old values are ignored and the default applies:
  _run_in_container postconf -h mynetworks
  assert_success
  assert_output ''
}
