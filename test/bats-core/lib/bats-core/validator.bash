#!/usr/bin/env bash

bats_test_count_validator() {
  header_pattern='[0-9]+\.\.[0-9]+'
  IFS= read -r header
  # repeat the header
  printf "%s\n" "$header"

  # if we detect a TAP plan
  if [[ "$header" =~ $header_pattern ]]; then
    # extract the number of tests ...
    local expected_number_of_tests="${header:3}"
    # ... count the actual number of [not ] oks...
    local actual_number_of_tests=0
    while IFS= read -r line; do
        # forward line
        printf "%s\n" "$line"
        case "$line" in
        'ok '*)
        (( ++actual_number_of_tests ))
        ;;
        'not ok'*)
        (( ++actual_number_of_tests ))
        ;;
        esac
    done
    # ... and error if they are not the same
    if [[ "${actual_number_of_tests}" != "${expected_number_of_tests}" ]]; then
        printf '# bats warning: Executed %s instead of expected %s tests\n' "$actual_number_of_tests" "$expected_number_of_tests"
        return 1
    fi
  else
    # forward output unchanged
    cat
  fi
}