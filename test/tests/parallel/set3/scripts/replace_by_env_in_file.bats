load "${REPOSITORY_ROOT}/test/helper/common"
source "${REPOSITORY_ROOT}/target/scripts/helpers/log.sh"
source "${REPOSITORY_ROOT}/target/scripts/helpers/utils.sh"

BATS_TEST_NAME_PREFIX='[Helper function] (_replace_by_env_in_file) '

function setup_file() {
  export TMP_CONFIG_FILE=$(mktemp)
  cp "${REPOSITORY_ROOT}/test/test-files/replace_by_env_in_file.conf" "${TMP_CONFIG_FILE}"
}

function teardown_file() { rm "${TMP_CONFIG_FILE}" ; }

@test "substitute key-value pair (01) (simple)" {
  export TEST_KEY_1='new_value_1'
  _do_work "key_1 = ${TEST_KEY_1}"
}

@test "substitute key-value pair (02) (complex 1)" {
  export TEST_KEY_1='(&(objectClass=PostfixBookMailAccount)(|(uniqueIdentifier=%n)(mail=%u)))'
  _do_work "key_1 = ${TEST_KEY_1}"
}

@test "substitute key-value pair (03) (complex 2)" {
  export TEST_KEY_1="*+=/_-%&"
  _do_work "key_1 = ${TEST_KEY_1}"
}

@test "substitute key-value pair (04) (complex 3)" {
  export TEST_KEY_1='(&(objectClass=mailAccount)(uid=%n))'
  _do_work "key_1 = ${TEST_KEY_1}"
}

@test "substitute key-value pair (05) (complex 4)" {
  export TEST_KEY_1='=home=/var/mail/%{ldap:mail}, =mail=maildir:/var/mail/%{ldap:mail}/Maildir'
  _do_work "key_1 = ${TEST_KEY_1}"
}

@test "substitute key-value pair (06) (complex 5)" {
  export TEST_KEY_1='(&(objectClass=mailAccount)(uid=%n))'
  _do_work "key_1 = ${TEST_KEY_1}"
}

@test "substitute key-value pair (07) (complex 6)" {
  export TEST_KEY_1='uid=user,userPassword=password'
  _do_work "key_1 = ${TEST_KEY_1}"
}

@test "substitute key-value pair (08) (no value in file)" {
  export TEST_KEY_2='new_value_2'
  _do_work "key_2 = ${TEST_KEY_2}"
}

@test "substitute key-value pair (09) (no space at value)" {
  export TEST_KEY_3='new_value_3'
  _do_work "key_3 = ${TEST_KEY_3}"
}

@test "substitute key-value pair (10) (no space at key)" {
  export TEST_KEY_4="new_value_4"
  _do_work "key_4 = ${TEST_KEY_4}"
}

@test "substitute key-value pair (11) (no space at key and value)" {
  export TEST_KEY_5="new_value_5"
  _do_work "key_5 = ${TEST_KEY_5}"
}

@test "substitute key-value pair (12) (no value of variable)" {
  export TEST_KEY_6=
  _do_work "key_6 ="
  run grep -q -F "key_6 = " "${TMP_CONFIG_FILE}"
  assert_failure
}

function _do_work() {
  local FILTER_STRING=${1:?No string to filter by was provided}
  run _replace_by_env_in_file 'TEST_' "${TMP_CONFIG_FILE}"
  assert_success
  run grep -q -F "${FILTER_STRING}" "${TMP_CONFIG_FILE}"
  assert_success
}
