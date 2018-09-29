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
      exit
    fi
  done
}

# testsum checks each file for changes.
# If a file is not found, the script exits with a log message.
# The return value of the function is equal to the number of changed files.
# NB: the array is not updated!
function testsum {
  changed=0
  for var in "${!sslmap[@]}"; do
    if [ -f ${var} ]; then
      if [ "$(sha512sum ${var})" != "${sslmap[${var}]}" ]; then
        # log File changed: ${var}
        changed=$((changed+1))
      fi
    else
      log No such file at ${var}!
      exit
    fi
  done
  return ${changed}
}

# ---

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
