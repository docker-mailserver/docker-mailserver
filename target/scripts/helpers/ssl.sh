#!/bin/bash

function _setup_dhparam() {
  local DH_SERVICE=$1
  local DH_DEST=$2
  local DH_CUSTOM='/tmp/docker-mailserver/dhparams.pem'

  _log 'debug' "Setting up ${DH_SERVICE} dhparam"

  if [[ -f ${DH_CUSTOM} ]]; then # use custom supplied dh params (assumes they're probably insecure)
    _log 'trace' "${DH_SERVICE} will use custom provided DH paramters"
    _log 'warn' "Using self-generated dhparams is considered insecure - unless you know what you are doing, please remove '${DH_CUSTOM}'"

    cp -f "${DH_CUSTOM}" "${DH_DEST}"
  else # use official standardized dh params (provided via Dockerfile)
    _log 'trace' "${DH_SERVICE} will use official standardized DH parameters (ffdhe4096)."
  fi
}

function _setup_ssl() {
  _log 'debug' 'Setting up SSL'

  local POSTFIX_CONFIG_MAIN='/etc/postfix/main.cf'
  local POSTFIX_CONFIG_MASTER='/etc/postfix/master.cf'
  local DOVECOT_CONFIG_SSL='/etc/dovecot/conf.d/10-ssl.conf'

  local TMP_DMS_TLS_PATH='/tmp/docker-mailserver/ssl' # config volume
  local DMS_TLS_PATH='/etc/dms/tls'
  mkdir -p "${DMS_TLS_PATH}"

  # Primary certificate to serve for TLS
  function _set_certificate() {
    local POSTFIX_KEY_WITH_FULLCHAIN=${1}
    local DOVECOT_KEY=${1}
    local DOVECOT_CERT=${1}

    # If a 2nd param is provided, a separate key and cert was received instead of a fullkeychain
    if [[ -n ${2} ]]; then
      local PRIVATE_KEY=$1
      local CERT_CHAIN=$2

      POSTFIX_KEY_WITH_FULLCHAIN="${PRIVATE_KEY} ${CERT_CHAIN}"
      DOVECOT_KEY="${PRIVATE_KEY}"
      DOVECOT_CERT="${CERT_CHAIN}"
    fi

    # Postfix configuration
    # NOTE: `smtpd_tls_chain_files` expects private key defined before public cert chain
    # Value can be a single PEM file, or a sequence of files; so long as the order is key->leaf->chain
    sedfile -i -r "s|^(smtpd_tls_chain_files =).*|\1 ${POSTFIX_KEY_WITH_FULLCHAIN}|" "${POSTFIX_CONFIG_MAIN}"

    # Dovecot configuration
    sedfile -i -r \
      -e "s|^(ssl_key =).*|\1 <${DOVECOT_KEY}|" \
      -e "s|^(ssl_cert =).*|\1 <${DOVECOT_CERT}|" \
      "${DOVECOT_CONFIG_SSL}"
  }

  # Enables supporting two certificate types such as ECDSA with an RSA fallback
  function _set_alt_certificate() {
    local COPY_KEY_FROM_PATH=$1
    local COPY_CERT_FROM_PATH=$2
    local PRIVATE_KEY_ALT="${DMS_TLS_PATH}/fallback_key"
    local CERT_CHAIN_ALT="${DMS_TLS_PATH}/fallback_cert"

    cp "${COPY_KEY_FROM_PATH}" "${PRIVATE_KEY_ALT}"
    cp "${COPY_CERT_FROM_PATH}" "${CERT_CHAIN_ALT}"
    chmod 600 "${PRIVATE_KEY_ALT}"
    chmod 644 "${CERT_CHAIN_ALT}"

    # Postfix configuration
    # NOTE: This operation doesn't replace the line, it appends to the end of the line.
    # Thus this method should only be used when this line has explicitly been replaced earlier in the script.
    # Otherwise without `docker compose down` first, a `docker compose up` may
    # persist previous container state and cause a failure in postfix configuration.
    sedfile -i "s|^smtpd_tls_chain_files =.*|& ${PRIVATE_KEY_ALT} ${CERT_CHAIN_ALT}|" "${POSTFIX_CONFIG_MAIN}"

    # Dovecot configuration
    # Conditionally checks for `#`, in the event that internal container state is accidentally persisted,
    # can be caused by: `docker compose up` run again after a `ctrl+c`, without running `docker compose down`
    sedfile -i -r \
      -e "s|^#?(ssl_alt_key =).*|\1 <${PRIVATE_KEY_ALT}|" \
      -e "s|^#?(ssl_alt_cert =).*|\1 <${CERT_CHAIN_ALT}|" \
      "${DOVECOT_CONFIG_SSL}"
  }

  function _apply_tls_level() {
    local TLS_CIPHERS_ALLOW=$1
    local TLS_PROTOCOL_IGNORE=$2
    local TLS_PROTOCOL_MINIMUM=$3

    # Postfix configuration
    sed -i -r \
      -e "s|^(smtpd?_tls_mandatory_protocols =).*|\1 ${TLS_PROTOCOL_IGNORE}|" \
      -e "s|^(smtpd?_tls_protocols =).*|\1 ${TLS_PROTOCOL_IGNORE}|" \
      -e "s|^(tls_high_cipherlist =).*|\1 ${TLS_CIPHERS_ALLOW}|" \
      "${POSTFIX_CONFIG_MAIN}"

    # Dovecot configuration (secure by default though)
    sed -i -r \
      -e "s|^(ssl_min_protocol =).*|\1 ${TLS_PROTOCOL_MINIMUM}|" \
      -e "s|^(ssl_cipher_list =).*|\1 ${TLS_CIPHERS_ALLOW}|" \
      "${DOVECOT_CONFIG_SSL}"
  }

  # 2020 feature intended for Traefik v2 support only:
  # https://github.com/docker-mailserver/docker-mailserver/pull/1553
  # Extracts files `key.pem` and `fullchain.pem`.
  # `_extract_certs_from_acme` is located in `helpers/ssl.sh`
  # NOTE: See the `SSL_TYPE=letsencrypt` case below for more details.
  function _traefik_support() {
    if [[ -f /etc/letsencrypt/acme.json ]]; then
      # Variable only intended for troubleshooting via debug output
      local EXTRACTED_DOMAIN

      # Conditional handling depends on the success of `_extract_certs_from_acme`,
      # Failure tries the next fallback FQDN to try extract a certificate from.
      # Subshell not used in conditional to ensure extraction log output is still captured
      if [[ -n ${SSL_DOMAIN} ]] && _extract_certs_from_acme "${SSL_DOMAIN}"; then
        EXTRACTED_DOMAIN=('SSL_DOMAIN' "${SSL_DOMAIN}")
      elif _extract_certs_from_acme "${HOSTNAME}"; then
        EXTRACTED_DOMAIN=('HOSTNAME' "${HOSTNAME}")
      elif _extract_certs_from_acme "${DOMAINNAME}"; then
        EXTRACTED_DOMAIN=('DOMAINNAME' "${DOMAINNAME}")
      else
        _log 'warn' "letsencrypt (acme.json) failed to identify a certificate to extract"
      fi

      _log 'trace' "letsencrypt (acme.json) extracted certificate using ${EXTRACTED_DOMAIN[0]}: '${EXTRACTED_DOMAIN[1]}'"
    fi
  }

  # TLS strength/level configuration
  case "${TLS_LEVEL}" in
    ( "modern" )
      local TLS_MODERN_SUITE='ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384'
      local TLS_MODERN_IGNORE='!SSLv2,!SSLv3,!TLSv1,!TLSv1.1'
      local TLS_MODERN_MIN='TLSv1.2'

      _apply_tls_level "${TLS_MODERN_SUITE}" "${TLS_MODERN_IGNORE}" "${TLS_MODERN_MIN}"

      _log 'debug' "TLS configured with 'modern' ciphers"
      ;;

    ( "intermediate" )
      local TLS_INTERMEDIATE_SUITE='ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA256'
      local TLS_INTERMEDIATE_IGNORE='!SSLv2,!SSLv3,!TLSv1,!TLSv1.1'
      local TLS_INTERMEDIATE_MIN='TLSv1.2'

      _apply_tls_level "${TLS_INTERMEDIATE_SUITE}" "${TLS_INTERMEDIATE_IGNORE}" "${TLS_INTERMEDIATE_MIN}"

      _log 'debug' "TLS configured with 'intermediate' ciphers"
      ;;

    ( * )
      _log 'warn' "TLS_LEVEL '${TLS_LEVEL}' not valid"
      ;;

  esac

  local SCOPE_SSL_TYPE="TLS Setup [SSL_TYPE=${SSL_TYPE}]"
  # SSL certificate Configuration
  # TODO: Refactor this feature, it's been extended multiple times for specific inputs/providers unnecessarily.
  # NOTE: Some `SSL_TYPE` logic uses mounted certs/keys directly, some make an internal copy either retaining filename or renaming.
  case "${SSL_TYPE}" in
    ( "letsencrypt" )
      _log 'debug' "Configuring SSL using 'letsencrypt'"

      # `docker-mailserver` will only use one certificate from an FQDN folder in `/etc/letsencrypt/live/`.
      # We iterate the sequence [SSL_DOMAIN, HOSTNAME, DOMAINNAME] to find a matching FQDN folder.
      # This same sequence is used for the Traefik `acme.json` certificate extraction process, which outputs the FQDN folder.
      #
      # eg: If HOSTNAME (mail.example.test) doesn't exist, try DOMAINNAME (example.test).
      # SSL_DOMAIN if set will take priority and is generally expected to have a wildcard prefix.
      # SSL_DOMAIN will have any wildcard prefix stripped for the output FQDN folder it is stored in.
      # TODO: A wildcard cert needs to be provisioned via Traefik to validate if acme.json contains any other value for `main` or `sans` beyond the wildcard.
      #
      # NOTE: HOSTNAME is set via `helpers/dns.sh`, it is not the original system HOSTNAME ENV anymore.
      # TODO: SSL_DOMAIN is Traefik specific, it no longer seems relevant and should be considered for removal.

      _traefik_support

      # checks folders in /etc/letsencrypt/live to identify which one to implicitly use:
      local LETSENCRYPT_DOMAIN LETSENCRYPT_KEY
      LETSENCRYPT_DOMAIN=$(_find_letsencrypt_domain)
      LETSENCRYPT_KEY=$(_find_letsencrypt_key "${LETSENCRYPT_DOMAIN}")

      # Update relevant config for Postfix and Dovecot
      _log 'trace' "Adding ${LETSENCRYPT_DOMAIN} SSL certificate to the postfix and dovecot configuration"

      # LetsEncrypt `fullchain.pem` and `privkey.pem` contents are detailed here from CertBot:
      # https://certbot.eff.org/docs/using.html#where-are-my-certificates
      # `key.pem` was added for `simp_le` support (2016): https://github.com/docker-mailserver/docker-mailserver/pull/288
      # `key.pem` is also a filename used by the `_extract_certs_from_acme` method (implemented for Traefik v2 only)
      local PRIVATE_KEY="/etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/${LETSENCRYPT_KEY}.pem"
      local CERT_CHAIN="/etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/fullchain.pem"

      _set_certificate "${PRIVATE_KEY}" "${CERT_CHAIN}"

      _log 'trace' "SSL configured with 'letsencrypt' certificates"
      ;;

    ( "custom" ) # (hard-coded path) Use a private key with full certificate chain all in a single PEM file.
      _log 'debug' "Adding ${HOSTNAME} SSL certificate"

      # NOTE: Dovecot works fine still as both values are bundled into the keychain
      local COMBINED_PEM_NAME="${HOSTNAME}-full.pem"
      local TMP_KEY_WITH_FULLCHAIN="${TMP_DMS_TLS_PATH}/${COMBINED_PEM_NAME}"
      local KEY_WITH_FULLCHAIN="${DMS_TLS_PATH}/${COMBINED_PEM_NAME}"

      if [[ -f ${TMP_KEY_WITH_FULLCHAIN} ]]; then
        cp "${TMP_KEY_WITH_FULLCHAIN}" "${KEY_WITH_FULLCHAIN}"
        chmod 600 "${KEY_WITH_FULLCHAIN}"

        _set_certificate "${KEY_WITH_FULLCHAIN}"

        _log 'trace' "SSL configured with 'CA signed/custom' certificates"
      else
        _dms_panic__no_file "${TMP_KEY_WITH_FULLCHAIN}" "${SCOPE_SSL_TYPE}"
      fi
      ;;

    ( "manual" ) # (dynamic path via ENV) Use separate private key and cert/chain files (should be PEM encoded)
      _log 'debug' "Configuring certificates using key ${SSL_KEY_PATH} and cert ${SSL_CERT_PATH}"

      # Source files are copied internally to these destinations:
      local PRIVATE_KEY="${DMS_TLS_PATH}/key"
      local CERT_CHAIN="${DMS_TLS_PATH}/cert"

      # Fail early:
      if [[ -z ${SSL_KEY_PATH} ]] && [[ -z ${SSL_CERT_PATH} ]]; then
        _dms_panic__no_env 'SSL_KEY_PATH or SSL_CERT_PATH' "${SCOPE_SSL_TYPE}"
      fi

      if [[ -n ${SSL_ALT_KEY_PATH} ]] \
      && [[ -n ${SSL_ALT_CERT_PATH} ]] \
      && [[ ! -f ${SSL_ALT_KEY_PATH} ]] \
      && [[ ! -f ${SSL_ALT_CERT_PATH} ]]
      then
        _dms_panic__no_file "(ALT) ${SSL_ALT_KEY_PATH} or ${SSL_ALT_CERT_PATH}" "${SCOPE_SSL_TYPE}"
      fi

      if [[ -f ${SSL_KEY_PATH} ]] && [[ -f ${SSL_CERT_PATH} ]]; then
        cp "${SSL_KEY_PATH}" "${PRIVATE_KEY}"
        cp "${SSL_CERT_PATH}" "${CERT_CHAIN}"
        chmod 600 "${PRIVATE_KEY}"
        chmod 644 "${CERT_CHAIN}"

        _set_certificate "${PRIVATE_KEY}" "${CERT_CHAIN}"

        # Support for a fallback certificate, useful for hybrid/dual ECDSA + RSA certs
        if [[ -n ${SSL_ALT_KEY_PATH} ]] && [[ -n ${SSL_ALT_CERT_PATH} ]]; then
          _log 'trace' "Configuring fallback certificates using key ${SSL_ALT_KEY_PATH} and cert ${SSL_ALT_CERT_PATH}"

          _set_alt_certificate "${SSL_ALT_KEY_PATH}" "${SSL_ALT_CERT_PATH}"
        else
          # If the Dovecot settings for alt cert has been enabled (doesn't start with `#`),
          # but required ENV var is missing, reset to disabled state:
          sed -i -r \
            -e 's|^(ssl_alt_key =).*|#\1 </path/to/alternative/key.pem|' \
            -e 's|^(ssl_alt_cert =).*|#\1 </path/to/alternative/cert.pem|' \
            "${DOVECOT_CONFIG_SSL}"
        fi

        _log 'trace' "SSL configured with 'Manual' certificates"
      else
        _dms_panic__no_file "${SSL_KEY_PATH} or ${SSL_CERT_PATH}" "${SCOPE_SSL_TYPE}"
      fi
      ;;

    ( "self-signed" ) # (hard-coded path) Use separate private key and cert/chain files (should be PEM encoded), expects self-signed CA
      _log 'debug' "Adding ${HOSTNAME} SSL certificate"

      local KEY_NAME="${HOSTNAME}-key.pem"
      local CERT_NAME="${HOSTNAME}-cert.pem"

      # Self-Signed source files:
      local SS_KEY="${TMP_DMS_TLS_PATH}/${KEY_NAME}"
      local SS_CERT="${TMP_DMS_TLS_PATH}/${CERT_NAME}"
      local SS_CA_CERT="${TMP_DMS_TLS_PATH}/demoCA/cacert.pem"

      # Source files are copied internally to these destinations:
      local PRIVATE_KEY="${DMS_TLS_PATH}/${KEY_NAME}"
      local CERT_CHAIN="${DMS_TLS_PATH}/${CERT_NAME}"
      local CA_CERT="${DMS_TLS_PATH}/cacert.pem"

      if [[ -f ${SS_KEY} ]] \
      && [[ -f ${SS_CERT} ]] \
      && [[ -f ${SS_CA_CERT} ]]
      then
        cp "${SS_KEY}" "${PRIVATE_KEY}"
        cp "${SS_CERT}" "${CERT_CHAIN}"
        chmod 600 "${PRIVATE_KEY}"
        chmod 644 "${CERT_CHAIN}"

        _set_certificate "${PRIVATE_KEY}" "${CERT_CHAIN}"

        cp "${SS_CA_CERT}" "${CA_CERT}"
        chmod 644 "${CA_CERT}"

        # Have Postfix trust the self-signed CA (which is not installed within the OS trust store)
        sedfile -i -r "s|^#?(smtpd?_tls_CAfile =).*|\1 ${CA_CERT}|" "${POSTFIX_CONFIG_MAIN}"
        # Part of the original `self-signed` support, unclear why this symlink was required?
        # May have been to support the now removed `Courier` (Dovecot replaced it):
        # https://github.com/docker-mailserver/docker-mailserver/commit/1fb3aeede8ac9707cc9ea11d603e3a7b33b5f8d5
        # smtp_tls_CApath and smtpd_tls_CApath both point to /etc/ssl/certs
        local PRIVATE_CA="/etc/ssl/certs/cacert-${HOSTNAME}.pem"
        ln -s "${CA_CERT}" "${PRIVATE_CA}"

        _log 'trace' "SSL configured with 'self-signed' certificates"
      else
        _dms_panic__no_file "${SS_KEY} or ${SS_CERT} or ${SS_CA_CERT}" "${SCOPE_SSL_TYPE}"
      fi
      ;;

    ( '' ) # No SSL/TLS certificate used/required, plaintext auth permitted over insecure connections
      _log 'warn' '!! INSECURE !! SSL configured with plain text access - DO NOT USE FOR PRODUCTION DEPLOYMENT'
      # Untested. Not officially supported.

      # Postfix configuration:
      # smtp_tls_security_level (default: 'may', amavis 'none' x2) | http://www.postfix.org/postconf.5.html#smtp_tls_security_level
      # '_setup_postfix_relay_hosts' also adds 'smtp_tls_security_level = encrypt'
      # smtpd_tls_security_level (default: 'may', port 587 'encrypt') | http://www.postfix.org/postconf.5.html#smtpd_tls_security_level
      #
      # smtpd_tls_auth_only (default not applied, 'no', implicitly 'yes' if security_level is 'encrypt')
      # | http://www.postfix.org/postconf.5.html#smtpd_tls_auth_only | http://www.postfix.org/TLS_README.html#server_tls_auth
      #
      # smtp_tls_wrappermode (default: not applied, 'no') | http://www.postfix.org/postconf.5.html#smtp_tls_wrappermode
      # smtpd_tls_wrappermode (default: 'yes' for service port 'submissions') | http://www.postfix.org/postconf.5.html#smtpd_tls_wrappermode
      # NOTE: Enabling wrappermode requires a security_level of 'encrypt' or stronger. Port 465 presently does not meet this condition.
      #
      # Postfix main.cf (base config):
      sedfile -i -r \
        -e "s|^#?(smtpd?_tls_security_level).*|\1 = none|" \
        -e "s|^#?(smtpd_tls_auth_only).*|\1 = no|" \
        "${POSTFIX_CONFIG_MAIN}"
      #
      # Postfix master.cf (per connection overrides):
      # Disables implicit TLS on port 465 for inbound (smtpd) and outbound (smtp) traffic. Treats it as equivalent to port 25 SMTP with explicit STARTTLS.
      # Inbound 465 (aka service port aliases: submissions) for Postfix to receive over implicit TLS (eg from MUA or functioning as a relay host).
      # Outbound 465 as alternative to port 587 when sending to another MTA (with authentication), such as a relay service (eg SendGrid).
      sedfile -i -r \
        -e "/smtpd?_tls_security_level/s|=.*|=none|" \
        -e '/smtpd?_tls_wrappermode/s|yes|no|' \
        -e '/smtpd_tls_auth_only/s|yes|no|' \
        "${POSTFIX_CONFIG_MASTER}"

      # Dovecot configuration:
      # https://doc.dovecot.org/configuration_manual/dovecot_ssl_configuration/
      # > The plaintext authentication is always allowed (and SSL not required) for connections from localhost, as they’re assumed to be secure anyway.
      # > This applies to all connections where the local and the remote IP addresses are equal.
      # > Also IP ranges specified by login_trusted_networks setting are assumed to be secure.
      #
      # no => insecure auth allowed, yes (default) => plaintext auth only allowed over a secure connection (insecure connection acceptable for non-plaintext auth)
      local DISABLE_PLAINTEXT_AUTH='no'
      # no => disabled, yes => optional (secure connections not required), required (default) => mandatory (only secure connections allowed)
      local DOVECOT_SSL_ENABLED='no'
      sed -i -r "s|^#?(disable_plaintext_auth =).*|\1 ${DISABLE_PLAINTEXT_AUTH}|" /etc/dovecot/conf.d/10-auth.conf
      sed -i -r "s|^(ssl =).*|\1 ${DOVECOT_SSL_ENABLED}|" "${DOVECOT_CONFIG_SSL}"
      ;;

    ( 'snakeoil' ) # This is a temporary workaround for testing only, using the insecure snakeoil cert.
      # mail_privacy.bats and mail_with_ldap.bats both attempt to make a starttls connection with openssl,
      # failing if SSL/TLS is not available.
      ;;

    ( * ) # Unknown option, panic.
      _dms_panic__invalid_value 'SSL_TYPE' "${SCOPE_TLS_LEVEL}"
      ;;

  esac
}


