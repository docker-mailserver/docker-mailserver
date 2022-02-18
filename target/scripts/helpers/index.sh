#! /bin/bash
# shellcheck source-path=target/scripts/helpers
# This file serves as a single import for all helpers

function _import_scripts
{
  local PATH_TO_SCRIPTS='/usr/local/bin/helpers'

  . "${PATH_TO_SCRIPTS}/postfix.sh"
  . "${PATH_TO_SCRIPTS}/accounts.sh"
  . "${PATH_TO_SCRIPTS}/aliases.sh"
  . "${PATH_TO_SCRIPTS}/relay.sh"
  . "${PATH_TO_SCRIPTS}/sasl.sh"
  . "${PATH_TO_SCRIPTS}/ssl.sh"
}
_import_scripts
