#! /bin/bash

function _setup
{
  _log 'info' 'Configuring mail server'
  for FUNC in "${FUNCS_SETUP[@]}"
  do
    ${FUNC}
  done

  # All startup modifications to configs should have taken place before calling this:
  _prepare_for_change_detection
}

function _setup_supervisor
{
  if ! grep -q "loglevel = ${SUPERVISOR_LOGLEVEL}" /etc/supervisor/supervisord.conf
  then
    case "${SUPERVISOR_LOGLEVEL}" in
      ( 'critical' | 'error' | 'info' | 'debug' )
        sed -i -E \
          "s|(loglevel).*|\1 = ${SUPERVISOR_LOGLEVEL}|g" \
          /etc/supervisor/supervisord.conf

        supervisorctl reload
        exit
        ;;

      ( 'warn' )
        return 0
        ;;

      ( * )
        _log 'warn' \
          "SUPERVISOR_LOGLEVEL '${SUPERVISOR_LOGLEVEL}' unknown. Using default 'warn'"
        ;;

    esac
  fi

  return 0
}

function _setup_default_vars
{
  _log 'debug' 'Setting up default variables'

  : >/root/.bashrc     # make DMS variables available in login shells and their subprocesses
  : >/etc/dms-settings # this file can be sourced by other scripts

  local VAR
  for VAR in "${!VARS[@]}"
  do
    echo "export ${VAR}='${VARS[${VAR}]}'" >>/root/.bashrc
    echo "${VAR}='${VARS[${VAR}]}'"        >>/etc/dms-settings
  done

  sort -o /root/.bashrc     /root/.bashrc
  sort -o /etc/dms-settings /etc/dms-settings
}

# File/folder permissions are fine when using docker volumes, but may be wrong
# when file system folders are mounted into the container.
# Set the expected values and create missing folders/files just in case.
function _setup_file_permissions
{
  _log 'debug' 'Setting file and directory permissions'

  mkdir -p /var/log/supervisor

  mkdir -p /var/log/mail
  chown syslog:root /var/log/mail

  touch /var/log/mail/clamav.log
  chown clamav:adm /var/log/mail/clamav.log
  chmod 640 /var/log/mail/clamav.log

  touch /var/log/mail/freshclam.log
  chown clamav:adm /var/log/mail/freshclam.log
  chmod 640 /var/log/mail/freshclam.log
}

function _setup_mailname
{
  _log 'debug' "Setting up mailname and creating '/etc/mailname'"
  echo "${DOMAINNAME}" >/etc/mailname
}

function _setup_amavis
{
  if [[ ${ENABLE_AMAVIS} -eq 1 ]]
  then
    _log 'debug' 'Setting up Amavis'
    sed -i \
      "s|^#\$myhostname = \"mail.example.com\";|\$myhostname = \"${HOSTNAME}\";|" \
      /etc/amavis/conf.d/05-node_id
  else
    _log 'debug' "Removing Amavis from Postfix's configuration"
    sed -i 's|content_filter =.*|content_filter =|' /etc/postfix/main.cf
    [[ ${ENABLE_CLAMAV} -eq 1 ]] && _log 'warn' 'ClamAV will not work when Amavis is disabled. Remove ENABLE_AMAVIS=0 from your configuration to fix it.'
    [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]] && _log 'warn' 'Spamassassin will not work when Amavis is disabled. Remove ENABLE_AMAVIS=0 from your configuration to fix it.'
  fi
}

function _setup_dmarc_hostname
{
  _log 'debug' 'Setting up DMARC'
  sed -i -e \
    "s|^AuthservID.*$|AuthservID          ${HOSTNAME}|g" \
    -e "s|^TrustedAuthservIDs.*$|TrustedAuthservIDs  ${HOSTNAME}|g" \
    /etc/opendmarc.conf
}

function _setup_postfix_hostname
{
  _log 'debug' 'Applying hostname and domainname to Postfix'
  postconf -e "myhostname = ${HOSTNAME}"
  postconf -e "mydomain = ${DOMAINNAME}"
}

function _setup_dovecot_hostname
{
  _log 'debug' 'Applying hostname to Dovecot'
  sed -i \
    "s|^#hostname =.*$|hostname = '${HOSTNAME}'|g" \
    /etc/dovecot/conf.d/15-lda.conf
}

