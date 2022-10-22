load 'test_helper/common'

function setup_file() {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG=$(duplicate_config_for_container .)

  docker run -d --name mail_helper_functions \
    --cap-add=NET_ADMIN \
    -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
    -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
    -e ENABLE_FETCHMAIL=1 \
    -h mail.my-domain.com -t "${NAME}"

  wait_for_finished_setup_in_container mail_helper_functions
}

function teardown_file() {
    docker rm -f mail_helper_functions
}

@test "check helper functions (network.sh): _sanitize_ipv4_to_subnet_cidr" {
    run docker exec mail_helper_functions bash -c "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 255.255.255.255/0"
    assert_output "0.0.0.0/0"

    run docker exec mail_helper_functions bash -c "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 192.168.255.14/20"
    assert_output "192.168.240.0/20"

    run docker exec mail_helper_functions bash -c "source /usr/local/bin/helpers/index.sh; _sanitize_ipv4_to_subnet_cidr 192.168.255.14/32"
    assert_output "192.168.255.14/32"
}
