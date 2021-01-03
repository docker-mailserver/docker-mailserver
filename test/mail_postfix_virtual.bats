load 'test_helper/common'

@test "checking postfix virtual alias domains no ENV set" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG="$(duplicate_config_for_container . )"
  docker run -d --name mail_postfix_virtual_alias_domains \
            -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
            -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
            -h mail.my-domain.com -t "${NAME}"

  teardown() { docker rm -f mail_postfix_virtual_alias_domains; }

  wait_for_finished_setup_in_container mail_postfix_virtual_alias_domains

  run docker exec mail_postfix_virtual_alias_domains postconf virtual_alias_domains
  assert_output "virtual_alias_domains = ???"
  assert_success
}

@test "checking postfix virtual alias domains with ENV" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG="$(duplicate_config_for_container . )"
  docker run -d --name mail_postfix_virtual_alias_domains \
            -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
            -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
		        -e POSTFIX_VIRTUAL_ALIAS_DOMAINS="domain1.tld domain2.fr" \
            -h mail.my-domain.com -t "${NAME}"

  teardown() { docker rm -f mail_postfix_virtual_alias_domains; }

  wait_for_finished_setup_in_container mail_postfix_virtual_alias_domains

  run docker exec mail_postfix_virtual_alias_domains postconf virtual_alias_domains
  assert_output "virtual_alias_domains = domain1.tld domain2.fr"
  assert_success
}

@test "checking postfix virtual alias maps no ENV set" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG="$(duplicate_config_for_container . )"
  docker run -d --name mail_postfix_virtual_alias_maps \
            -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
            -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
            -h mail.my-domain.com -t "${NAME}"

  teardown() { docker rm -f mail_postfix_virtual_alias_maps; }

  wait_for_finished_setup_in_container mail_postfix_virtual_alias_maps

  run docker exec mail_postfix_virtual_alias_maps postconf virtual_alias_maps
  assert_output "virtual_alias_maps = ???"
  assert_success
}

@test "checking postfix virtual alias maps with ENV" {
  local PRIVATE_CONFIG
  PRIVATE_CONFIG="$(duplicate_config_for_container . )"
  docker run -d --name mail_postfix_virtual_alias_maps \
            -v "${PRIVATE_CONFIG}":/tmp/docker-mailserver \
            -v "$(pwd)/test/test-files":/tmp/docker-mailserver-test:ro \
		        -e POSTFIX_VIRTUAL_ALIAS_maps="hash:/etc/postfix/virtual-custom" \
            -h mail.my-domain.com -t "${NAME}"

  teardown() { docker rm -f mail_postfix_virtual_alias_maps; }

  wait_for_finished_setup_in_container mail_postfix_virtual_alias_maps

  run docker exec mail_postfix_virtual_alias_maps postconf virtual_alias_maps
  assert_output "virtual_alias_maps = hash:/etc/postfix/virtual-custom"
  assert_success
}