function _setup_dovecot
{
  _log 'debug' 'Setting up Dovecot'

  cp -a /usr/share/dovecot/protocols.d /etc/dovecot/
  # disable pop3 (it will be eventually enabled later in the script, if requested)
  mv /etc/dovecot/protocols.d/pop3d.protocol /etc/dovecot/protocols.d/pop3d.protocol.disab
  mv /etc/dovecot/protocols.d/managesieved.protocol /etc/dovecot/protocols.d/managesieved.protocol.disab
  sed -i -e 's|#ssl = yes|ssl = yes|g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's|#port = 993|port = 993|g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's|#port = 995|port = 995|g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's|#ssl = yes|ssl = required|g' /etc/dovecot/conf.d/10-ssl.conf
  sed -i 's|^postmaster_address = .*$|postmaster_address = '"${POSTMASTER_ADDRESS}"'|g' /etc/dovecot/conf.d/15-lda.conf

  if ! grep -q -E '^stats_writer_socket_path=' /etc/dovecot/dovecot.conf
  then
    printf '\n%s\n' 'stats_writer_socket_path=' >>/etc/dovecot/dovecot.conf
  fi

  # set mail_location according to mailbox format
  case "${DOVECOT_MAILBOX_FORMAT}" in

    ( 'sdbox' | 'mdbox' )
      _log 'trace' "Dovecot ${DOVECOT_MAILBOX_FORMAT} format configured"
      sed -i -e \
        "s|^mail_location = .*$|mail_location = ${DOVECOT_MAILBOX_FORMAT}:\/var\/mail\/%d\/%n|g" \
        /etc/dovecot/conf.d/10-mail.conf

      _log 'trace' 'Enabling cron job for dbox purge'
      mv /etc/cron.d/dovecot-purge.disabled /etc/cron.d/dovecot-purge
      chmod 644 /etc/cron.d/dovecot-purge
      ;;

    ( * )
      _log 'trace' 'Dovecot default format (maildir) configured'
      sed -i -e 's|^mail_location = .*$|mail_location = maildir:\/var\/mail\/%d\/%n|g' /etc/dovecot/conf.d/10-mail.conf
      ;;

  esac

  # enable Managesieve service by setting the symlink
  # to the configuration file Dovecot will actually find
  if [[ ${ENABLE_MANAGESIEVE} -eq 1 ]]
  then
    _log 'trace' 'Sieve management enabled'
    mv /etc/dovecot/protocols.d/managesieved.protocol.disab /etc/dovecot/protocols.d/managesieved.protocol
  fi

  # copy pipe and filter programs, if any
  rm -f /usr/lib/dovecot/sieve-filter/*
  rm -f /usr/lib/dovecot/sieve-pipe/*
  [[ -d /tmp/docker-mailserver/sieve-filter ]] && cp /tmp/docker-mailserver/sieve-filter/* /usr/lib/dovecot/sieve-filter/
  [[ -d /tmp/docker-mailserver/sieve-pipe ]] && cp /tmp/docker-mailserver/sieve-pipe/* /usr/lib/dovecot/sieve-pipe/

  # create global sieve directories
  mkdir -p /usr/lib/dovecot/sieve-global/before
  mkdir -p /usr/lib/dovecot/sieve-global/after

  if [[ -f /tmp/docker-mailserver/before.dovecot.sieve ]]
  then
    cp /tmp/docker-mailserver/before.dovecot.sieve /usr/lib/dovecot/sieve-global/before/50-before.dovecot.sieve
    sievec /usr/lib/dovecot/sieve-global/before/50-before.dovecot.sieve
  else
    rm -f /usr/lib/dovecot/sieve-global/before/50-before.dovecot.sieve /usr/lib/dovecot/sieve-global/before/50-before.dovecot.svbin
  fi

  if [[ -f /tmp/docker-mailserver/after.dovecot.sieve ]]
  then
    cp /tmp/docker-mailserver/after.dovecot.sieve /usr/lib/dovecot/sieve-global/after/50-after.dovecot.sieve
    sievec /usr/lib/dovecot/sieve-global/after/50-after.dovecot.sieve
  else
    rm -f /usr/lib/dovecot/sieve-global/after/50-after.dovecot.sieve /usr/lib/dovecot/sieve-global/after/50-after.dovecot.svbin
  fi

  # sieve will move spams to .Junk folder when SPAMASSASSIN_SPAM_TO_INBOX=1 and MOVE_SPAM_TO_JUNK=1
  if [[ ${SPAMASSASSIN_SPAM_TO_INBOX} -eq 1 ]] && [[ ${MOVE_SPAM_TO_JUNK} -eq 1 ]]
  then
    _log 'debug' 'Spam messages will be moved to the Junk folder'
    cp /etc/dovecot/sieve/before/60-spam.sieve /usr/lib/dovecot/sieve-global/before/
    sievec /usr/lib/dovecot/sieve-global/before/60-spam.sieve
  else
    rm -f /usr/lib/dovecot/sieve-global/before/60-spam.sieve /usr/lib/dovecot/sieve-global/before/60-spam.svbin
  fi

  chown docker:docker -R /usr/lib/dovecot/sieve*
  chmod 550 -R /usr/lib/dovecot/sieve*
  chmod -f +x /usr/lib/dovecot/sieve-pipe/*
}

function _setup_dovecot_quota
{
    _log 'debug' 'Setting up Dovecot quota'

    # Dovecot quota is disabled when using LDAP or SMTP_ONLY or when explicitly disabled.
    if [[ ${ENABLE_LDAP} -eq 1 ]] || [[ ${SMTP_ONLY} -eq 1 ]] || [[ ${ENABLE_QUOTAS} -eq 0 ]]
    then
      # disable dovecot quota in docevot confs
      if [[ -f /etc/dovecot/conf.d/90-quota.conf ]]
      then
        mv /etc/dovecot/conf.d/90-quota.conf /etc/dovecot/conf.d/90-quota.conf.disab
        sed -i \
          "s|mail_plugins = \$mail_plugins quota|mail_plugins = \$mail_plugins|g" \
          /etc/dovecot/conf.d/10-mail.conf
        sed -i \
          "s|mail_plugins = \$mail_plugins imap_quota|mail_plugins = \$mail_plugins|g" \
          /etc/dovecot/conf.d/20-imap.conf
      fi

      # disable quota policy check in postfix
      sed -i "s|check_policy_service inet:localhost:65265||g" /etc/postfix/main.cf
    else
      if [[ -f /etc/dovecot/conf.d/90-quota.conf.disab ]]
      then
        mv /etc/dovecot/conf.d/90-quota.conf.disab /etc/dovecot/conf.d/90-quota.conf
        sed -i \
          "s|mail_plugins = \$mail_plugins|mail_plugins = \$mail_plugins quota|g" \
          /etc/dovecot/conf.d/10-mail.conf
        sed -i \
          "s|mail_plugins = \$mail_plugin|mail_plugins = \$mail_plugins imap_quota|g" \
          /etc/dovecot/conf.d/20-imap.conf
      fi

      local MESSAGE_SIZE_LIMIT_MB=$((POSTFIX_MESSAGE_SIZE_LIMIT / 1000000))
      local MAILBOX_LIMIT_MB=$((POSTFIX_MAILBOX_SIZE_LIMIT / 1000000))

      sed -i \
        "s|quota_max_mail_size =.*|quota_max_mail_size = ${MESSAGE_SIZE_LIMIT_MB}$([[ ${MESSAGE_SIZE_LIMIT_MB} -eq 0 ]] && echo "" || echo "M")|g" \
        /etc/dovecot/conf.d/90-quota.conf

      sed -i \
        "s|quota_rule = \*:storage=.*|quota_rule = *:storage=${MAILBOX_LIMIT_MB}$([[ ${MAILBOX_LIMIT_MB} -eq 0 ]] && echo "" || echo "M")|g" \
        /etc/dovecot/conf.d/90-quota.conf

      if [[ -d /tmp/docker-mailserver ]] && [[ ! -f /tmp/docker-mailserver/dovecot-quotas.cf ]]
      then
        _log 'trace' "'/tmp/docker-mailserver/dovecot-quotas.cf' is not provided. Using default quotas."
        : >/tmp/docker-mailserver/dovecot-quotas.cf
      fi

      # enable quota policy check in postfix
      sed -i \
        "s|reject_unknown_recipient_domain, reject_rbl_client zen.spamhaus.org|reject_unknown_recipient_domain, check_policy_service inet:localhost:65265, reject_rbl_client zen.spamhaus.org|g" \
        /etc/postfix/main.cf
    fi
}

function _setup_dovecot_local_user
{
  _log 'debug' 'Setting up Dovecot Local User'

  _create_accounts
  [[ ${ENABLE_LDAP} -eq 1 ]] && return 0

  if [[ ! -f /tmp/docker-mailserver/postfix-accounts.cf ]]
  then
    _log 'trace' "'/tmp/docker-mailserver/postfix-accounts.cf' not provided, no mail account created"
  fi

  local SLEEP_PERIOD='10'
  for (( COUNTER = 11 ; COUNTER >= 0 ; COUNTER-- ))
  do
    if [[ $(grep -cE '.+@.+\|' /tmp/docker-mailserver/postfix-accounts.cf 2>/dev/null || printf '%s' '0') -ge 1 ]]
    then
      return 0
    else
      _log 'warn' "You need at least one email account to start Dovecot ($(( ( COUNTER + 1 ) * SLEEP_PERIOD ))s left for account creation before shutdown)"
      sleep "${SLEEP_PERIOD}"
    fi
  done

  _shutdown 'No accounts provided - Dovecot could not be started'
}

function _setup_ldap
{
  _log 'debug' 'Setting up LDAP'
  _log 'trace' 'Checking for custom configs'

  for i in 'users' 'groups' 'aliases' 'domains'
  do
    local FPATH="/tmp/docker-mailserver/ldap-${i}.cf"
    if [[ -f ${FPATH} ]]
    then
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

  for FILE in "${FILES[@]}"
  do
    [[ ${FILE} =~ ldap-user ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_USER}"
    [[ ${FILE} =~ ldap-group ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_GROUP}"
    [[ ${FILE} =~ ldap-aliases ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_ALIAS}"
    [[ ${FILE} =~ ldap-domains ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_DOMAIN}"
    [[ ${FILE} =~ ldap-senders ]] && export LDAP_QUERY_FILTER="${LDAP_QUERY_FILTER_SENDERS}"
    _log debug "$(configomat.sh "LDAP_" "${FILE}" 2>&1)"
  done

  _log 'trace' "Configuring Dovecot LDAP"

  declare -A DOVECOT_LDAP_MAPPING

  DOVECOT_LDAP_MAPPING['DOVECOT_BASE']="${DOVECOT_BASE:="${LDAP_SEARCH_BASE}"}"
  DOVECOT_LDAP_MAPPING['DOVECOT_DN']="${DOVECOT_DN:="${LDAP_BIND_DN}"}"
  DOVECOT_LDAP_MAPPING['DOVECOT_DNPASS']="${DOVECOT_DNPASS:="${LDAP_BIND_PW}"}"
  DOVECOT_LDAP_MAPPING['DOVECOT_URIS']="${DOVECOT_URIS:="${DOVECOT_HOSTS:="${LDAP_SERVER_HOST}"}"}"

  # Add protocol to DOVECOT_URIS so that we can use dovecot's "uris" option:
  # https://doc.dovecot.org/configuration_manual/authentication/ldap/
  if [[ ${DOVECOT_LDAP_MAPPING["DOVECOT_URIS"]} != *'://'* ]]
  then
    DOVECOT_LDAP_MAPPING['DOVECOT_URIS']="ldap://${DOVECOT_LDAP_MAPPING["DOVECOT_URIS"]}"
  fi

  # Default DOVECOT_PASS_FILTER to the same value as DOVECOT_USER_FILTER
  DOVECOT_LDAP_MAPPING['DOVECOT_PASS_FILTER']="${DOVECOT_PASS_FILTER:="${DOVECOT_USER_FILTER}"}"

  for VAR in "${!DOVECOT_LDAP_MAPPING[@]}"
  do
    export "${VAR}=${DOVECOT_LDAP_MAPPING[${VAR}]}"
  done

  _log debug "$(configomat.sh "DOVECOT_" "/etc/dovecot/dovecot-ldap.conf.ext" 2>&1)"

  _log 'trace' 'Enabling Dovecot LDAP authentication'

  sed -i -e '/\!include auth-ldap\.conf\.ext/s/^#//' /etc/dovecot/conf.d/10-auth.conf
  sed -i -e '/\!include auth-passwdfile\.inc/s/^/#/' /etc/dovecot/conf.d/10-auth.conf

  _log 'trace' "Configuring LDAP"

  if [[ -f /etc/postfix/ldap-users.cf ]]
  then
    postconf -e 'virtual_mailbox_maps = ldap:/etc/postfix/ldap-users.cf'
  else
    _log 'warn' "'/etc/postfix/ldap-users.cf' not found"
  fi

  if [[ -f /etc/postfix/ldap-domains.cf ]]
  then
    postconf -e 'virtual_mailbox_domains = /etc/postfix/vhost, ldap:/etc/postfix/ldap-domains.cf'
  else
    _log 'warn' "'/etc/postfix/ldap-domains.cf' not found"
  fi

  if [[ -f /etc/postfix/ldap-aliases.cf ]] && [[ -f /etc/postfix/ldap-groups.cf ]]
  then
    postconf -e 'virtual_alias_maps = ldap:/etc/postfix/ldap-aliases.cf, ldap:/etc/postfix/ldap-groups.cf'
  else
    _log 'warn' "'/etc/postfix/ldap-aliases.cf' and / or '/etc/postfix/ldap-groups.cf' not found"
  fi

  # shellcheck disable=SC2016
  sed -i 's|mydestination = \$myhostname, |mydestination = |' /etc/postfix/main.cf

  return 0
}

function _setup_postgrey
{
  _log 'debug' 'Configuring Postgrey'

  sed -i -E \
    's|, reject_rbl_client zen.spamhaus.org$|, reject_rbl_client zen.spamhaus.org, check_policy_service inet:127.0.0.1:10023|' \
    /etc/postfix/main.cf

  sed -i -e \
    "s|\"--inet=127.0.0.1:10023\"|\"--inet=127.0.0.1:10023 --delay=${POSTGREY_DELAY} --max-age=${POSTGREY_MAX_AGE} --auto-whitelist-clients=${POSTGREY_AUTO_WHITELIST_CLIENTS}\"|" \
    /etc/default/postgrey

  TEXT_FOUND=$(grep -c -i 'POSTGREY_TEXT' /etc/default/postgrey)

  if [[ ${TEXT_FOUND} -eq 0 ]]
  then
    printf 'POSTGREY_TEXT=\"%s\"\n\n' "${POSTGREY_TEXT}" >>/etc/default/postgrey
  fi

  if [[ -f /tmp/docker-mailserver/whitelist_clients.local ]]
  then
    cp -f /tmp/docker-mailserver/whitelist_clients.local /etc/postgrey/whitelist_clients.local
  fi

  if [[ -f /tmp/docker-mailserver/whitelist_recipients ]]
  then
    cp -f /tmp/docker-mailserver/whitelist_recipients /etc/postgrey/whitelist_recipients
  fi
}

function _setup_postfix_postscreen
{
  _log 'debug' 'Configuring Postscreen'
  sed -i \
    -e "s|postscreen_dnsbl_action = enforce|postscreen_dnsbl_action = ${POSTSCREEN_ACTION}|" \
    -e "s|postscreen_greet_action = enforce|postscreen_greet_action = ${POSTSCREEN_ACTION}|" \
    -e "s|postscreen_bare_newline_action = enforce|postscreen_bare_newline_action = ${POSTSCREEN_ACTION}|" /etc/postfix/main.cf
}

function _setup_postfix_sizelimits
{
  _log 'trace' "Configuring Postfix message size limit to '${POSTFIX_MESSAGE_SIZE_LIMIT}'"
  postconf -e "message_size_limit = ${POSTFIX_MESSAGE_SIZE_LIMIT}"

  _log 'trace' "Configuring Postfix mailbox size limit to '${POSTFIX_MAILBOX_SIZE_LIMIT}'"
  postconf -e "mailbox_size_limit = ${POSTFIX_MAILBOX_SIZE_LIMIT}"

  _log 'trace' "Configuring Postfix virtual mailbox size limit to '${POSTFIX_MAILBOX_SIZE_LIMIT}'"
  postconf -e "virtual_mailbox_limit = ${POSTFIX_MAILBOX_SIZE_LIMIT}"
}

function _setup_clamav_sizelimit
{
  _log 'trace' "Setting ClamAV message scan size limit to '${CLAMAV_MESSAGE_SIZE_LIMIT}'"
  sedfile -i "s/^MaxFileSize.*/MaxFileSize ${CLAMAV_MESSAGE_SIZE_LIMIT}/" /etc/clamav/clamd.conf
}

