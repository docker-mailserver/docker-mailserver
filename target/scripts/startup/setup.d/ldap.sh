#!/bin/bash

function _dovecot_ldap_attrs_to_fields() {
  local ATTRS=${1:?LDAP attributes are required}
  local OMIT_PASSWORD=${2:-no}
  local ATTRIBUTE FIELD VALUE LDAP_ATTRIBUTE
  local -a ATTR_PAIRS

  IFS=',' read -ra ATTR_PAIRS <<<"${ATTRS}"
  for ATTRIBUTE in "${ATTR_PAIRS[@]}"; do
    ATTRIBUTE="${ATTRIBUTE#"${ATTRIBUTE%%[![:space:]]*}"}"
    ATTRIBUTE="${ATTRIBUTE%"${ATTRIBUTE##*[![:space:]]}"}"
    [[ -z ${ATTRIBUTE} ]] && continue

    if [[ ${ATTRIBUTE} == =* ]]; then
      ATTRIBUTE="${ATTRIBUTE#=}"
      [[ ${ATTRIBUTE} == *=* ]] || {
        _log 'error' "Invalid Dovecot LDAP attribute mapping '${ATTRIBUTE}'"
        return 1
      }
      FIELD="${ATTRIBUTE%%=*}"
      VALUE="${ATTRIBUTE#*=}"
    elif [[ ${ATTRIBUTE} == *=* ]]; then
      LDAP_ATTRIBUTE="${ATTRIBUTE%%=*}"
      FIELD="${ATTRIBUTE#*=}"
      VALUE="%{ldap:${LDAP_ATTRIBUTE}}"
    else
      _log 'error' "Invalid Dovecot LDAP attribute mapping '${ATTRIBUTE}'"
      return 1
    fi

    FIELD="${FIELD#"${FIELD%%[![:space:]]*}"}"
    FIELD="${FIELD%"${FIELD##*[![:space:]]}"}"
    VALUE="${VALUE#"${VALUE%%[![:space:]]*}"}"
    VALUE="${VALUE%"${VALUE##*[![:space:]]}"}"

    [[ ${FIELD} == password && ${OMIT_PASSWORD,,} == yes ]] && continue
    if [[ ${FIELD} == mail ]]; then
      FIELD='mail_path'
    fi
    if [[ ${FIELD} == mail_path ]]; then
      VALUE="${VALUE#maildir:}"
    fi

    [[ -n ${FIELD} ]] || {
      _log 'error' "Invalid Dovecot LDAP attribute mapping '${ATTRIBUTE}'"
      return 1
    }
    printf '    %s = %s\n' "${FIELD}" "${VALUE}"
  done
}

function _dovecot_ldap_replace_fields() {
  local MARKER=${1:?Dovecot LDAP fields marker is required}
  local ATTRS=${2:?Dovecot LDAP attributes are required}
  local CONFIG_FILE=${3:?Dovecot LDAP config is required}
  local OMIT_PASSWORD=${4:-no}
  local FIELDS_FILE TMP_FILE

  FIELDS_FILE=$(mktemp)
  TMP_FILE=$(mktemp)

  if ! _dovecot_ldap_attrs_to_fields "${ATTRS}" "${OMIT_PASSWORD}" >"${FIELDS_FILE}"; then
    rm -f "${FIELDS_FILE}" "${TMP_FILE}"
    return 1
  fi

  if ! awk -v marker="${MARKER}" -v fields_file="${FIELDS_FILE}" '
    $0 == marker {
      print
      while ((getline line < fields_file) > 0) {
        print line
      }
      replacing = 1
      replaced = 1
      next
    }
    replacing && /^  }$/ {
      replacing = 0
      print
      next
    }
    replacing {
      next
    }
    { print }
    END {
      if (!replaced) {
        exit 1
      }
    }
  ' "${CONFIG_FILE}" >"${TMP_FILE}"; then
    rm -f "${FIELDS_FILE}" "${TMP_FILE}"
    return 1
  fi

  if ! cat "${TMP_FILE}" >"${CONFIG_FILE}"; then
    rm -f "${FIELDS_FILE}" "${TMP_FILE}"
    return 1
  fi
  rm -f "${FIELDS_FILE}" "${TMP_FILE}"
}

# Prints `key = value` for each Postfix LDAP table setting (`ldap_table(5)`)
# that has a non-empty ENV with the given prefix (e.g. `LDAP_` + `SEARCH_BASE`).
#
# @param ${1} = ENV prefix
function _postfix_ldap_settings_from_env() {
  local ENV_PREFIX=${1:?ENV prefix is required}
  local SETTING ENV_NAME

  for SETTING in server_host server_port timeout search_base query_filter result_format domain \
    result_attribute special_result_attribute terminal_result_attribute leaf_result_attribute \
    scope bind bind_dn bind_pw recursion_limit expansion_limit size_limit dereference \
    chase_referrals version debuglevel sasl_mechs sasl_realm sasl_authz_id sasl_minssf \
    start_tls tls_ca_cert_dir tls_ca_cert_file tls_cert tls_key tls_require_cert \
    tls_random_file tls_cipher_suite
  do
    ENV_NAME="${ENV_PREFIX}${SETTING^^}"
    if [[ -n ${!ENV_NAME:-} ]]; then
      printf '%s = %s\n' "${SETTING}" "${!ENV_NAME}"
    fi
  done
}

# Reads `key = value` lines from stdin, normalizes the white-space around the first `=`,
# drops keys without a value and keeps only the last occurrence of each key.
function _cleanse_config() {
  sed -E \
    -e 's/^[[:space:]]*([^=[:space:]]+)[[:space:]]*=[[:space:]]*/\1 = /' \
    -e '/^[^=]+ = [[:space:]]*$/d' \
  | tac | sort --unique --field-separator='=' --key=1,1
}

# Generates `/etc/postfix/ldap/<KIND>.cf` from layered sources, later sources take precedence:
# defaults, `LDAP_*` ENV, the optional user config `ldap-<KIND>.cf`, `POSTFIX_<KIND>_*` ENV.
# Without a `query_filter`, the config is removed (the lookup table is disabled).
#
# @param ${1} = Query kind (users, groups, aliases, domains, senders)
function _create_config_postfix() {
  local QUERY_KIND=${1:?Query kind is required}
  local CONFIG_FILE="/etc/postfix/ldap/${QUERY_KIND}.cf"
  local USER_CONFIG="/tmp/docker-mailserver/ldap-${QUERY_KIND}.cf"

  {
    echo 'version = 3'
    echo 'result_attribute = mail'
    # Spoof protection compares the results against the SASL login name:
    if [[ ${QUERY_KIND} == 'senders' ]]; then
      echo 'result_attribute = mail, uid'
    fi
    _postfix_ldap_settings_from_env 'LDAP_'
    if [[ -f ${USER_CONFIG} ]]; then
      _get_valid_lines_from_file "${USER_CONFIG}"
    fi
    _postfix_ldap_settings_from_env "POSTFIX_${QUERY_KIND^^}_"
  } | _cleanse_config >"${CONFIG_FILE}"

  if ! grep -q '^query_filter = ' "${CONFIG_FILE}"; then
    _log 'warn' "No 'query_filter' configured for Postfix LDAP '${QUERY_KIND}' lookups (ENV 'POSTFIX_${QUERY_KIND^^}_QUERY_FILTER') - disabling"
    rm "${CONFIG_FILE}"
  fi
}

function _setup_ldap() {
  _log 'debug' 'Setting up LDAP'
  _log 'trace' 'Configuring Postfix LDAP'

  mkdir -p /etc/postfix/ldap
  local QUERY_KIND
  for QUERY_KIND in 'users' 'groups' 'aliases' 'domains' 'senders'; do
    _create_config_postfix "${QUERY_KIND}"
  done

  # Lookup tables are only configured when their config was generated with a `query_filter`:
  if [[ -f /etc/postfix/ldap/users.cf ]]; then
    postconf 'virtual_mailbox_maps = ldap:/etc/postfix/ldap/users.cf'
  fi

  if [[ -f /etc/postfix/ldap/domains.cf ]]; then
    postconf 'virtual_mailbox_domains = /etc/postfix/vhost, ldap:/etc/postfix/ldap/domains.cf'
  fi

  local ALIAS_MAPS=()
  for QUERY_KIND in 'aliases' 'groups'; do
    [[ -f /etc/postfix/ldap/${QUERY_KIND}.cf ]] && ALIAS_MAPS+=("ldap:/etc/postfix/ldap/${QUERY_KIND}.cf")
  done
  if [[ ${#ALIAS_MAPS[@]} -gt 0 ]]; then
    postconf "virtual_alias_maps = ${ALIAS_MAPS[*]}"
  fi

  _log 'trace' "Configuring Dovecot LDAP"

  declare -A DOVECOT_LDAP_MAPPING

  DOVECOT_LDAP_MAPPING['DOVECOT_LDAP_URIS']="${DOVECOT_URIS:=${LDAP_SERVER_HOST}}"
  DOVECOT_LDAP_MAPPING['DOVECOT_LDAP_BASE']="${DOVECOT_BASE:=${LDAP_SEARCH_BASE}}"
  DOVECOT_LDAP_MAPPING['DOVECOT_LDAP_AUTH_DN']="${DOVECOT_DN:=${LDAP_BIND_DN}}"
  DOVECOT_LDAP_MAPPING['DOVECOT_LDAP_AUTH_DN_PASSWORD']="${DOVECOT_DNPASS:=${LDAP_BIND_PW}}"
  # `DOVECOT_TLS` (Dovecot 2.3 `tls`) maps to Dovecot 2.4 `ldap_starttls`:
  DOVECOT_LDAP_MAPPING['DOVECOT_LDAP_STARTTLS']="${DOVECOT_TLS:=no}"
  DOVECOT_LDAP_MAPPING['DOVECOT_LDAP_VERSION']="${DOVECOT_LDAP_VERSION:=3}"
  DOVECOT_LDAP_MAPPING['DOVECOT_PASSDB_LDAP_BIND']="${DOVECOT_PASSDB_LDAP_BIND:=${DOVECOT_AUTH_BIND:=no}}"
  DOVECOT_LDAP_MAPPING['DOVECOT_PASSDB_DEFAULT_PASSWORD_SCHEME']="${DOVECOT_DEFAULT_PASS_SCHEME:=SSHA}"

  # Temporary compatibility to support fallback from Dovecot 2.3 settings ENV (used prior to DMS v16):
  DOVECOT_LDAP_MAPPING['DOVECOT_USERDB_LDAP_FILTER']="${DOVECOT_USERDB_LDAP_FILTER:=${DOVECOT_USER_FILTER}}"
  DOVECOT_LDAP_MAPPING['DOVECOT_PASSDB_LDAP_FILTER']="${DOVECOT_PASSDB_LDAP_FILTER:=${DOVECOT_PASS_FILTER}}"

  # Default fallback for the passdb filter to share the same LDAP query filter as the userdb:
  DOVECOT_LDAP_MAPPING['DOVECOT_PASSDB_LDAP_FILTER']="${DOVECOT_PASSDB_LDAP_FILTER:=${DOVECOT_USERDB_LDAP_FILTER}}"

  for VAR in "${!DOVECOT_LDAP_MAPPING[@]}"; do
    export "${VAR}=${DOVECOT_LDAP_MAPPING[${VAR}]}"
  done

  _replace_by_env_in_file 'DOVECOT_' /etc/dovecot/conf.d/auth-ldap.conf.ext

  if [[ -n ${DOVECOT_PASS_ATTRS:-} ]]; then
    _dovecot_ldap_replace_fields \
      '    # DOVECOT_PASSDB_FIELDS' \
      "${DOVECOT_PASS_ATTRS}" \
      /etc/dovecot/conf.d/auth-ldap.conf.ext \
      "${DOVECOT_PASSDB_LDAP_BIND}"
  fi
  if [[ -n ${DOVECOT_USER_ATTRS:-} ]]; then
    _dovecot_ldap_replace_fields \
      '    # DOVECOT_USERDB_FIELDS' \
      "${DOVECOT_USER_ATTRS}" \
      /etc/dovecot/conf.d/auth-ldap.conf.ext
  fi

  if [[ ${DOVECOT_PASSDB_LDAP_BIND,,} == yes ]]; then
    # Password fields are omitted by `_dovecot_ldap_replace_fields()` for custom mappings.
    # The default mapping needs the same treatment when authentication binds are enabled.
    sed -i '/^    password = /d' /etc/dovecot/conf.d/auth-ldap.conf.ext
  fi

  _log 'trace' 'Enabling Dovecot LDAP authentication'

  sed -i -e '/\!include auth-ldap\.conf\.ext/s/^#//' /etc/dovecot/conf.d/10-auth.conf
  sed -i -e '/\!include auth-passwdfile\.inc/s/^/#/' /etc/dovecot/conf.d/10-auth.conf

  # shellcheck disable=SC2016
  sed -i 's|mydestination = \$myhostname, |mydestination = |' /etc/postfix/main.cf

  return 0
}
