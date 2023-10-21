#!/bin/bash

# Set up MTA-STS

function _setup_mta_sts() {
  _log 'trace' 'Adding MTA-STS lookup to the Postfix TLS policy map'
  postconf 'smtp_tls_policy_maps = socketmap:inet:127.0.0.1:8461:postfix'
}