function _setup_postfix_smtputf8
{
  _log 'trace' "Disabling Postfix's smtputf8 support"
  postconf -e "smtputf8_enable = no"
}

function _setup_spoof_protection
{
  _log 'trace' 'Configuring spoof protection'
  sed -i \
    's|smtpd_sender_restrictions =|smtpd_sender_restrictions = reject_authenticated_sender_login_mismatch,|' \
    /etc/postfix/main.cf

  if [[ ${ENABLE_LDAP} -eq 1 ]]
  then
    if [[ -z ${LDAP_QUERY_FILTER_SENDERS} ]]
    then
      postconf -e 'smtpd_sender_login_maps = ldap:/etc/postfix/ldap-users.cf ldap:/etc/postfix/ldap-aliases.cf ldap:/etc/postfix/ldap-groups.cf'
    else
      postconf -e 'smtpd_sender_login_maps = ldap:/etc/postfix/ldap-senders.cf'
    fi
  else
    if [[ -f /etc/postfix/regexp ]]
    then
      postconf -e 'smtpd_sender_login_maps = unionmap:{ texthash:/etc/postfix/virtual, hash:/etc/aliases, pcre:/etc/postfix/maps/sender_login_maps.pcre, pcre:/etc/postfix/regexp }'
    else
      postconf -e 'smtpd_sender_login_maps = texthash:/etc/postfix/virtual, hash:/etc/aliases, pcre:/etc/postfix/maps/sender_login_maps.pcre'
    fi
  fi
}

