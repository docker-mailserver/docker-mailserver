load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[DSN] '
CONTAINER_NAME='dms-test_dsn'

function teardown() { _default_teardown ; }

@test "should always send a DSN when requested" {

  local LOG_DSN='delivery status notification'
  local CONTAINER_ARGS_ENV_CUSTOM=(
    # Required only for delivery via nc (_send_email)
    --env PERMIT_DOCKER=container
  )

  _init_with_defaults
  # Unset `smtpd_discard_ehlo_keywords` to allow DSNs by default on any `smtpd` service:
  mv "${TEST_TMP_CONFIG}/dsn/postfix-main.cf" "${TEST_TMP_CONFIG}/postfix-main.cf"
  _common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'

  _send_email 'email-templates/dsn-unauthenticated'
  _send_email 'email-templates/dsn-authenticated' '0.0.0.0 465'
  _send_email 'email-templates/dsn-authenticated' '0.0.0.0 587'
  _wait_for_empty_mail_queue_in_container

  # A similar line is added to the log when a DSN (Delivery Status Notification) is sent:
  #
  # postfix/bounce[1023]: C943BA6B46: sender delivery status notification: DBF86A6B4CO
  #
  _run_in_container grep "${LOG_DSN}" /var/log/mail/mail.log
  _should_output_number_of_lines 3
}

# Defaults test case
@test "should only send a DSN when requested from ports 465/587" {

  local LOG_DSN='delivery status notification'
  local CONTAINER_ARGS_ENV_CUSTOM=(
    # Required only for delivery via nc (_send_email)
    --env PERMIT_DOCKER=container
  )

  _init_with_defaults
  _common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'

  _send_email 'email-templates/dsn-unauthenticated'
  _wait_for_empty_mail_queue_in_container

  # DSN requests can now only be made on ports 465 and 587,
  # so grep should not find anything.
  #
  # Although external requests are discarded, anyone who has requested a DSN
  # will still receive it, but it will come from the sending mail server, not this one.
  _run_in_container grep "${LOG_DSN}" /var/log/mail/mail.log
  assert_failure

  # These ports are excluded via master.cf.
  _send_email 'email-templates/dsn-authenticated' '0.0.0.0 465'
  _send_email 'email-templates/dsn-authenticated' '0.0.0.0 587'

  _run_in_container grep "${LOG_DSN}" /var/log/mail/mail.log
  _should_output_number_of_lines 2
}

@test "should never send a DSN" {

  local LOG_DSN='delivery status notification'
  local CONTAINER_ARGS_ENV_CUSTOM=(
    # Required only for delivery via nc (_send_email)
    --env PERMIT_DOCKER=container
  )

  _init_with_defaults
  # Mirror default main.cf (disable DSN on ports 465 + 587 too):
  mv "${TEST_TMP_CONFIG}/dsn/postfix-master.cf" "${TEST_TMP_CONFIG}/postfix-master.cf"
  _common_container_setup 'CONTAINER_ARGS_ENV_CUSTOM'

  _send_email 'email-templates/dsn-unauthenticated'
  _send_email 'email-templates/dsn-authenticated' '0.0.0.0 465'
  _send_email 'email-templates/dsn-authenticated' '0.0.0.0 587'
  _wait_for_empty_mail_queue_in_container

  # DSN requests are rejected regardless of origin.
  # This is usually a bad idea, as you won't get them either.
  _run_in_container grep "${LOG_DSN}" /var/log/mail/mail.log
  assert_failure
}
