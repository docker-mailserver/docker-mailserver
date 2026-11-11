#!/bin/bash

function _setup_mailname() {
  _log 'debug' "Setting up mailname and creating '/etc/mailname'"
  echo "${DOMAINNAME}" >/etc/mailname
}

# Prints the IPv4 or IPv6 address / network given as `${1}` as a CIDR range in the text form that OpenDKIM and
# OpenDMARC match client addresses against (lower case, compressed IPv6, host bits masked), e.g. `2001:DB8:0::5/32`
# becomes `2001:db8::/32`. Fails for anything else. The regex keeps out IPv6 zone IDs, which `ipaddress` accepts.
function __trusted_networks__normalize() {
  [[ ${1} =~ ^[[:xdigit:]:.]+(/[[:digit:]]+)?$ ]] || return 1
  python3 -c '
import ipaddress, sys
print(ipaddress.ip_network(sys.argv[1], strict=False))
' "${1}" 2>/dev/null
}

# Makes the OpenDKIM and OpenDMARC milters treat clients in the network `${1}` (CIDR, no brackets) as trusted.
function __trusted_networks__add_to_milters() {
  if [[ ${ENABLE_OPENDMARC} -eq 1 ]]; then echo "${1}" >>/etc/opendmarc/ignore.hosts; fi
  if [[ ${ENABLE_OPENDKIM} -eq 1 ]]; then echo "${1}" >>/etc/opendkim/TrustedHosts; fi
}

# Postfix `mynetworks` defines the clients that are allowed to relay without authentication.
# ref: https://www.postfix.org/postconf.5.html#mynetworks
function _setup_trusted_networks() {
  _log 'debug' "Setting up trusted networks (DMS_TRUSTED_NETWORKS='${DMS_TRUSTED_NETWORKS}')"

  local ENTRY NETWORK
  local -a NETWORKS=()

  case "${DMS_TRUSTED_NETWORKS}" in
    ( 'none' )
      _log 'trace' "Clearing Postfix's 'mynetworks'"
      postconf 'mynetworks ='
      ;;

    ( 'host' | 'subnet' )
      _log 'trace' "Letting Postfix derive 'mynetworks' from the interface addresses (mynetworks_style=${DMS_TRUSTED_NETWORKS})"
      _adjust_mtime_for_postfix_maincf
      postconf -X mynetworks
      postconf "mynetworks_style = ${DMS_TRUSTED_NETWORKS}"

      # The warnings (e.g. IPv6 being unavailable) are not relevant here, Postfix repeats them when it starts.
      read -r -a NETWORKS < <(postconf -h mynetworks 2>/dev/null)
      for ENTRY in "${NETWORKS[@]}"; do
        if NETWORK=$(__trusted_networks__normalize "${ENTRY//[\[\]]/}"); then
          __trusted_networks__add_to_milters "${NETWORK}"
        else
          _log 'warn' "Trusted network '${ENTRY}' (derived by Postfix) is not understood and was not added to OpenDKIM / OpenDMARC"
        fi
      done
      ;;

    ( * ) # A list of CIDR ranges, separated by spaces and / or commas. The ranges extend Postfix's default `mynetworks`.
      local POSTFIX_MYNETWORKS
      POSTFIX_MYNETWORKS=$(postconf -h mynetworks)

      local -a ENTRIES
      IFS=', ' read -r -a ENTRIES <<< "${DMS_TRUSTED_NETWORKS}"
      for ENTRY in "${ENTRIES[@]}"; do
        [[ -z ${ENTRY} ]] && continue
        NETWORK=$(__trusted_networks__normalize "${ENTRY}") || _dms_panic__invalid_value "DMS_TRUSTED_NETWORKS ('${ENTRY}' is neither 'none', 'host', 'subnet' nor a CIDR range)" 'Network Setup [trusted_networks]'

        NETWORKS+=("${NETWORK}")
        # Postfix expects IPv6 addresses in square brackets:
        if [[ ${NETWORK} == *:* ]]; then
          POSTFIX_MYNETWORKS+=" [${NETWORK%/*}]/${NETWORK#*/}"
        else
          POSTFIX_MYNETWORKS+=" ${NETWORK}"
        fi
      done

      [[ ${#NETWORKS[@]} -eq 0 ]] && _dms_panic__invalid_value "DMS_TRUSTED_NETWORKS ('${DMS_TRUSTED_NETWORKS}' contains no CIDR range)" 'Network Setup [trusted_networks]'

      _log 'trace' "Adding '${NETWORKS[*]}' to Postfix 'main.cf:mynetworks'"
      _adjust_mtime_for_postfix_maincf
      postconf "mynetworks = ${POSTFIX_MYNETWORKS}"
      for NETWORK in "${NETWORKS[@]}"; do
        __trusted_networks__add_to_milters "${NETWORK}"
      done
      ;;
  esac
}
