#!/usr/bin/env bats

load test_helper
fixtures junit-formatter

FLOAT_REGEX='[0-9]+(\.[0-9]+)?'
TIMESTAMP_REGEX='[0-9]+-[0-1][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]'
TESTSUITES_REGEX="<testsuites time=\"$FLOAT_REGEX\">"

@test "junit formatter with skipped test does not fail" {
  run bats --formatter junit "$FIXTURE_ROOT/skipped.bats"
  echo "$output"
  [[ $status -eq 0 ]]
  [[ "${lines[0]}" == '<?xml version="1.0" encoding="UTF-8"?>' ]]
  
  [[ "${lines[1]}" =~ $TESTSUITES_REGEX ]]

  TESTSUITE_REGEX="<testsuite name=\"skipped.bats\" tests=\"2\" failures=\"0\" errors=\"0\" skipped=\"2\" time=\"$FLOAT_REGEX\" timestamp=\"$TIMESTAMP_REGEX\" hostname=\".*\">"
  echo "TESTSUITE_REGEX='$TESTSUITE_REGEX'"
  [[ "${lines[2]}" =~ $TESTSUITE_REGEX ]]

  TESTCASE_REGEX="<testcase classname=\"skipped.bats\" name=\"a skipped test\" time=\"$FLOAT_REGEX\">"
  [[ "${lines[3]}" =~ $TESTCASE_REGEX ]]

  [[ "${lines[4]}" == *"<skipped></skipped>"* ]]
  [[ "${lines[5]}" == *"</testcase>"* ]]

  TESTCASE_REGEX="<testcase classname=\"skipped.bats\" name=\"a skipped test with a reason\" time=\"$FLOAT_REGEX\">"
  [[ "${lines[6]}" =~ $TESTCASE_REGEX ]]
  [[ "${lines[7]}" == *"<skipped>a reason</skipped>"* ]]
  [[ "${lines[8]}" == *"</testcase>"* ]]
  
  [[ "${lines[9]}" == *"</testsuite>"* ]]
  [[ "${lines[10]}" == *"</testsuites>"* ]]
}

@test "junit formatter: escapes xml special chars" {
  make_bats_test_suite_tmpdir
  case $OSTYPE in
    linux*|darwin)
      # their CI can handle special chars on filename
      TEST_FILE_NAME="xml-escape-\"<>'&.bats"
      ESCAPED_TEST_FILE_NAME="xml-escape-&quot;&lt;&gt;&#39;&amp;.bats"
      TEST_FILE_PATH="$BATS_TEST_SUITE_TMPDIR/$TEST_FILE_NAME"
      cp "$FIXTURE_ROOT/xml-escape.bats" "$TEST_FILE_PATH"
    ;;
    *)
      # use the filename without special chars
      TEST_FILE_NAME="xml-escape.bats"
      ESCAPED_TEST_FILE_NAME="$TEST_FILE_NAME"
      TEST_FILE_PATH="$FIXTURE_ROOT/$TEST_FILE_NAME"
    ;;
  esac
  run bats --formatter junit "$TEST_FILE_PATH"

  echo "$output"
  [[ "${lines[2]}" == "<testsuite name=\"$ESCAPED_TEST_FILE_NAME\" tests=\"3\" failures=\"1\" errors=\"0\" skipped=\"1\" time=\""*"\" timestamp=\""*"\" hostname=\""*"\">" ]]
  [[ "${lines[3]}" == "    <testcase classname=\"$ESCAPED_TEST_FILE_NAME\" name=\"Successful test with escape characters: &quot;&#39;&lt;&gt;&amp;&#27;[0m (0x1b)\" time=\""*"\" />" ]]
  [[ "${lines[4]}" == "    <testcase classname=\"$ESCAPED_TEST_FILE_NAME\" name=\"Failed test with escape characters: &quot;&#39;&lt;&gt;&amp;&#27;[0m (0x1b)\" "* ]]
  [[ "${lines[5]}" == '        <failure type="failure">(in test file '*"$ESCAPED_TEST_FILE_NAME, line 6)" ]]
  [[ "${lines[6]}" == '  `echo &quot;&lt;&gt;&#39;&amp;&#27;[0m&quot; &amp;&amp; false&#39; failed'* ]]
  [[ "${lines[9]}" == "    <testcase classname=\"$ESCAPED_TEST_FILE_NAME\" name=\"Skipped test with escape characters: &quot;&#39;&lt;&gt;&amp;&#27;[0m (0x1b)\" time=\""*"\">" ]]
  [[ "${lines[10]}" == "        <skipped>&quot;&#39;&lt;&gt;&amp;&#27;[0m</skipped>" ]]
}

