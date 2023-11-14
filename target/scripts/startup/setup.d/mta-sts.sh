#!/bin/bash


function _setup_mta_sts() {
  _log 'trace' 'Adding MTA-STS lookup to the Postfix TLS policy map'
  _add_to_or_update_postfix_main smtp_tls_policy_maps 'socketmap:unix:/var/run/mta-sts/daemon.sock:postfix'
}