# Identify a valid letsencrypt FQDN folder to use.
function _find_letsencrypt_domain() {
  local LETSENCRYPT_DOMAIN

  if [[ -n ${SSL_DOMAIN} ]] && [[ -e /etc/letsencrypt/live/$(_strip_wildcard_prefix "${SSL_DOMAIN}")/fullchain.pem ]]; then
    LETSENCRYPT_DOMAIN=$(_strip_wildcard_prefix "${SSL_DOMAIN}")
  elif [[ -e /etc/letsencrypt/live/${HOSTNAME}/fullchain.pem ]]; then
    LETSENCRYPT_DOMAIN=${HOSTNAME}
  elif [[ -e /etc/letsencrypt/live/${DOMAINNAME}/fullchain.pem ]]; then
    LETSENCRYPT_DOMAIN=${DOMAINNAME}
  else
    _log 'error' "Cannot find a valid DOMAIN for '/etc/letsencrypt/live/<DOMAIN>/', tried: '${SSL_DOMAIN}', '${HOSTNAME}', '${DOMAINNAME}'"
    _dms_panic__misconfigured 'LETSENCRYPT_DOMAIN' '_find_letsencrypt_domain'
  fi

  echo "${LETSENCRYPT_DOMAIN}"
}

# Verify the FQDN folder also includes a valid private key (`privkey.pem` for Certbot, `key.pem` for extraction by Traefik)
function _find_letsencrypt_key() {
  local LETSENCRYPT_KEY

  local LETSENCRYPT_DOMAIN=${1}
  if [[ -z ${LETSENCRYPT_DOMAIN} ]]; then
    _dms_panic__misconfigured 'LETSENCRYPT_DOMAIN' '_find_letsencrypt_key'
  fi

  if [[ -e /etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/privkey.pem ]]; then
    LETSENCRYPT_KEY='privkey'
  elif [[ -e /etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/key.pem ]]; then
    LETSENCRYPT_KEY='key'
  else
    _log 'error' "Cannot find key file ('privkey.pem' or 'key.pem') in '/etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/'"
    _dms_panic__misconfigured 'LETSENCRYPT_KEY' '_find_letsencrypt_key'
  fi

  echo "${LETSENCRYPT_KEY}"
}

