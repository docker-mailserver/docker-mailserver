#!/usr/bin/env bash

function log {
  echo "[$(date --rfc-3339=seconds)] $*"
}

# sslmap is an associative array.
# Keys are filenames, values are checksums.
declare -A sslmap

# gensum takes a list of filenames as arguments.
# The function populates the associative array with checksums.
# If any file is not found, the script exits with a log message.
function gensum {
  for var in "$@"; do
    if [ -f ${var} ]; then
      sslmap[${var}]=$(sha512sum ${var})
    else
      log No such file at ${var}!
      exit -1
    fi
  done
}

# testsum checks each file for changes.
# If a file is not found, the script exits with a log message.
# The return value of the function is equal to the number of changed files.
# NB: the array is updated!
function testsum {
  changed=0
  for var in "${!sslmap[@]}"; do
    if [ -f ${var} ]; then
      newsum=$(sha512sum ${var})
      if [ "$newsum" != "${sslmap[${var}]}" ]; then
        # log File changed: ${var}
        changed=$((changed+1))
        sslmap[${var}]=$newsum
      fi
    else
      log No such file at ${var}!
      exit -1
    fi
  done
  return ${changed}
}

# This function tests gensum and testsum.
function test_script {
  failed=""
  passed=""

  # 1. No test file, so gensum should exit.
  rm -f testme
  (gensum testme >/dev/null && failed+=" 1") || passed+=" 1"

  # Create test file.
  ls > testme
  gensum testme

  # 2. Unchanged file, testsum should return 0.
  testsum
  testsumresult=$?
  if [ $testsumresult -ne 0 ]; then
    failed+=" 2"
  else
    passed+=" 2"
  fi

  # Change file.
  ls >> testme

  # 3. Changed file should not return 0.
  testsum
  testsumresult=$?
  if [ $testsumresult -eq 0 ]; then
    failed+=" 3"
  else
    passed+=" 3"
  fi

  # 4. Array should have been updated in previous run, so should return 0.
  testsum
  testsumresult=$?
  if [ $testsumresult -ne 0 ]; then
    failed+=" 4"
  else
    passed+=" 4"
  fi

  # Remove test file.
  rm testme

  # 5. No file found should exit.
  (testsum >/dev/null && failed+=" 5") || passed+=" 5"

  # All tests must pass!
  if [[ "$failed" = "" && "$passed" = " 1 2 3 4 5" ]]; then
    exit 0
  else
    echo "Tests passed: $passed, failed: $failed"
    exit 1
  fi
}

# ---

# Test by passing "test" as first argument.
if [[ ! -z "$1" && "$1" = "test" ]]; then
  test_script
fi

# Populate array with SSL files.
gensum ${SSL_CERT_PATH} ${SSL_KEY_PATH}

# Run forever.
while true; do

  # Test files for changes.
  testsum
  testsumresult=$?
  if [ $testsumresult -ne 0 ]; then
    log SSL files changed, restarting Postfix and Dovecot
    supervisorctl restart postfix
    supervisorctl restart dovecot
  fi

  # Try again soon!
  sleep 1
done
