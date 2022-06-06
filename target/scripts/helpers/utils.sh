#! /bin/bash

function _escape
{
  echo "${1//./\\.}"
}

# Returns input after filtering out lines that are:
# empty, white-space, comments (`#` as the first non-whitespace character)
function _filter_to_valid_lines
{
  grep --extended-regexp --invert-match "^\s*$|^\s*#" "${1}" || true
}

# TODO: Only used by `relay.sh`, will be removed in future.
# Similar to _filter_to_valid_lines, but only returns a status code
# to indicate invalid line(s):
function _is_comment
{
  grep -q -E "^\s*$|^\s*#" <<< "${1}"
}

# Provide the name of an environment variable to this function
# and it will return its value stored in /etc/dms-settings
function _get_dms_env_value
{
  local VALUE
  VALUE=$(grep "^${1}=" /etc/dms-settings | cut -d '=' -f 2)
  printf '%s' "${VALUE:1:-1}"
}
