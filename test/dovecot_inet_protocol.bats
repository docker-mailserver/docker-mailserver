load 'test_helper/common'

function setup_file() {
  local PRIVATE_CONFIG
  export ALL IPV4 IPV6

  PRIVATE_CONFIG=$(duplicate_config_for_container . "${IPV4}")
  ALL="mail_dovecot_all_protocols"
  IPV4="mail_dovecot_ipv4"
  IPV6="mail_dovecot_ipv6"

  docker run --rm -d --name "${ALL}" \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -e DOVECOT_INET_PROTOCOLS= \
    -h mail.my-domain.com \
    -t "${NAME}"

  docker run --rm -d --name "${IPV4}" \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -e DOVECOT_INET_PROTOCOLS=ipv4 \
    -h mail.my-domain.com \
    -t "${NAME}"

  docker run --rm -d --name "${IPV6}" \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -e DOVECOT_INET_PROTOCOLS=ipv6 \
    -h mail.my-domain.com \
    -t "${NAME}"
}

@test 'checking dovecot IP configuration' {
  wait_for_finished_setup_in_container "${ALL}"
  run docker exec "${ALL}" grep '^#listen = \*, ::' /etc/dovecot/dovecot.conf
  assert_success
  assert_output '#listen = *, ::'
}

@test 'checking dovecot IPv4 configuration' {
  wait_for_finished_setup_in_container "${IPV4}"
  run docker exec "${IPV4}" grep '^listen = \*$' /etc/dovecot/dovecot.conf
  assert_success
  assert_output 'listen = *'
}

@test 'checking dovecot IPv6 configuration' {
  wait_for_finished_setup_in_container "${IPV6}"
  run docker exec "${IPV6}" grep '^listen = \[::\]$' /etc/dovecot/dovecot.conf
  assert_success
  assert_output 'listen = [::]'
}

function teardown_file {
  docker rm -f "${ALL}" "${IPV4}" "${IPV6}"
}
