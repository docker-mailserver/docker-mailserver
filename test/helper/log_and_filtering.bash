#!/bin/bash

# ? ABOUT: Functions defined here aid in working with logs and filtering them.

# ! ATTENTION: This file is loaded by `common.sh` - do not load it yourself!
# ! ATTENTION: This file requires helper functions from `common.sh`!

# shellcheck disable=SC2034,SC2155

# Assert that the number of lines output by a previous command matches the given
# amount (${1}). `lines` is a special BATS variable updated via `run`.
#
# @param ${1} = number of lines that the output should have
function _should_output_number_of_lines() {
  # shellcheck disable=SC2154
  assert_equal "${#lines[@]}" "${1:?Number of lines not provided}"
}

# Filters a service's logs (under `/var/log/supervisor/<SERVICE>.log`) given
# a specific string.
#
# @param ${1} = service name
# @param ${2} = string to filter by
# @param ${3} = container name [OPTIONAL]
#
# ## Attention
#
# The string given to this function is interpreted by `grep -E`, i.e.
# as a regular expression. In case you use characters that are special
# in regular expressions, you need to escape them!
function _filter_service_log() {
  local SERVICE=${1:?Service name must be provided}
  local STRING=${2:?String to match must be provided}
  local CONTAINER_NAME=$(__handle_container_name "${3:-}")
  local FILE="/var/log/supervisor/${SERVICE}.log"

  # Fallback to alternative log location:
  [[ -f ${FILE} ]] || FILE="/var/log/mail/${SERVICE}.log"
  _run_in_container grep -E "${STRING}" "${FILE}"
}

# Like `_filter_service_log` but asserts that the string was found.
#
# @param ${1} = service name
# @param ${2} = string to filter by
# @param ${3} = container name [OPTIONAL]
#
# ## Attention
#
# The string given to this function is interpreted by `grep -E`, i.e.
# as a regular expression. In case you use characters that are special
# in regular expressions, you need to escape them!
function _service_log_should_contain_string() {
  local SERVICE=${1:?Service name must be provided}
  local STRING=${2:?String to match must be provided}
  local CONTAINER_NAME=$(__handle_container_name "${3:-}")

  _filter_service_log "${SERVICE}" "${STRING}"
  assert_success
}