function _setup_postfix_access_control
{
  _log 'trace' 'Configuring user access'

  if [[ -f /tmp/docker-mailserver/postfix-send-access.cf ]]
  then
    sed -i 's|smtpd_sender_restrictions =|smtpd_sender_restrictions = check_sender_access texthash:/tmp/docker-mailserver/postfix-send-access.cf,|' /etc/postfix/main.cf
  fi

  if [[ -f /tmp/docker-mailserver/postfix-receive-access.cf ]]
  then
    sed -i 's|smtpd_recipient_restrictions =|smtpd_recipient_restrictions = check_recipient_access texthash:/tmp/docker-mailserver/postfix-receive-access.cf,|' /etc/postfix/main.cf
  fi
}

function _setup_postfix_sasl
{
  if [[ ${ENABLE_SASLAUTHD} -eq 1 ]] && [[ ! -f /etc/postfix/sasl/smtpd.conf ]]
  then
    cat >/etc/postfix/sasl/smtpd.conf << EOF
pwcheck_method: saslauthd
mech_list: plain login
EOF
  fi

  if [[ ${ENABLE_SASLAUTHD} -eq 0 ]] && [[ ${SMTP_ONLY} -eq 1 ]]
  then
    sed -i -E \
      's|^smtpd_sasl_auth_enable =.*|smtpd_sasl_auth_enable = no|g' \
      /etc/postfix/main.cf
    sed -i -E \
      's|^  -o smtpd_sasl_auth_enable=.*|  -o smtpd_sasl_auth_enable=no|g' \
      /etc/postfix/master.cf
  fi
}

function _setup_saslauthd
{
  _log 'debug' 'Setting up SASLAUTHD'

  if [[ ! -f /etc/saslauthd.conf ]]
  then
    _log 'trace' 'Creating /etc/saslauthd.conf'
    cat > /etc/saslauthd.conf << EOF
ldap_servers: ${SASLAUTHD_LDAP_SERVER}

ldap_auth_method: ${SASLAUTHD_LDAP_AUTH_METHOD}
ldap_bind_dn: ${SASLAUTHD_LDAP_BIND_DN}
ldap_bind_pw: ${SASLAUTHD_LDAP_PASSWORD}

ldap_search_base: ${SASLAUTHD_LDAP_SEARCH_BASE}
ldap_filter: ${SASLAUTHD_LDAP_FILTER}

ldap_start_tls: ${SASLAUTHD_LDAP_START_TLS}
ldap_tls_check_peer: ${SASLAUTHD_LDAP_TLS_CHECK_PEER}

${SASLAUTHD_LDAP_TLS_CACERT_FILE}
${SASLAUTHD_LDAP_TLS_CACERT_DIR}
${SASLAUTHD_LDAP_PASSWORD_ATTR}
${SASLAUTHD_LDAP_MECH}

ldap_referrals: yes
log_level: 10
EOF
  fi

  sed -i \
    -e "/^[^#].*smtpd_sasl_type.*/s/^/#/g" \
    -e "/^[^#].*smtpd_sasl_path.*/s/^/#/g" \
    /etc/postfix/master.cf

  sed -i \
    -e "/smtpd_sasl_path =.*/d" \
    -e "/smtpd_sasl_type =.*/d" \
    -e "/dovecot_destination_recipient_limit =.*/d" \
    /etc/postfix/main.cf

  gpasswd -a postfix sasl
}

function _setup_postfix_aliases
{
  _log 'debug' 'Setting up Postfix aliases'
  _create_aliases
}

