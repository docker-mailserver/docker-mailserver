load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

@test "checking spamassassin: docker env variables are set correctly (custom)" {
  run docker exec mail_undef_spam_subject /bin/sh -c "grep '\$sa_spam_subject_tag' /etc/amavis/conf.d/20-debian_defaults | grep '= undef'"
  assert_success
}



