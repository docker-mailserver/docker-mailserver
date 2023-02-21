load "${REPOSITORY_ROOT}/test/helper/setup"
load "${REPOSITORY_ROOT}/test/helper/common"

BATS_TEST_NAME_PREFIX='[Spam] (undefined subject) '

CONTAINER1_NAME='dms-test_spam-undef-subject_1'
CONTAINER2_NAME='dms-test_spam-undef-subject_2'
CONTAINER_NAME=${CONTAINER2_NAME}

function teardown() { _default_teardown ; }

@test "'SA_SPAM_SUBJECT=undef' should update Amavis config" {
  export CONTAINER_NAME=${CONTAINER1_NAME}
  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_AMAVIS=1
    --env ENABLE_SPAMASSASSIN=1
    --env SA_SPAM_SUBJECT='undef'
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container_bash "grep '\$sa_spam_subject_tag' /etc/amavis/conf.d/20-debian_defaults | grep '= undef'"
  assert_success
}

# TODO: Unclear why some of these ENV are relevant for the test?
@test "Docker env variables are set correctly (custom)" {
  export CONTAINER_NAME=${CONTAINER2_NAME}

  local CUSTOM_SETUP_ARGUMENTS=(
    --env ENABLE_CLAMAV=1
    --env SPOOF_PROTECTION=1
    --env ENABLE_SPAMASSASSIN=1
    --env REPORT_RECIPIENT=user1@localhost.localdomain
    --env REPORT_SENDER=report1@mail.my-domain.com
    --env SA_TAG=-5.0
    --env SA_TAG2=2.0
    --env SA_KILL=3.0
    --env SA_SPAM_SUBJECT="SPAM: "
    --env VIRUSMAILS_DELETE_DELAY=7
    --env ENABLE_SRS=1
    --env ENABLE_MANAGESIEVE=1
    --env PERMIT_DOCKER=host
    # NOTE: ulimit required for `ENABLE_SRS=1` until running a newer `postsrsd`
    --ulimit "nofile=$(ulimit -Sn):$(ulimit -Hn)"
  )
  _init_with_defaults
  _common_container_setup 'CUSTOM_SETUP_ARGUMENTS'

  _run_in_container_bash "grep '\$sa_tag_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= -5.0'"
  assert_success

  _run_in_container_bash "grep '\$sa_tag2_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 2.0'"
  assert_success

  _run_in_container_bash "grep '\$sa_kill_level_deflt' /etc/amavis/conf.d/20-debian_defaults | grep '= 3.0'"
  assert_success

  _run_in_container_bash "grep '\$sa_spam_subject_tag' /etc/amavis/conf.d/20-debian_defaults | grep '= .SPAM: .'"
  assert_success
}