function _setup_SRS
{
  _log 'debug' 'Setting up SRS'

  postconf -e 'sender_canonical_maps = tcp:localhost:10001'
  postconf -e "sender_canonical_classes = ${SRS_SENDER_CLASSES}"
  postconf -e 'recipient_canonical_maps = tcp:localhost:10002'
  postconf -e 'recipient_canonical_classes = envelope_recipient,header_recipient'
}

function _setup_dkim
{
  _log 'debug' 'Setting up DKIM'

  mkdir -p /etc/opendkim && touch /etc/opendkim/SigningTable

  # check if any keys are available
  if [[ -e "/tmp/docker-mailserver/opendkim/KeyTable" ]]
  then
    cp -a /tmp/docker-mailserver/opendkim/* /etc/opendkim/

    _log 'trace' "DKIM keys added for: $(ls /etc/opendkim/keys/)"
    _log 'trace' "Changing permissions on '/etc/opendkim'"

    chown -R opendkim:opendkim /etc/opendkim/
    chmod -R 0700 /etc/opendkim/keys/
  else
    _log 'debug' 'No DKIM key(s) provided - check the documentation on how to get your keys'
    [[ ! -f /etc/opendkim/KeyTable ]] && touch /etc/opendkim/KeyTable
  fi

  # setup nameservers parameter from /etc/resolv.conf if not defined
  if ! grep '^Nameservers' /etc/opendkim.conf
  then
    echo "Nameservers $(grep '^nameserver' /etc/resolv.conf | awk -F " " '{print $2}' | paste -sd ',' -)" >>/etc/opendkim.conf

    _log 'trace' "Nameservers added to '/etc/opendkim.conf'"
  fi
}

function _setup_postfix_vhost
{
  _log 'debug' 'Setting up Postfix vhost'
  _create_postfix_vhost
}

function _setup_postfix_inet_protocols
{
  _log 'trace' 'Setting up POSTFIX_INET_PROTOCOLS option'
  postconf -e "inet_protocols = ${POSTFIX_INET_PROTOCOLS}"
}

function _setup_dovecot_inet_protocols
{
  local PROTOCOL

  _log 'trace' 'Setting up DOVECOT_INET_PROTOCOLS option'

  # https://dovecot.org/doc/dovecot-example.conf
  if [[ ${DOVECOT_INET_PROTOCOLS} == "ipv4" ]]
  then
    PROTOCOL='*' # IPv4 only
  elif [[ ${DOVECOT_INET_PROTOCOLS} == "ipv6" ]]
  then
    PROTOCOL='[::]' # IPv6 only
  else
    # Unknown value, panic.
    dms_panic__invalid_value 'DOVECOT_INET_PROTOCOLS' "${DOVECOT_INET_PROTOCOLS}"
  fi

  sedfile -i "s|^#listen =.*|listen = ${PROTOCOL}|g" /etc/dovecot/dovecot.conf
}

function _setup_docker_permit
{
  _log 'debug' 'Setting up PERMIT_DOCKER option'

  local CONTAINER_IP CONTAINER_NETWORK

  unset CONTAINER_NETWORKS
  declare -a CONTAINER_NETWORKS

  CONTAINER_IP=$(ip addr show "${NETWORK_INTERFACE}" | \
    grep 'inet ' | sed 's|[^0-9\.\/]*||g' | cut -d '/' -f 1)
  CONTAINER_NETWORK=$(echo "${CONTAINER_IP}" | cut -d '.' -f1-2).0.0

  if [[ -z ${CONTAINER_IP} ]]
  then
    _log 'error' 'Detecting the container IP address failed'
    dms_panic__misconfigured 'NETWORK_INTERFACE' 'Network Setup [docker_permit]'
  fi

  while read -r IP
  do
    CONTAINER_NETWORKS+=("${IP}")
  done < <(ip -o -4 addr show type veth | grep -E -o '[0-9\.]+/[0-9]+')

  case "${PERMIT_DOCKER}" in
    ( 'none' )
      _log 'trace' "Clearing Postfix's 'mynetworks'"
      postconf -e "mynetworks ="
      ;;

    ( 'connected-networks' )
      for NETWORK in "${CONTAINER_NETWORKS[@]}"
      do
        NETWORK=$(_sanitize_ipv4_to_subnet_cidr "${NETWORK}")
        _log 'trace' "Adding Docker network '${NETWORK}' to Postfix's 'mynetworks'"
        postconf -e "$(postconf | grep '^mynetworks =') ${NETWORK}"
        echo "${NETWORK}" >> /etc/opendmarc/ignore.hosts
        echo "${NETWORK}" >> /etc/opendkim/TrustedHosts
      done
      ;;

    ( 'container' )
      _log 'trace' "Adding container IP address to Postfix's 'mynetworks'"
      postconf -e "$(postconf | grep '^mynetworks =') ${CONTAINER_IP}/32"
      echo "${CONTAINER_IP}/32" >> /etc/opendmarc/ignore.hosts
      echo "${CONTAINER_IP}/32" >> /etc/opendkim/TrustedHosts
      ;;

    ( 'host' )
      _log 'trace' "Adding '${CONTAINER_NETWORK}/16' to Postfix's 'mynetworks'"
      postconf -e "$(postconf | grep '^mynetworks =') ${CONTAINER_NETWORK}/16"
      echo "${CONTAINER_NETWORK}/16" >> /etc/opendmarc/ignore.hosts
      echo "${CONTAINER_NETWORK}/16" >> /etc/opendkim/TrustedHosts
      ;;

    ( 'network' )
      _log 'trace' "Adding Docker network to Postfix's 'mynetworks'"
      postconf -e "$(postconf | grep '^mynetworks =') 172.16.0.0/12"
      echo 172.16.0.0/12 >> /etc/opendmarc/ignore.hosts
      echo 172.16.0.0/12 >> /etc/opendkim/TrustedHosts
      ;;

    ( * )
      _log 'warn' "Invalid value for PERMIT_DOCKER: '${PERMIT_DOCKER}'"
      _log 'warn' "Clearing Postfix's 'mynetworks'"
      postconf -e "mynetworks ="
      ;;

  esac
}

# Requires ENABLE_POSTFIX_VIRTUAL_TRANSPORT=1
function _setup_postfix_virtual_transport
{
  _log 'trace' 'Setting up Postfix virtual transport'

  if [[ -z ${POSTFIX_DAGENT} ]]
  then
    dms_panic__no_env 'POSTFIX_DAGENT' 'Postfix Setup [virtual_transport]'
    return 1
  fi

  postconf -e "virtual_transport = ${POSTFIX_DAGENT}"
}

function _setup_postfix_override_configuration
{
  _log 'debug' 'Overriding / adjusting Postfix configuration with user-supplied values'

  if [[ -f /tmp/docker-mailserver/postfix-main.cf ]]
  then
    cat /tmp/docker-mailserver/postfix-main.cf >>/etc/postfix/main.cf
    # do not directly output to 'main.cf' as this causes a read-write-conflict
    postconf -n >/tmp/postfix-main-new.cf 2>/dev/null
    mv /tmp/postfix-main-new.cf /etc/postfix/main.cf
    _log 'trace' "Adjusted '/etc/postfix/main.cf' according to '/tmp/docker-mailserver/postfix-main.cf'"
  else
    _log 'trace' "No extra Postfix settings loaded because optional '/tmp/docker-mailserver/postfix-main.cf' was not provided"
  fi

  if [[ -f /tmp/docker-mailserver/postfix-master.cf ]]
  then
    while read -r LINE
    do
      if [[ ${LINE} =~ ^[0-9a-z] ]]
      then
        postconf -P "${LINE}"
      fi
    done < /tmp/docker-mailserver/postfix-master.cf
    _log 'trace' "Adjusted '/etc/postfix/master.cf' according to '/tmp/docker-mailserver/postfix-master.cf'"
  else
    _log 'trace' "No extra Postfix settings loaded because optional '/tmp/docker-mailserver/postfix-master.cf' was not provided"
  fi
}

function _setup_postfix_relay_hosts
{
  _setup_relayhost
}

function _setup_postfix_dhparam
{
  _setup_dhparam 'Postfix' '/etc/postfix/dhparams.pem'
}

function _setup_dovecot_dhparam
{
  _setup_dhparam 'Dovecot' '/etc/dovecot/dh.pem'
}

function _setup_dhparam
{
  local DH_SERVICE=$1
  local DH_DEST=$2
  local DH_CUSTOM='/tmp/docker-mailserver/dhparams.pem'

  _log 'debug' "Setting up ${DH_SERVICE} dhparam"

  if [[ -f ${DH_CUSTOM} ]]
  then # use custom supplied dh params (assumes they're probably insecure)
    _log 'trace' "${DH_SERVICE} will use custom provided DH paramters"
    _log 'warn' "Using self-generated dhparams is considered insecure - unless you know what you are doing, please remove '${DH_CUSTOM}'"

    cp -f "${DH_CUSTOM}" "${DH_DEST}"
  else # use official standardized dh params (provided via Dockerfile)
    _log 'trace' "${DH_SERVICE} will use official standardized DH parameters (ffdhe4096)."
  fi
}

function _setup_security_stack
{
  _log 'debug' 'Setting up Security Stack'

  # recreate auto-generated file
  local DMS_AMAVIS_FILE=/etc/amavis/conf.d/61-dms_auto_generated

  echo "# WARNING: this file is auto-generated." >"${DMS_AMAVIS_FILE}"
  echo "use strict;" >>"${DMS_AMAVIS_FILE}"

  # SpamAssassin
  if [[ ${ENABLE_SPAMASSASSIN} -eq 0 ]]
  then
    _log 'debug' 'SpamAssassin is disabled'
    echo "@bypass_spam_checks_maps = (1);" >>"${DMS_AMAVIS_FILE}"
  elif [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]]
  then
    _log 'debug' 'Enabling and configuring SpamAssassin'

    # shellcheck disable=SC2016
    sed -i -r 's|^\$sa_tag_level_deflt (.*);|\$sa_tag_level_deflt = '"${SA_TAG}"';|g' /etc/amavis/conf.d/20-debian_defaults

    # shellcheck disable=SC2016
    sed -i -r 's|^\$sa_tag2_level_deflt (.*);|\$sa_tag2_level_deflt = '"${SA_TAG2}"';|g' /etc/amavis/conf.d/20-debian_defaults

    # shellcheck disable=SC2016
    sed -i -r 's|^\$sa_kill_level_deflt (.*);|\$sa_kill_level_deflt = '"${SA_KILL}"';|g' /etc/amavis/conf.d/20-debian_defaults

    if [[ ${SA_SPAM_SUBJECT} == 'undef' ]]
    then
      # shellcheck disable=SC2016
      sed -i -r 's|^\$sa_spam_subject_tag (.*);|\$sa_spam_subject_tag = undef;|g' /etc/amavis/conf.d/20-debian_defaults
    else
      # shellcheck disable=SC2016
      sed -i -r 's|^\$sa_spam_subject_tag (.*);|\$sa_spam_subject_tag = '"'${SA_SPAM_SUBJECT}'"';|g' /etc/amavis/conf.d/20-debian_defaults
    fi

    # activate short circuits when SA BAYES is certain it has spam or ham.
    if [[ ${SA_SHORTCIRCUIT_BAYES_SPAM} -eq 1 ]]
    then
      # automatically activate the Shortcircuit Plugin
      sed -i -r 's|^# loadplugin Mail::SpamAssassin::Plugin::Shortcircuit|loadplugin Mail::SpamAssassin::Plugin::Shortcircuit|g' /etc/spamassassin/v320.pre
      sed -i -r 's|^# shortcircuit BAYES_99|shortcircuit BAYES_99|g' /etc/spamassassin/local.cf
    fi

    if [[ ${SA_SHORTCIRCUIT_BAYES_HAM} -eq 1 ]]
    then
      # automatically activate the Shortcircuit Plugin
      sed -i -r 's|^# loadplugin Mail::SpamAssassin::Plugin::Shortcircuit|loadplugin Mail::SpamAssassin::Plugin::Shortcircuit|g' /etc/spamassassin/v320.pre
      sed -i -r 's|^# shortcircuit BAYES_00|shortcircuit BAYES_00|g' /etc/spamassassin/local.cf
    fi

    if [[ -e /tmp/docker-mailserver/spamassassin-rules.cf ]]
    then
      cp /tmp/docker-mailserver/spamassassin-rules.cf /etc/spamassassin/
    fi

    if [[ ${SPAMASSASSIN_SPAM_TO_INBOX} -eq 1 ]]
    then
      _log 'trace' 'Configuring Spamassassin/Amavis to send SPAM to inbox'

      sed -i "s|\$final_spam_destiny.*=.*$|\$final_spam_destiny = D_PASS;|g" /etc/amavis/conf.d/49-docker-mailserver
      sed -i "s|\$final_bad_header_destiny.*=.*$|\$final_bad_header_destiny = D_PASS;|g" /etc/amavis/conf.d/49-docker-mailserver
    else
      _log 'trace' 'Configuring Spamassassin/Amavis to bounce SPAM'

      sed -i "s|\$final_spam_destiny.*=.*$|\$final_spam_destiny = D_BOUNCE;|g" /etc/amavis/conf.d/49-docker-mailserver
      sed -i "s|\$final_bad_header_destiny.*=.*$|\$final_bad_header_destiny = D_BOUNCE;|g" /etc/amavis/conf.d/49-docker-mailserver
    fi

    if [[ ${ENABLE_SPAMASSASSIN_KAM} -eq 1 ]]
    then
      _log 'trace' 'Configuring Spamassassin KAM'
      local SPAMASSASSIN_KAM_CRON_FILE=/etc/cron.daily/spamassassin_kam

      sa-update --import /etc/spamassassin/kam/kam.sa-channels.mcgrail.com.key

      cat >"${SPAMASSASSIN_KAM_CRON_FILE}" <<"EOM"
#! /bin/bash

RESULT=$(sa-update --gpgkey 24C063D8 --channel kam.sa-channels.mcgrail.com 2>&1)
EXIT_CODE=${?}

# see https://spamassassin.apache.org/full/3.1.x/doc/sa-update.html#exit_codes
if [[ ${EXIT_CODE} -ge 4 ]]
then
  echo -e "Updating SpamAssassin KAM failed:\n${RESULT}\n" >&2
  exit 1
fi

exit 0

EOM

      chmod +x "${SPAMASSASSIN_KAM_CRON_FILE}"
    fi
  fi

  # ClamAV
  if [[ ${ENABLE_CLAMAV} -eq 0 ]]
  then
    _log 'debug' 'ClamAV is disabled'
    echo '@bypass_virus_checks_maps = (1);' >>"${DMS_AMAVIS_FILE}"
  elif [[ ${ENABLE_CLAMAV} -eq 1 ]]
  then
    _log 'debug' 'Enabling ClamAV'
  fi

  echo '1;  # ensure a defined return' >>"${DMS_AMAVIS_FILE}"
  chmod 444 "${DMS_AMAVIS_FILE}"

  # Fail2ban
  if [[ ${ENABLE_FAIL2BAN} -eq 1 ]]
  then
    _log 'debug' 'Enabling Fail2Ban'

    if [[ -e /tmp/docker-mailserver/fail2ban-fail2ban.cf ]]
    then
      cp /tmp/docker-mailserver/fail2ban-fail2ban.cf /etc/fail2ban/fail2ban.local
    fi

    if [[ -e /tmp/docker-mailserver/fail2ban-jail.cf ]]
    then
      cp /tmp/docker-mailserver/fail2ban-jail.cf /etc/fail2ban/jail.d/user-jail.local
    fi
  else
    # disable logrotate config for fail2ban if not enabled
    rm -f /etc/logrotate.d/fail2ban
  fi

  # fix cron.daily for spamassassin
  sed -i \
    's|invoke-rc.d spamassassin reload|/etc/init\.d/spamassassin reload|g' \
    /etc/cron.daily/spamassassin

  # Amavis
  if [[ ${ENABLE_AMAVIS} -eq 1 ]]
  then
    _log 'debug' 'Enabling Amavis'
    if [[ -f /tmp/docker-mailserver/amavis.cf ]]
    then
      cp /tmp/docker-mailserver/amavis.cf /etc/amavis/conf.d/50-user
    fi

    sed -i -E \
      "s|(log_level).*|\1 = ${AMAVIS_LOGLEVEL};|g" \
      /etc/amavis/conf.d/49-docker-mailserver
  fi
}

function _setup_logrotate
{
  _log 'debug' 'Setting up logrotate'

  LOGROTATE='/var/log/mail/mail.log\n{\n  compress\n  copytruncate\n  delaycompress\n'

  case "${LOGROTATE_INTERVAL}" in
    ( 'daily' )
      _log 'trace' 'Setting postfix logrotate interval to daily'
      LOGROTATE="${LOGROTATE}  rotate 4\n  daily\n"
      ;;

    ( 'weekly' )
      _log 'trace' 'Setting postfix logrotate interval to weekly'
      LOGROTATE="${LOGROTATE}  rotate 4\n  weekly\n"
      ;;

    ( 'monthly' )
      _log 'trace' 'Setting postfix logrotate interval to monthly'
      LOGROTATE="${LOGROTATE}  rotate 4\n  monthly\n"
      ;;

    ( * )
      _log 'warn' 'LOGROTATE_INTERVAL not found in _setup_logrotate'
      ;;

  esac

  echo -e "${LOGROTATE}}" >/etc/logrotate.d/maillog
}

function _setup_mail_summary
{
  local ENABLED_MESSAGE
  ENABLED_MESSAGE="Enabling Postfix log summary reports with recipient '${PFLOGSUMM_RECIPIENT}'"

  case "${PFLOGSUMM_TRIGGER}" in
    ( 'daily_cron' )
      _log 'debug' "${ENABLED_MESSAGE}"
      _log 'trace' 'Creating daily cron job for pflogsumm report'

      cat >/etc/cron.daily/postfix-summary << EOM
#! /bin/bash

/usr/local/bin/report-pflogsumm-yesterday ${HOSTNAME} ${PFLOGSUMM_RECIPIENT} ${PFLOGSUMM_SENDER}
EOM

      chmod +x /etc/cron.daily/postfix-summary
      ;;

    ( 'logrotate' )
      _log 'debug' "${ENABLED_MESSAGE}"
      _log 'trace' 'Add postrotate action for pflogsumm report'
      sed -i \
        "s|}|  postrotate\n    /usr/local/bin/postfix-summary ${HOSTNAME} ${PFLOGSUMM_RECIPIENT} ${PFLOGSUMM_SENDER}\n  endscript\n}\n|" \
        /etc/logrotate.d/maillog
      ;;

    ( 'none' )
      _log 'debug' 'Postfix log summary reports disabled'
      ;;

    ( * )
      _log 'warn' "Invalid value for PFLOGSUMM_TRIGGER: '${PFLOGSUMM_TRIGGER}'"
      ;;

  esac
}

function _setup_logwatch
{
  echo 'LogFile = /var/log/mail/freshclam.log' >>/etc/logwatch/conf/logfiles/clam-update.conf
  echo "MailFrom = ${LOGWATCH_SENDER}" >>/etc/logwatch/conf/logwatch.conf

  case "${LOGWATCH_INTERVAL}" in
    ( 'daily' | 'weekly' )
      _log 'debug' "Enabling logwatch reports with recipient '${LOGWATCH_RECIPIENT}'"
      _log 'trace' "Creating ${LOGWATCH_INTERVAL} cron job for logwatch reports"

      local LOGWATCH_FILE INTERVAL

      LOGWATCH_FILE="/etc/cron.${LOGWATCH_INTERVAL}/logwatch"
      INTERVAL='--range Yesterday'

      if [[ ${LOGWATCH_INTERVAL} == 'weekly' ]]
      then
        INTERVAL="--range 'between -7 days and -1 days'"
      fi

      cat >"${LOGWATCH_FILE}" << EOM
#! /bin/bash

/usr/sbin/logwatch ${INTERVAL} --hostname ${HOSTNAME} --mailto ${LOGWATCH_RECIPIENT}
EOM
      chmod 744 "${LOGWATCH_FILE}"
      ;;

    ( 'none' )
      _log 'debug' 'Logwatch reports disabled.'
      ;;

    ( * )
      _log 'warn' "Invalid value for LOGWATCH_INTERVAL: '${LOGWATCH_INTERVAL}'"
      ;;

  esac
}

function _setup_user_patches
{
  local USER_PATCHES='/tmp/docker-mailserver/user-patches.sh'

  if [[ -f ${USER_PATCHES} ]]
  then
    _log 'debug' 'Applying user patches'
    /bin/bash "${USER_PATCHES}"
  else
    _log 'trace' "No optional '${USER_PATCHES}' provided"
  fi
}

function _setup_fail2ban
{
  _log 'debug' 'Setting up Fail2Ban'

  if [[ ${FAIL2BAN_BLOCKTYPE} != 'reject' ]]
  then
    echo -e '[Init]\nblocktype = drop' >/etc/fail2ban/action.d/nftables-common.local
  fi

  echo '[Definition]' >/etc/fail2ban/filter.d/custom.conf
}

function _setup_dnsbl_disable
{
  _log 'debug' 'Disabling postfix DNS block list (zen.spamhaus.org)'

  sedfile -i \
    '/^smtpd_recipient_restrictions = / s/, reject_rbl_client zen.spamhaus.org//' \
    /etc/postfix/main.cf

  _log 'debug' 'Disabling postscreen DNS block lists'
  postconf -e "postscreen_dnsbl_action = ignore"
  postconf -e "postscreen_dnsbl_sites = "
}

function _setup_fetchmail
{
  _log 'trace' 'Preparing Fetchmail configuration'

  local CONFIGURATION FETCHMAILRC

  CONFIGURATION='/tmp/docker-mailserver/fetchmail.cf'
  FETCHMAILRC='/etc/fetchmailrc'

  if [[ -f ${CONFIGURATION} ]]
  then
    cat /etc/fetchmailrc_general "${CONFIGURATION}" >"${FETCHMAILRC}"
  else
    cat /etc/fetchmailrc_general >"${FETCHMAILRC}"
  fi

  chmod 700 "${FETCHMAILRC}"
  chown fetchmail:root "${FETCHMAILRC}"
}

function _setup_fetchmail_parallel
{
  _log 'trace' 'Setting up Fetchmail parallel'
  mkdir /etc/fetchmailrc.d/

  # Split the content of /etc/fetchmailrc into
  # smaller fetchmailrc files per server [poll] entries. Each
  # separate fetchmailrc file is stored in /etc/fetchmailrc.d
  #
  # The sole purpose for this is to work around what is known
  # as the Fetchmail IMAP idle issue.
  function _fetchmailrc_split
  {
    local FETCHMAILRC='/etc/fetchmailrc'
    local FETCHMAILRCD='/etc/fetchmailrc.d'
    local DEFAULT_FILE="${FETCHMAILRCD}/defaults"

    if [[ ! -r ${FETCHMAILRC} ]]
    then
      _log 'warn' "File '${FETCHMAILRC}' not found"
      return 1
    fi

    if [[ ! -d ${FETCHMAILRCD} ]]
    then
      if ! mkdir "${FETCHMAILRCD}"
      then
        _log 'warn' "Unable to create folder '${FETCHMAILRCD}'"
        return 1
      fi
    fi

    local COUNTER=0 SERVER=0
    while read -r LINE
    do
      if [[ ${LINE} =~ poll ]]
      then
        # If we read "poll" then we reached a new server definition
        # We need to create a new file with fetchmail defaults from
        # /etc/fetcmailrc
        COUNTER=$(( COUNTER + 1 ))
        SERVER=1
        cat "${DEFAULT_FILE}" >"${FETCHMAILRCD}/fetchmail-${COUNTER}.rc"
        echo "${LINE}" >>"${FETCHMAILRCD}/fetchmail-${COUNTER}.rc"
      elif [[ ${SERVER} -eq 0 ]]
      then
        # We have not yet found "poll". Let's assume we are still reading
        # the default settings from /etc/fetchmailrc file
        echo "${LINE}" >>"${DEFAULT_FILE}"
      else
        # Just the server settings that need to be added to the specific rc.d file
        echo "${LINE}" >>"${FETCHMAILRCD}/fetchmail-${COUNTER}.rc"
      fi
    done < <(_get_valid_lines_from_file "${FETCHMAILRC}")

    rm "${DEFAULT_FILE}"
  }

  _fetchmailrc_split

  local COUNTER=0
  for RC in /etc/fetchmailrc.d/fetchmail-*.rc
  do
    COUNTER=$(( COUNTER + 1 ))
    cat >"/etc/supervisor/conf.d/fetchmail-${COUNTER}.conf" << EOF
[program:fetchmail-${COUNTER}]
startsecs=0
autostart=false
autorestart=true
stdout_logfile=/var/log/supervisor/%(program_name)s.log
stderr_logfile=/var/log/supervisor/%(program_name)s.log
user=fetchmail
command=/usr/bin/fetchmail -f ${RC} -v --nodetach --daemon %(ENV_FETCHMAIL_POLL)s -i /var/lib/fetchmail/.fetchmail-UIDL-cache --pidfile /var/run/fetchmail/%(program_name)s.pid
EOF
    chmod 700 "${RC}"
    chown fetchmail:root "${RC}"
  done

  supervisorctl reread
  supervisorctl update
}

function _setup_timezone
{
  _log 'debug' "Setting timezone to '${TZ}'"

  local ZONEINFO_FILE="/usr/share/zoneinfo/${TZ}"

  if [[ ! -e ${ZONEINFO_FILE} ]]
  then
    _log 'warn' "Cannot find timezone '${TZ}'"
    return 1
  fi

  if ln -fs "${ZONEINFO_FILE}" /etc/localtime \
  && dpkg-reconfigure -f noninteractive tzdata &>/dev/null
  then
    _log 'trace' "Set time zone to '${TZ}'"
  else
    _log 'warn' "Setting timezone to '${TZ}' failed"
    return 1
  fi
}
