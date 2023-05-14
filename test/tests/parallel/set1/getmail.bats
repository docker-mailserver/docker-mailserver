load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Getmail] '
CONTAINER_NAME='dms-test_getmail'

function setup_file() {
  _init_with_defaults
  local CUSTOM_SETUP_ARGUMENTS=(--env 'ENABLE_GETMAIL=1')

  mv "${TEST_TMP_CONFIG}/getmail/getmail-user3.cf" "${TEST_TMP_CONFIG}/getmail-user3.cf"
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'
}

function teardown_file() { _default_teardown ; }

@test 'default configuration exists and is correct' {
  _run_in_container cat /etc/getmailrc_general
  assert_success
  assert_output '[options]
verbose = 0
read_all = false
delete = false
max_messages_per_session = 500
received = false
delivered_to = false
'

  _run_in_container stat /usr/local/bin/debug-getmail
  assert_success
  _run_in_container stat /usr/local/bin/getmail-cron
  assert_success
}

@test 'debug-getmail works as expected' {
  _run_in_container cat /etc/getmailrc.d/getmailrc-user3
  assert_success
  assert_output '[options]
verbose = 0
read_all = false
delete = false
max_messages_per_session = 500
received = false
delivered_to = false
message_log = /var/log/mail/getmail-user3.log

[retriever]
type = SimpleIMAPSSLRetriever
server =  imap.remote-service.test
username = user3
password=secret

[destination]
type = MDA_external
path = /usr/lib/dovecot/deliver
allow_root_commands = true
arguments =("-d","user3@example.test")
'

  _run_in_container /usr/local/bin/debug-getmail
  assert_success
  assert_output = '  retriever:  SimpleIMAPSSLRetriever(ca_certs="None", certfile="None", getmaildir="/var/lib/getmail", imap_on_delete="None", imap_search="None", keyfile="None", mailboxes="('INBOX',)", move_on_delete="None", password="*", password_command="()", port="993", record_mailbox="True", server="imap.remote-service.test", ssl_cert_hostname="None", ssl_ciphers="None", ssl_fingerprints="()", ssl_version="None", timeout="180", use_cram_md5="False", use_kerberos="False", use_peek="True", use_xoauth2="False", username="user3")
  destination:  MDA_external(allow_root_commands="True", arguments="('-d', 'user3@example.test')", command="deliver", group="None", ignore_stderr="False", path="/usr/lib/dovecot/deliver", pipe_stdout="True", unixfrom="False", user="None")
  options:
    delete : False
    delete_after : 0
    delete_bigger_than : 0
    delivered_to : False
    fingerprint : False
    logfile : logfile(filename="/var/log/mail/getmail-user3.log")
    max_bytes_per_session : 0
    max_message_size : 0
    max_messages_per_session : 500
    message_log : /var/log/mail/getmail-user3.log
    message_log_syslog : False
    message_log_verbose : False
    netrc_file : None
    read_all : False
    received : False
    skip_imap_fetch_size : False
    to_oldmail_on_each_mail : False
    use_netrc : False
    verbose : 0
'
}
