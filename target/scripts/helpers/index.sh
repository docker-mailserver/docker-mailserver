#!/bin/bash

# shellcheck source-path=target/scripts/helpers
# This file serves as a single import for all helpers

function _import_scripts() {
  local PATH_TO_SCRIPTS='/usr/local/bin/helpers'

  source "${PATH_TO_SCRIPTS}/accounts.sh"
  source "${PATH_TO_SCRIPTS}/aliases.sh"
  source "${PATH_TO_SCRIPTS}/change-detection.sh"
  source "${PATH_TO_SCRIPTS}/dns.sh"
  source "${PATH_TO_SCRIPTS}/error.sh"
  source "${PATH_TO_SCRIPTS}/lock.sh"
  source "${PATH_TO_SCRIPTS}/log.sh"
  source "${PATH_TO_SCRIPTS}/network.sh"
  source "${PATH_TO_SCRIPTS}/postfix.sh"
  source "${PATH_TO_SCRIPTS}/relay.sh"
  source "${PATH_TO_SCRIPTS}/ssl.sh"
  source "${PATH_TO_SCRIPTS}/utils.sh"

  source "${PATH_TO_SCRIPTS}/database/db.sh"
}

_import_scripts
