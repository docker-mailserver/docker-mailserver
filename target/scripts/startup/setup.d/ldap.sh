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

function _setup_ldap() {
  _log 'debug' 'Setting up LDAP'
  _log 'trace' 'Checking for custom configs'

  for i in 'users' 'groups' 'aliases' 'domains'; do
    local FPATH="/tmp/docker-mailserver/ldap-${i}.cf"
    if [[ -f ${FPATH} ]]; then
      cp "${FPATH}" "/etc/postfix/ldap-${i}.cf"
    fi
  done

  _log 'trace' 'Starting to override configs'

  local FILES=(
    /etc/postfix/ldap-users.cf
    /etc/postfix/ldap-groups.cf
    /etc/postfix/ldap-aliases.cf
    /etc/postfix/ldap-domains.cf
    /etc/postfix/ldap-senders.cf
    /etc/postfix/maps/sender_login_maps.ldap
  )

  for FILE in "${FILES[@]}"; do
    [[ ${FILE} =~ ldap-user ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_USER}"
    [[ ${FILE} =~ ldap-group ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_GROUP}"
    [[ ${FILE} =~ ldap-aliases ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_ALIAS}"
    [[ ${FILE} =~ ldap-domains ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_DOMAIN}"
    [[ ${FILE} =~ ldap-senders ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_SENDERS}"
    [[ -f ${FILE} ]] && _replace_by_env_in_file 'LDAP_' "${FILE}"
  done

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

  _log 'trace' "Configuring LDAP"

  if [[ -f /etc/postfix/ldap-users.cf ]]; then
    postconf 'virtual_mailbox_maps = ldap:/etc/postfix/ldap-users.cf'
  else
    _log 'warn' "'/etc/postfix/ldap-users.cf' not found"
  fi

  if [[ -f /etc/postfix/ldap-domains.cf ]]; then
    postconf 'virtual_mailbox_domains = /etc/postfix/vhost, ldap:/etc/postfix/ldap-domains.cf'
  else
    _log 'warn' "'/etc/postfix/ldap-domains.cf' not found"
  fi

  if [[ -f /etc/postfix/ldap-aliases.cf ]] && [[ -f /etc/postfix/ldap-groups.cf ]]; then
    postconf 'virtual_alias_maps = ldap:/etc/postfix/ldap-aliases.cf, ldap:/etc/postfix/ldap-groups.cf'
  else
    _log 'warn' "'/etc/postfix/ldap-aliases.cf' and / or '/etc/postfix/ldap-groups.cf' not found"
  fi

  # shellcheck disable=SC2016
  sed -i 's|mydestination = \$myhostname, |mydestination = |' /etc/postfix/main.cf

  return 0
}
