load "${REPOSITORY_ROOT}/test/helper/common"
load "${REPOSITORY_ROOT}/test/helper/setup"

BATS_TEST_NAME_PREFIX='[Special Use Folders] '
CONTAINER_NAME='dms-test_special-use-folders'

function setup_file() {
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(--env PERMIT_DOCKER=host)
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
  _wait_for_smtp_port_in_container
}

function teardown_file() { _default_teardown ; }

@test "normal delivery works" {
  _run_in_container_bash "nc 0.0.0.0 25 < /tmp/docker-mailserver-test/email-templates/existing-user1.txt"
  assert_success

  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/new 1
}

@test "(IMAP) special-use folders should not exist yet" {
  _run_in_container find /var/mail/localhost.localdomain/user1 -maxdepth 1 -type d
  assert_success
  refute_output --partial '.Drafts'
  refute_output --partial '.Sent'
  refute_output --partial '.Trash'
}

@test "(IMAP) special-use folders should be created when necessary" {
  _run_in_container_bash "nc -w 8 0.0.0.0 143 < /tmp/docker-mailserver-test/nc_templates/imap_special_use_folders.txt"
  assert_success
  assert_output --partial 'Drafts'
  assert_output --partial 'Junk'
  assert_output --partial 'Trash'
  assert_output --partial 'Sent'
}
