#! /bin/bash

function _escape
{
  echo "${1//./\\.}"
}
export -f _escape

# Check if string input is an empty line, only whitespaces
# or `#` as the first non-whitespace character.
function _is_comment
{
  grep -q -E "^\s*$|^\s*#" <<< "${1}"
}
export -f _is_comment