function _extract_certs_from_acme() {
  local CERT_DOMAIN=${1}
  if [[ -z ${CERT_DOMAIN} ]]; then
    _log 'warn' "_extract_certs_from_acme | CERT_DOMAIN is empty"
    return 1
  fi

  local KEY CERT
  KEY=$(acme_extract.py /etc/letsencrypt/acme.json "${CERT_DOMAIN}" --key)
  CERT=$(acme_extract.py /etc/letsencrypt/acme.json "${CERT_DOMAIN}" --cert)

  if [[ -z ${KEY} ]] || [[ -z ${CERT} ]]; then
    _log 'warn' "_extract_certs_from_acme | Unable to find key and/or cert for '${CERT_DOMAIN}' in '/etc/letsencrypt/acme.json'"
    return 1
  fi

  # Currently we advise SSL_DOMAIN for wildcard support using a `*.example.com` value,
  # The filepath however should be `example.com`, avoiding the wildcard part:
  if [[ ${SSL_DOMAIN} == "${CERT_DOMAIN}" ]]; then
    CERT_DOMAIN=$(_strip_wildcard_prefix "${SSL_DOMAIN}")
  fi

  mkdir -p "/etc/letsencrypt/live/${CERT_DOMAIN}/"
  echo "${KEY}" | base64 -d > "/etc/letsencrypt/live/${CERT_DOMAIN}/key.pem" || exit 1
  echo "${CERT}" | base64 -d > "/etc/letsencrypt/live/${CERT_DOMAIN}/fullchain.pem" || exit 1

  _log 'trace' "_extract_certs_from_acme | Certificate successfully extracted for '${CERT_DOMAIN}'"
}

# Remove the `*.` prefix if it exists, else returns the input value
function _strip_wildcard_prefix {
  [[ ${1} == "*."* ]] && echo "${1:2}" || echo "${1}"
}
