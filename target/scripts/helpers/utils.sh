#! /bin/bash

function _escape
{
  echo "${1//./\\.}"
}

# Check if string input is an empty line, only whitespaces
# or `#` as the first non-whitespace character.
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
