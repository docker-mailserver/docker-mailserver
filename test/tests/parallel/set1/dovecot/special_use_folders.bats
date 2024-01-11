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

@test 'normal delivery works' {
  _send_email
  _count_files_in_directory_in_container /var/mail/localhost.localdomain/user1/new 1
}

@test '(IMAP) special-use folders should not exist yet' {
  _should_have_content_in_directory '/var/mail/localhost.localdomain/user1'
  refute_line '.Drafts'
  refute_line '.Sent'
  refute_line '.Trash'
}

@test "(IMAP) special-use folders should be created when necessary" {
  _nc_wrapper 'nc/imap_special_use_folders.txt' '-w 8 0.0.0.0 143'
  assert_output --partial 'Drafts'
  assert_output --partial 'Junk'
  assert_output --partial 'Trash'
  assert_output --partial 'Sent'
}
