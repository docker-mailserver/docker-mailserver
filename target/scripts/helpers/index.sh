#! /bin/bash

# shellcheck source-path=target/scripts/helpers
# This file serves as a single import for all helpers

export CHKSUM_FILE=/tmp/docker-mailserver-config-chksum

function _import_scripts
{
  local PATH_TO_SCRIPTS='/usr/local/bin/helpers'

  source "${PATH_TO_SCRIPTS}/accounts.sh"
  source "${PATH_TO_SCRIPTS}/aliases.sh"
  source "${PATH_TO_SCRIPTS}/dns.sh"
  source "${PATH_TO_SCRIPTS}/exit.sh"
  source "${PATH_TO_SCRIPTS}/log.sh"
  source "${PATH_TO_SCRIPTS}/miscellaneous.sh"
  source "${PATH_TO_SCRIPTS}/postfix.sh"
  source "${PATH_TO_SCRIPTS}/relay.sh"
  source "${PATH_TO_SCRIPTS}/sasl.sh"
  source "${PATH_TO_SCRIPTS}/ssl.sh"
  source "${PATH_TO_SCRIPTS}/tcp_ip.sh"
}

_import_scripts