@test "junit formatter: test suites" {
  run bats --formatter junit "$FIXTURE_ROOT/suite/"
  echo "$output"

  [[ "${lines[0]}" == '<?xml version="1.0" encoding="UTF-8"?>' ]]
  [[ "${lines[1]}" == *"<testsuites "* ]]
  [[ "${lines[2]}" == *"<testsuite name=\"file1.bats\""* ]]
  [[ "${lines[3]}" == *"<testcase "* ]]
  [[ "${lines[4]}" == *"</testsuite>"* ]]
  [[ "${lines[5]}" == *"<testsuite name=\"file2.bats\""* ]]
  [[ "${lines[6]}" == *"<testcase"* ]]
  [[ "${lines[7]}" == *"</testsuite>"* ]]
  [[ "${lines[8]}" == *"</testsuites>"* ]]
}

@test "junit formatter: test suites relative path" {
  cd "$FIXTURE_ROOT"
  run bats --formatter junit "suite/"
  echo "$output"

  [[ "${lines[0]}" == '<?xml version="1.0" encoding="UTF-8"?>' ]]
  [[ "${lines[1]}" == *"<testsuites "* ]]
  [[ "${lines[2]}" == *"<testsuite name=\"file1.bats\""* ]]
  [[ "${lines[3]}" == *"<testcase "* ]]
  [[ "${lines[4]}" == *"</testsuite>"* ]]
  [[ "${lines[5]}" == *"<testsuite name=\"file2.bats\""* ]]
  [[ "${lines[6]}" == *"<testcase"* ]]
  [[ "${lines[7]}" == *"</testsuite>"* ]]
  [[ "${lines[8]}" == *"</testsuites>"* ]]
}

@test "junit formatter: files with the same name are distinguishable" {
  run bats --formatter junit -r "$FIXTURE_ROOT/duplicate/"
  echo "$output"

  [[ "${lines[2]}" == *"<testsuite name=\"first/file1.bats\""* ]]
  [[ "${lines[5]}" == *"<testsuite name=\"second/file1.bats\""* ]]
}

@test "junit formatter as report formatter creates report.xml" {
  make_bats_test_suite_tmpdir
  cd "$BATS_TEST_SUITE_TMPDIR" # don't litter sources with output files
  run bats --report-formatter junit "$FIXTURE_ROOT/suite/"
  echo "$output"
  [[ -e "report.xml" ]]
  run cat "report.xml"
  echo "$output"
  [[ "${lines[2]}" == *"<testsuite name=\"file1.bats\" tests=\"1\" failures=\"0\" errors=\"0\" skipped=\"0\""* ]]
  [[ "${lines[5]}" == *"<testsuite name=\"file2.bats\" tests=\"1\" failures=\"0\" errors=\"0\" skipped=\"0\""* ]]
}

@test "junit does not mark tests with FD 3 output as failed (issue #360)" {
  run bats --formatter junit "$FIXTURE_ROOT/issue_360.bats"

  echo "$output"

  [[ "${lines[2]}" == '<testsuite name="issue_360.bats" '*'>' ]]
  [[ "${lines[3]}" == '    <testcase classname="issue_360.bats" '*'>' ]]
  # only the outputs on FD3 should be visible on a successful test
  [[ "${lines[4]}" == '        <system-out>setup FD3' ]]
  [[ "${lines[5]}" == 'hello Bilbo' ]]
  [[ "${lines[6]}" == 'teardown FD3</system-out>' ]]
  [[ "${lines[7]}" == '    </testcase>' ]]
  [[ "${lines[8]}" == '    <testcase classname="issue_360.bats" name="fail to say hello to Biblo" time="'*'">' ]]
  # a failed test should show FD3 output first ...
  [[ "${lines[9]}" == '        <system-out>setup FD3' ]]
  [[ "${lines[10]}" == 'hello Bilbo' ]]
  [[ "${lines[11]}" == 'teardown FD3</system-out>' ]]
  [[ "${lines[12]}" == '        <failure type="failure">(in test file '*'test/fixtures/junit-formatter/issue_360.bats, line 21)' ]]
  [[ "${lines[13]}" == '  `false&#39; failed' ]]
  # ... and then the stdout output
  [[ "${lines[14]}" == '# setup stdout' ]]
  [[ "${lines[15]}" == '# hello stdout' ]]
  [[ "${lines[16]}" == '# teardown stdout</failure>' ]]
  [[ "${lines[17]}" == '    </testcase>' ]]
  [[ "${lines[18]}" == '</testsuite>' ]]
}