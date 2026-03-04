load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Getmail] '
CONTAINER1_NAME='dms-test_getmail'
CONTAINER2_NAME='dms-test_getmail_parallel'
CONTAINER3_NAME='dms-test_getmail_parallel_specific'

function setup_file() {
  export CONTAINER_NAME

  CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(--env 'ENABLE_GETMAIL=1')
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  CONTAINER_NAME=${CONTAINER2_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_GETMAIL=1
    --env GETMAIL_PARALLEL=1
    --env LOG_LEVEL=debug
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  CONTAINER_NAME=${CONTAINER3_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_GETMAIL=1
    --env GETMAIL_PARALLEL=1
    --env GETMAIL_IDLE='user3.cf,user4.cf'
    --env LOG_LEVEL=debug
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() {
    docker rm -f "${CONTAINER1_NAME}" "${CONTAINER2_NAME}" "${CONTAINER3_NAME}"
}

#? The file used in the following tests is placed in test/config/getmail/user3.cf

@test 'default configuration exists and is correct' {
  _run_in_container cat /etc/getmailrc_general
  assert_success
  assert_line '[options]'
  assert_line 'verbose = 0'
  assert_line 'read_all = false'
  assert_line 'delete = false'
  assert_line 'max_messages_per_session = 500'
  assert_line 'received = false'
  assert_line 'delivered_to = false'
  assert_line 'message_log_syslog = true'

  _run_in_container_bash '[[ -f /usr/local/bin/debug-getmail ]]'
  assert_success
  _run_in_container_bash '[[ -f /usr/local/bin/getmail-service.sh ]]'
  assert_success
}

@test 'debug-getmail works as expected' {
  _run_in_container cat /etc/getmailrc.d/user3
  assert_success
  assert_line '[options]'
  assert_line 'verbose = 0'
  assert_line 'read_all = false'
  assert_line 'delete = false'
  assert_line 'max_messages_per_session = 500'
  assert_line 'received = false'
  assert_line 'delivered_to = false'
  assert_line 'message_log_syslog = true'
  assert_line '[retriever]'
  assert_line 'type = SimpleIMAPSSLRetriever'
  assert_line 'server =  imap.remote-service.test'
  assert_line 'username = user3'
  assert_line 'password=secret'
  assert_line '[destination]'
  assert_line 'type = MDA_external'
  assert_line 'path = /usr/lib/dovecot/deliver'
  assert_line 'allow_root_commands = true'
  assert_line 'arguments =("-d","user3@example.test")'

  _run_in_container /usr/local/bin/debug-getmail
  assert_success
  assert_line --regexp 'retriever:.*SimpleIMAPSSLRetriever\(ca_certs="None", certfile="None", getmaildir="\/var\/lib\/getmail", imap_on_delete="None", imap_search="None", keyfile="None", mailboxes="\(.*INBOX.*\)", move_on_delete="None", password="\*", password_command="\(\)", port="993", record_mailbox="True", server="imap.remote-service.test", ssl_cert_hostname="None", ssl_ciphers="None", ssl_fingerprints="\(\)", ssl_version="None", timeout="180", use_cram_md5="False", use_kerberos="False", use_peek="True", use_xoauth2="False", username="user3"\)'
  assert_line --regexp 'destination:.*MDA_external\(allow_root_commands="True", arguments="\(.*-d.*user3@example.test.*\)", command="deliver", group="None", ignore_stderr="False", path="\/usr\/lib\/dovecot\/deliver", pipe_stdout="True", unixfrom="False", user="None"\)'
  assert_line '    delete : False'
  assert_line '    delete_after : 0'
  assert_line '    delete_bigger_than : 0'
  assert_line '    delivered_to : False'
  assert_line '    fingerprint : False'
  assert_line '    max_bytes_per_session : 0'
  assert_line '    max_message_size : 0'
  assert_line '    max_messages_per_session : 500'
  assert_line '    message_log : None'
  assert_line '    message_log_syslog : True'
  assert_line '    message_log_verbose : False'
  assert_line '    netrc_file : None'
  assert_line '    read_all : False'
  assert_line '    received : False'
  assert_line '    skip_imap_fetch_size : False'
  assert_line '    to_oldmail_on_each_mail : False'
  assert_line '    use_netrc : False'
  assert_line '    verbose : 0'
}

@test "(ENV GETMAIL_PARALLEL=1, GETMAIL_IDLE=auto) should create seperate services and start idle on all IMAP configs" {
  export CONTAINER_NAME=${CONTAINER2_NAME}

  _wait_for_service getmail-1
  _wait_for_service getmail-2
  _wait_for_service getmail-3
  _wait_for_service getmail-4

  _service_log_should_contain_string "mail" "getmail-1"
  _service_log_should_contain_string "mail" "getmail-2"
  _service_log_should_contain_string "mail" "getmail-3"
  _service_log_should_contain_string "mail" "getmail-4"

  _service_log_should_contain_string "mail" "Enabling IMAP IDLE for user3.cf"
  _service_log_should_contain_string "mail" "Enabling IMAP IDLE for user4.cf"
  _service_log_should_contain_string "mail" "Enabling IMAP IDLE for user5.cf"
  _service_log_should_not_contain_string "mail" "Enabling IMAP IDLE for user6.cf"

  _service_log_should_not_contain_string "mail" "Processing user3.cf"
  _service_log_should_not_contain_string "mail" "Processing user4.cf"
  _service_log_should_not_contain_string "mail" "Processing user5.cf"
  _service_log_should_contain_string "mail" "Processing user6.cf"
}

@test "(ENV GETMAIL_PARALLEL=1, GETMAIL_IDLE=user3.cf,user4.cf) should create seperate services and only start idle on 2 configs" {
  export CONTAINER_NAME=${CONTAINER3_NAME}

  _wait_for_service getmail-1
  _wait_for_service getmail-2
  _wait_for_service getmail-3
  _wait_for_service getmail-4

  _service_log_should_contain_string "mail" "getmail-1"
  _service_log_should_contain_string "mail" "getmail-2"
  _service_log_should_contain_string "mail" "getmail-3"
  _service_log_should_contain_string "mail" "getmail-4"

  _service_log_should_contain_string "mail" "Enabling IMAP IDLE for user3.cf"
  _service_log_should_contain_string "mail" "Enabling IMAP IDLE for user4.cf"
  _service_log_should_not_contain_string "mail" "Enabling IMAP IDLE for user5.cf"
  _service_log_should_not_contain_string "mail" "Enabling IMAP IDLE for user6.cf"

  _service_log_should_not_contain_string "mail" "Processing user3.cf"
  _service_log_should_not_contain_string "mail" "Processing user4.cf"
  _service_log_should_contain_string "mail" "Processing user5.cf"
  _service_log_should_contain_string "mail" "Processing user6.cf"

}
