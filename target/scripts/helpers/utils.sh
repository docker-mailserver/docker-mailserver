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

# This function parses `/root/.bashrc` and "extracts" the environment
# variables by making them available to the current shell. After the
# call, you can work with the environment variables previously defined
# in `/root/.bashrc` as if you defined them yourself. Note that the
# file `/root/.bashrc` itself is not altered when you alter one of the
# parsed environment variables.
function _get_dms_environment_variables
{
  local LINE

  while read -r LINE
  do
    if grep -qE "^export [A-Z_]+='.*'$" <<< "${LINE}"
    then
      eval "${LINE}"
    fi
  done < /root/.bashrc
}
