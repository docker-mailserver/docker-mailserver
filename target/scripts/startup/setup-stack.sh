#! /bin/bash

function setup
{
  _notify 'tasklog' 'Configuring mail server'
  for FUNC in "${FUNCS_SETUP[@]}"
  do
    ${FUNC}
  done
}

function _setup_supervisor
{
  if ! grep -q "loglevel = ${SUPERVISOR_LOGLEVEL}" /etc/supervisor/supervisord.conf
  then
    case "${SUPERVISOR_LOGLEVEL}" in
      'critical' | 'error' | 'info' | 'debug' )
        sed -i -E \
          "s|(loglevel).*|\1 = ${SUPERVISOR_LOGLEVEL}|g" \
          /etc/supervisor/supervisord.conf

        supervisorctl reload
        ;;

      'warn' )
        return 0
        ;;

      * )
        _notify 'err' \
          "SUPERVISOR_LOGLEVEL '${SUPERVISOR_LOGLEVEL}' unknown. Using default 'warn'"
        ;;

    esac
  fi

  return 0
}

function _setup_default_vars
{
  _notify 'task' 'Setting up default variables'

  # update POSTMASTER_ADDRESS - must be done done after _check_hostname
  POSTMASTER_ADDRESS="${POSTMASTER_ADDRESS:=postmaster@${DOMAINNAME}}"

  # update REPORT_SENDER - must be done done after _check_hostname
  REPORT_SENDER="${REPORT_SENDER:=mailserver-report@${HOSTNAME}}"
  PFLOGSUMM_SENDER="${PFLOGSUMM_SENDER:=${REPORT_SENDER}}"

  # set PFLOGSUMM_TRIGGER here for backwards compatibility
  # when REPORT_RECIPIENT is on the old method should be used
  # ! needs to be a string comparison
  if [[ ${REPORT_RECIPIENT} == '0' ]]
  then
    PFLOGSUMM_TRIGGER="${PFLOGSUMM_TRIGGER:=none}"
  else
    PFLOGSUMM_TRIGGER="${PFLOGSUMM_TRIGGER:=logrotate}"
  fi

  # expand address to simplify the rest of the script
  if [[ ${REPORT_RECIPIENT} == '0' ]] || [[ ${REPORT_RECIPIENT} == '1' ]]
  then
    REPORT_RECIPIENT="${POSTMASTER_ADDRESS}"
  fi

  PFLOGSUMM_RECIPIENT="${PFLOGSUMM_RECIPIENT:=${REPORT_RECIPIENT}}"
  LOGWATCH_RECIPIENT="${LOGWATCH_RECIPIENT:=${REPORT_RECIPIENT}}"

  local VAR
  for VAR in "${!VARS[@]}"
  do
    echo "export ${VAR}='${VARS[${VAR}]}'" >>/root/.bashrc
  done

  {
    echo "export PFLOGSUMM_SENDER='${PFLOGSUMM_SENDER}'"
    echo "export PFLOGSUMM_TRIGGER='${PFLOGSUMM_TRIGGER}'"
    echo "export PFLOGSUMM_RECIPIENT='${PFLOGSUMM_RECIPIENT}'"
    echo "export POSTMASTER_ADDRESS='${POSTMASTER_ADDRESS}'"
    echo "export REPORT_RECIPIENT='${REPORT_RECIPIENT}'"
    echo "export REPORT_SENDER='${REPORT_SENDER}'"
  } >>/root/.bashrc
}

# File/folder permissions are fine when using docker volumes, but may be wrong
# when file system folders are mounted into the container.
# Set the expected values and create missing folders/files just in case.
function _setup_file_permissions
{
  _notify 'task' 'Setting file/folder permissions'

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

function _setup_chksum_file
{
  _notify 'task' 'Setting up configuration checksum file'

  if [[ -d /tmp/docker-mailserver ]]
  then
    _notify 'inf' "Creating ${CHKSUM_FILE}"
    _monitored_files_checksums >"${CHKSUM_FILE}"
  else
    # We could just skip the file, but perhaps config can be added later?
    # If so it must be processed by the check for changes script
    _notify 'inf' "Creating empty ${CHKSUM_FILE} (no config)"
    touch "${CHKSUM_FILE}"
  fi
}

function _setup_mailname
{
  _notify 'task' 'Setting up mailname / creating /etc/mailname'
  echo "${DOMAINNAME}" >/etc/mailname
}

function _setup_amavis
{
  if [[ ${ENABLE_AMAVIS} -eq 1 ]]
  then
    _notify 'task' 'Setting up Amavis'
    sed -i \
      "s|^#\$myhostname = \"mail.example.com\";|\$myhostname = \"${HOSTNAME}\";|" \
      /etc/amavis/conf.d/05-node_id
  else
    _notify 'task' 'Remove Amavis from postfix configuration'
    sed -i 's|content_filter =.*|content_filter =|' /etc/postfix/main.cf
    [[ ${ENABLE_CLAMAV} -eq 1 ]] && _notify 'warn' 'ClamAV will not work when Amavis is disabled. Remove ENABLE_AMAVIS=0 from your configuration to fix it.'
    [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]] && _notify 'warn' 'Spamassassin will not work when Amavis is disabled. Remove ENABLE_AMAVIS=0 from your configuration to fix it.'
  fi
}

function _setup_dmarc_hostname
{
  _notify 'task' 'Setting up dmarc'
  sed -i -e \
    "s|^AuthservID.*$|AuthservID          '${HOSTNAME}'|g" \
    -e "s|^TrustedAuthservIDs.*$|TrustedAuthservIDs  '${HOSTNAME}'|g" \
    /etc/opendmarc.conf
}

function _setup_postfix_hostname
{
  _notify 'task' 'Applying hostname and domainname to Postfix'
  postconf -e "myhostname = ${HOSTNAME}"
  postconf -e "mydomain = ${DOMAINNAME}"
}

function _setup_dovecot_hostname
{
  _notify 'task' 'Applying hostname to Dovecot'
  sed -i \
    "s|^#hostname =.*$|hostname = '${HOSTNAME}'|g" \
    /etc/dovecot/conf.d/15-lda.conf
}

function _setup_dovecot
{
  _notify 'task' 'Setting up Dovecot'

  cp -a /usr/share/dovecot/protocols.d /etc/dovecot/
  # disable pop3 (it will be eventually enabled later in the script, if requested)
  mv /etc/dovecot/protocols.d/pop3d.protocol /etc/dovecot/protocols.d/pop3d.protocol.disab
  mv /etc/dovecot/protocols.d/managesieved.protocol /etc/dovecot/protocols.d/managesieved.protocol.disab
  sed -i -e 's|#ssl = yes|ssl = yes|g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's|#port = 993|port = 993|g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's|#port = 995|port = 995|g' /etc/dovecot/conf.d/10-master.conf
  sed -i -e 's|#ssl = yes|ssl = required|g' /etc/dovecot/conf.d/10-ssl.conf
  sed -i 's|^postmaster_address = .*$|postmaster_address = '"${POSTMASTER_ADDRESS}"'|g' /etc/dovecot/conf.d/15-lda.conf

  # set mail_location according to mailbox format
  case "${DOVECOT_MAILBOX_FORMAT}" in
    "sdbox" | "mdbox" )
      _notify 'inf' "Dovecot ${DOVECOT_MAILBOX_FORMAT} format configured"
      sed -i -e \
        "s|^mail_location = .*$|mail_location = ${DOVECOT_MAILBOX_FORMAT}:\/var\/mail\/%d\/%n|g" \
        /etc/dovecot/conf.d/10-mail.conf

      _notify 'inf' 'Enabling cron job for dbox purge'
      mv /etc/cron.d/dovecot-purge.disabled /etc/cron.d/dovecot-purge
      chmod 644 /etc/cron.d/dovecot-purge
      ;;

    * )
      _notify 'inf' "Dovecot maildir format configured (default)"
      sed -i -e 's|^mail_location = .*$|mail_location = maildir:\/var\/mail\/%d\/%n|g' /etc/dovecot/conf.d/10-mail.conf
      ;;

  esac

  # enable Managesieve service by setting the symlink
  # to the configuration file Dovecot will actually find
  if [[ ${ENABLE_MANAGESIEVE} -eq 1 ]]
  then
    _notify 'inf' 'Sieve management enabled'
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
    _notify 'inf' "Spam messages will be moved to the Junk folder."
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
    _notify 'task' 'Setting up Dovecot quota'

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

      if [[ ! -f /tmp/docker-mailserver/dovecot-quotas.cf ]]
      then
        _notify 'inf' "'/tmp/docker-mailserver/dovecot-quotas.cf' is not provided. Using default quotas."
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
  _notify 'task' 'Setting up Dovecot Local User'
  : >/etc/postfix/vmailbox
  : >/etc/dovecot/userdb

  if [[ -f /tmp/docker-mailserver/postfix-accounts.cf ]] && [[ ${ENABLE_LDAP} -ne 1 ]]
  then
    _notify 'inf' "Checking file line endings"
    sed -i 's|\r||g' /tmp/docker-mailserver/postfix-accounts.cf

    _notify 'inf' "Regenerating postfix user list"
    echo "# WARNING: this file is auto-generated. Modify /tmp/docker-mailserver/postfix-accounts.cf to edit the user list." > /etc/postfix/vmailbox

    # checking that /tmp/docker-mailserver/postfix-accounts.cf ends with a newline
    # shellcheck disable=SC1003
    sed -i -e '$a\' /tmp/docker-mailserver/postfix-accounts.cf

    chown dovecot:dovecot /etc/dovecot/userdb
    chmod 640 /etc/dovecot/userdb

    sed -i -e '/\!include auth-ldap\.conf\.ext/s/^/#/' /etc/dovecot/conf.d/10-auth.conf
    sed -i -e '/\!include auth-passwdfile\.inc/s/^#//' /etc/dovecot/conf.d/10-auth.conf

    # creating users ; 'pass' is encrypted
    # comments and empty lines are ignored
    while IFS=$'|' read -r LOGIN PASS USER_ATTRIBUTES
    do
      # Setting variables for better readability
      USER=$(echo "${LOGIN}" | cut -d @ -f1)
      DOMAIN=$(echo "${LOGIN}" | cut -d @ -f2)

      # test if user has a defined quota
      if [[ -f /tmp/docker-mailserver/dovecot-quotas.cf ]]
      then
        declare -a USER_QUOTA
        IFS=':' ; read -r -a USER_QUOTA < <(grep "${USER}@${DOMAIN}:" -i /tmp/docker-mailserver/dovecot-quotas.cf)
        unset IFS

        [[ ${#USER_QUOTA[@]} -eq 2 ]] && USER_ATTRIBUTES="${USER_ATTRIBUTES} userdb_quota_rule=*:bytes=${USER_QUOTA[1]}"
      fi

      # Let's go!
      _notify 'inf' "user '${USER}' for domain '${DOMAIN}' with password '********', attr=${USER_ATTRIBUTES}"

      echo "${LOGIN} ${DOMAIN}/${USER}/" >> /etc/postfix/vmailbox
      # User database for dovecot has the following format:
      # user:password:uid:gid:(gecos):home:(shell):extra_fields
      # Example :
      # ${LOGIN}:${PASS}:5000:5000::/var/mail/${DOMAIN}/${USER}::userdb_mail=maildir:/var/mail/${DOMAIN}/${USER}
      echo "${LOGIN}:${PASS}:5000:5000::/var/mail/${DOMAIN}/${USER}::${USER_ATTRIBUTES}" >> /etc/dovecot/userdb
      mkdir -p "/var/mail/${DOMAIN}/${USER}"

      # Copy user provided sieve file, if present
      if [[ -e "/tmp/docker-mailserver/${LOGIN}.dovecot.sieve" ]]
      then
        cp "/tmp/docker-mailserver/${LOGIN}.dovecot.sieve" "/var/mail/${DOMAIN}/${USER}/.dovecot.sieve"
      fi

      echo "${DOMAIN}" >> /tmp/vhost.tmp
    done < <(grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-accounts.cf)
  else
    _notify 'inf' "'/tmp/docker-mailserver/postfix-accounts.cf' is not provided. No mail account created."
  fi

  if ! grep '@' /tmp/docker-mailserver/postfix-accounts.cf 2>/dev/null | grep -q '|'
  then
    if [[ ${ENABLE_LDAP} -eq 0 ]]
    then
      _shutdown 'Unless using LDAP, you need at least 1 email account to start Dovecot.'
    fi
  fi
}

function _setup_ldap
{
  _notify 'task' 'Setting up Ldap'
  _notify 'inf' 'Checking for custom configs'

  for i in 'users' 'groups' 'aliases' 'domains'
  do
    local FPATH="/tmp/docker-mailserver/ldap-${i}.cf"
    if [[ -f ${FPATH} ]]
    then
      cp "${FPATH}" "/etc/postfix/ldap-${i}.cf"
    fi
  done

  _notify 'inf' 'Starting to override configs'

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
    configomat.sh "LDAP_" "${FILE}"
  done

  _notify 'inf' "Configuring dovecot LDAP"

  declare -A DOVECOT_LDAP_MAPPING

  DOVECOT_LDAP_MAPPING["DOVECOT_BASE"]="${DOVECOT_BASE:="${LDAP_SEARCH_BASE}"}"
  DOVECOT_LDAP_MAPPING["DOVECOT_DN"]="${DOVECOT_DN:="${LDAP_BIND_DN}"}"
  DOVECOT_LDAP_MAPPING["DOVECOT_DNPASS"]="${DOVECOT_DNPASS:="${LDAP_BIND_PW}"}"
  DOVECOT_LDAP_MAPPING["DOVECOT_URIS"]="${DOVECOT_URIS:="${DOVECOT_HOSTS:="${LDAP_SERVER_HOST}"}"}"

  # Add protocol to DOVECOT_URIS so that we can use dovecot's "uris" option:
  # https://doc.dovecot.org/configuration_manual/authentication/ldap/
  if [[ "${DOVECOT_LDAP_MAPPING["DOVECOT_URIS"]}" != *'://'* ]]
  then
    DOVECOT_LDAP_MAPPING["DOVECOT_URIS"]="ldap://${DOVECOT_LDAP_MAPPING["DOVECOT_URIS"]}"
  fi

  # Default DOVECOT_PASS_FILTER to the same value as DOVECOT_USER_FILTER
  DOVECOT_LDAP_MAPPING["DOVECOT_PASS_FILTER"]="${DOVECOT_PASS_FILTER:="${DOVECOT_USER_FILTER}"}"

  for VAR in "${!DOVECOT_LDAP_MAPPING[@]}"
  do
    export "${VAR}=${DOVECOT_LDAP_MAPPING[${VAR}]}"
  done

  configomat.sh "DOVECOT_" "/etc/dovecot/dovecot-ldap.conf.ext"

  # add domainname to vhost
  echo "${DOMAINNAME}" >>/tmp/vhost.tmp

  _notify 'inf' "Enabling dovecot LDAP authentification"

  sed -i -e '/\!include auth-ldap\.conf\.ext/s/^#//' /etc/dovecot/conf.d/10-auth.conf
  sed -i -e '/\!include auth-passwdfile\.inc/s/^/#/' /etc/dovecot/conf.d/10-auth.conf

  _notify 'inf' "Configuring LDAP"

  if [[ -f /etc/postfix/ldap-users.cf ]]
  then
    postconf -e "virtual_mailbox_maps = ldap:/etc/postfix/ldap-users.cf" || \
    _notify 'inf' "==> Warning: /etc/postfix/ldap-user.cf not found"
  fi

  if [[ -f /etc/postfix/ldap-domains.cf ]]
  then
    postconf -e "virtual_mailbox_domains = /etc/postfix/vhost, ldap:/etc/postfix/ldap-domains.cf" || \
    _notify 'inf' "==> Warning: /etc/postfix/ldap-domains.cf not found"
  fi

  if [[ -f /etc/postfix/ldap-aliases.cf ]] && [[ -f /etc/postfix/ldap-groups.cf ]]
  then
    postconf -e "virtual_alias_maps = ldap:/etc/postfix/ldap-aliases.cf, ldap:/etc/postfix/ldap-groups.cf" || \
    _notify 'inf' "==> Warning: /etc/postfix/ldap-aliases.cf or /etc/postfix/ldap-groups.cf not found"
  fi

  # shellcheck disable=SC2016
  sed -i 's|mydestination = \$myhostname, |mydestination = |' /etc/postfix/main.cf

  return 0
}

function _setup_postgrey
{
  _notify 'inf' "Configuring postgrey"

  sed -i -E \
    's|, reject_rbl_client zen.spamhaus.org$|, reject_rbl_client zen.spamhaus.org, check_policy_service inet:127.0.0.1:10023|' \
    /etc/postfix/main.cf

  sed -i -e \
    "s|\"--inet=127.0.0.1:10023\"|\"--inet=127.0.0.1:10023 --delay=${POSTGREY_DELAY} --max-age=${POSTGREY_MAX_AGE} --auto-whitelist-clients=${POSTGREY_AUTO_WHITELIST_CLIENTS}\"|" \
    /etc/default/postgrey

  TEXT_FOUND=$(grep -c -i "POSTGREY_TEXT" /etc/default/postgrey)

  if [[ ${TEXT_FOUND} -eq 0 ]]
  then
    printf "POSTGREY_TEXT=\"%s\"\n\n" "${POSTGREY_TEXT}" >>/etc/default/postgrey
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
  _notify 'inf' "Configuring postscreen"
  sed -i \
    -e "s|postscreen_dnsbl_action = enforce|postscreen_dnsbl_action = ${POSTSCREEN_ACTION}|" \
    -e "s|postscreen_greet_action = enforce|postscreen_greet_action = ${POSTSCREEN_ACTION}|" \
    -e "s|postscreen_bare_newline_action = enforce|postscreen_bare_newline_action = ${POSTSCREEN_ACTION}|" /etc/postfix/main.cf
}

function _setup_postfix_sizelimits
{
  _notify 'inf' "Configuring postfix message size limit"
  postconf -e "message_size_limit = ${POSTFIX_MESSAGE_SIZE_LIMIT}"

  _notify 'inf' "Configuring postfix mailbox size limit"
  postconf -e "mailbox_size_limit = ${POSTFIX_MAILBOX_SIZE_LIMIT}"

  _notify 'inf' "Configuring postfix virtual mailbox size limit"
  postconf -e "virtual_mailbox_limit = ${POSTFIX_MAILBOX_SIZE_LIMIT}"
}

function _setup_postfix_smtputf8
{
  _notify 'inf' "Configuring postfix smtputf8 support (disable)"
  postconf -e "smtputf8_enable = no"
}

function _setup_spoof_protection
{
  _notify 'inf' "Configuring Spoof Protection"
  sed -i \
    's|smtpd_sender_restrictions =|smtpd_sender_restrictions = reject_authenticated_sender_login_mismatch,|' \
    /etc/postfix/main.cf

  if [[ ${ENABLE_LDAP} -eq 1 ]]
  then
    if [[ -z ${LDAP_QUERY_FILTER_SENDERS} ]]; then
      postconf -e "smtpd_sender_login_maps = ldap:/etc/postfix/ldap-users.cf ldap:/etc/postfix/ldap-aliases.cf ldap:/etc/postfix/ldap-groups.cf"
    else
      postconf -e "smtpd_sender_login_maps = ldap:/etc/postfix/ldap-senders.cf"
    fi
  else
    if [[ -f /etc/postfix/regexp ]]
    then
      postconf -e "smtpd_sender_login_maps = unionmap:{ texthash:/etc/postfix/virtual, hash:/etc/aliases, pcre:/etc/postfix/maps/sender_login_maps.pcre, pcre:/etc/postfix/regexp }"
    else
      postconf -e "smtpd_sender_login_maps = texthash:/etc/postfix/virtual, hash:/etc/aliases, pcre:/etc/postfix/maps/sender_login_maps.pcre"
    fi
  fi
}

function _setup_postfix_access_control
{
  _notify 'inf' 'Configuring user access'

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
  _notify 'task' "Setting up SASLAUTHD"

  # checking env vars and setting defaults
  [[ -z ${SASLAUTHD_MECHANISMS:-} ]] && SASLAUTHD_MECHANISMS=pam
  [[ -z ${SASLAUTHD_LDAP_SERVER} ]] && SASLAUTHD_LDAP_SERVER="${LDAP_SERVER_HOST}"
  [[ -z ${SASLAUTHD_LDAP_FILTER} ]] && SASLAUTHD_LDAP_FILTER='(&(uniqueIdentifier=%u)(mailEnabled=TRUE))'

  [[ -z ${SASLAUTHD_LDAP_BIND_DN} ]] && SASLAUTHD_LDAP_BIND_DN="${LDAP_BIND_DN}"
  [[ -z ${SASLAUTHD_LDAP_PASSWORD} ]] && SASLAUTHD_LDAP_PASSWORD="${LDAP_BIND_PW}"
  [[ -z ${SASLAUTHD_LDAP_SEARCH_BASE} ]] && SASLAUTHD_LDAP_SEARCH_BASE="${LDAP_SEARCH_BASE}"

  if [[ "${SASLAUTHD_LDAP_SERVER}" != *'://'* ]]
  then
    SASLAUTHD_LDAP_SERVER="ldap://${SASLAUTHD_LDAP_SERVER}"
  fi

  [[ -z ${SASLAUTHD_LDAP_START_TLS} ]] && SASLAUTHD_LDAP_START_TLS=no
  [[ -z ${SASLAUTHD_LDAP_TLS_CHECK_PEER} ]] && SASLAUTHD_LDAP_TLS_CHECK_PEER=no
  [[ -z ${SASLAUTHD_LDAP_AUTH_METHOD} ]] && SASLAUTHD_LDAP_AUTH_METHOD=bind

  if [[ -z ${SASLAUTHD_LDAP_TLS_CACERT_FILE} ]]
  then
    SASLAUTHD_LDAP_TLS_CACERT_FILE=""
  else
    SASLAUTHD_LDAP_TLS_CACERT_FILE="ldap_tls_cacert_file: ${SASLAUTHD_LDAP_TLS_CACERT_FILE}"
  fi

  if [[ -z ${SASLAUTHD_LDAP_TLS_CACERT_DIR} ]]
  then
    SASLAUTHD_LDAP_TLS_CACERT_DIR=""
  else
    SASLAUTHD_LDAP_TLS_CACERT_DIR="ldap_tls_cacert_dir: ${SASLAUTHD_LDAP_TLS_CACERT_DIR}"
  fi

  if [[ -z ${SASLAUTHD_LDAP_PASSWORD_ATTR} ]]
  then
    SASLAUTHD_LDAP_PASSWORD_ATTR=""
  else
    SASLAUTHD_LDAP_PASSWORD_ATTR="ldap_password_attr: ${SASLAUTHD_LDAP_PASSWORD_ATTR}"
  fi

  if [[ -z ${SASLAUTHD_LDAP_MECH} ]]
  then
    SASLAUTHD_LDAP_MECH=""
  else
    SASLAUTHD_LDAP_MECH="ldap_mech: ${SASLAUTHD_LDAP_MECH}"
  fi

  if [[ ! -f /etc/saslauthd.conf ]]
  then
    _notify 'inf' 'Creating /etc/saslauthd.conf'
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
  _notify 'task' 'Setting up Postfix Aliases'

  : >/etc/postfix/virtual
  : >/etc/postfix/regexp

  if [[ -f /tmp/docker-mailserver/postfix-virtual.cf ]]
  then
    # fixing old virtual user file
    if grep -q ",$" /tmp/docker-mailserver/postfix-virtual.cf
    then
      sed -i -e "s|, |,|g" -e "s|,$||g" /tmp/docker-mailserver/postfix-virtual.cf
    fi

    cp -f /tmp/docker-mailserver/postfix-virtual.cf /etc/postfix/virtual

    # the `to` is important, don't delete it
    # shellcheck disable=SC2034
    while read -r FROM TO
    do
      UNAME=$(echo "${FROM}" | cut -d @ -f1)
      DOMAIN=$(echo "${FROM}" | cut -d @ -f2)

      # if they are equal it means the line looks like: "user1     other@domain.tld"
      [[ ${UNAME} != "${DOMAIN}" ]] && echo "${DOMAIN}" >>/tmp/vhost.tmp
    done < <(grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-virtual.cf || true)
  else
    _notify 'inf' "Warning '/tmp/docker-mailserver/postfix-virtual.cf' is not provided. No mail alias/forward created."
  fi

  if [[ -f /tmp/docker-mailserver/postfix-regexp.cf ]]
  then
    _notify 'inf' "Adding regexp alias file postfix-regexp.cf"

    cp -f /tmp/docker-mailserver/postfix-regexp.cf /etc/postfix/regexp
    sed -i -E \
      's|virtual_alias_maps(.*)|virtual_alias_maps\1 pcre:/etc/postfix/regexp|g' \
      /etc/postfix/main.cf
  fi

  _notify 'inf' 'Configuring root alias'

  echo "root: ${POSTMASTER_ADDRESS}" > /etc/aliases

  if [[ -f /tmp/docker-mailserver/postfix-aliases.cf ]]
  then
    cat /tmp/docker-mailserver/postfix-aliases.cf >>/etc/aliases
  else
    _notify 'inf' "'/tmp/docker-mailserver/postfix-aliases.cf' is not provided, it will be auto created."
    : >/tmp/docker-mailserver/postfix-aliases.cf
  fi

  postalias /etc/aliases
}

function _setup_SRS
{
  _notify 'task' 'Setting up SRS'

  postconf -e "sender_canonical_maps = tcp:localhost:10001"
  postconf -e "sender_canonical_classes = ${SRS_SENDER_CLASSES}"
  postconf -e "recipient_canonical_maps = tcp:localhost:10002"
  postconf -e "recipient_canonical_classes = envelope_recipient,header_recipient"
}

function _setup_dkim
{
  _notify 'task' 'Setting up DKIM'

  mkdir -p /etc/opendkim && touch /etc/opendkim/SigningTable

  # check if any keys are available
  if [[ -e "/tmp/docker-mailserver/opendkim/KeyTable" ]]
  then
    cp -a /tmp/docker-mailserver/opendkim/* /etc/opendkim/

    _notify 'inf' "DKIM keys added for: $(ls -C /etc/opendkim/keys/)"
    _notify 'inf' "Changing permissions on /etc/opendkim"

    chown -R opendkim:opendkim /etc/opendkim/
    chmod -R 0700 /etc/opendkim/keys/
  else
    _notify 'warn' 'No DKIM key provided. Check the documentation on how to get your keys.'
    [[ ! -f "/etc/opendkim/KeyTable" ]] && touch "/etc/opendkim/KeyTable"
  fi

  # setup nameservers paramater from /etc/resolv.conf if not defined
  if ! grep '^Nameservers' /etc/opendkim.conf
  then
    echo "Nameservers $(grep '^nameserver' /etc/resolv.conf | awk -F " " '{print $2}' | paste -sd ',' -)" >> /etc/opendkim.conf

    _notify 'inf' "Nameservers added to /etc/opendkim.conf"
  fi
}

function _setup_ssl
{
  _notify 'task' 'Setting up SSL'

  local POSTFIX_CONFIG_MAIN='/etc/postfix/main.cf'
  local POSTFIX_CONFIG_MASTER='/etc/postfix/master.cf'
  local DOVECOT_CONFIG_SSL='/etc/dovecot/conf.d/10-ssl.conf'

  local TMP_DMS_TLS_PATH='/tmp/docker-mailserver/ssl' # config volume
  local DMS_TLS_PATH='/etc/dms/tls'
  mkdir -p "${DMS_TLS_PATH}"

  # Primary certificate to serve for TLS
  function _set_certificate
  {
    local POSTFIX_KEY_WITH_FULLCHAIN=${1}
    local DOVECOT_KEY=${1}
    local DOVECOT_CERT=${1}

    # If a 2nd param is provided, a separate key and cert was received instead of a fullkeychain
    if [[ -n ${2} ]]
    then
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
  function _set_alt_certificate
  {
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
    # Otherwise without `docker-compose down` first, a `docker-compose up` may
    # persist previous container state and cause a failure in postfix configuration.
    sedfile -i "s|^smtpd_tls_chain_files =.*|& ${PRIVATE_KEY_ALT} ${CERT_CHAIN_ALT}|" "${POSTFIX_CONFIG_MAIN}"

    # Dovecot configuration
    # Conditionally checks for `#`, in the event that internal container state is accidentally persisted,
    # can be caused by: `docker-compose up` run again after a `ctrl+c`, without running `docker-compose down`
    sedfile -i -r \
      -e "s|^#?(ssl_alt_key =).*|\1 <${PRIVATE_KEY_ALT}|" \
      -e "s|^#?(ssl_alt_cert =).*|\1 <${CERT_CHAIN_ALT}|" \
      "${DOVECOT_CONFIG_SSL}"
  }

  function _apply_tls_level
  {
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

  # TLS strength/level configuration
  case "${TLS_LEVEL}" in
    ( "modern" )
      local TLS_MODERN_SUITE='ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384'
      local TLS_MODERN_IGNORE='!SSLv2,!SSLv3,!TLSv1,!TLSv1.1'
      local TLS_MODERN_MIN='TLSv1.2'

      _apply_tls_level "${TLS_MODERN_SUITE}" "${TLS_MODERN_IGNORE}" "${TLS_MODERN_MIN}"

      _notify 'inf' "TLS configured with 'modern' ciphers"
      ;;

    ( "intermediate" )
      local TLS_INTERMEDIATE_SUITE='ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA'
      local TLS_INTERMEDIATE_IGNORE='!SSLv2,!SSLv3'
      local TLS_INTERMEDIATE_MIN='TLSv1'

      _apply_tls_level "${TLS_INTERMEDIATE_SUITE}" "${TLS_INTERMEDIATE_IGNORE}" "${TLS_INTERMEDIATE_MIN}"

      # Lowers the minimum acceptable TLS version connection to `TLSv1` (from Debian upstream `TLSv1.2`)
      # Lowers Security Level to `1` (from Debian upstream `2`, openssl release defaults to `1`)
      # https://www.openssl.org/docs/man1.1.1/man3/SSL_CTX_set_security_level.html
      # https://wiki.debian.org/ContinuousIntegration/TriagingTips/openssl-1.1.1
      # https://dovecot.org/pipermail/dovecot/2020-October/120225.html
      # TODO: This is a fix for Debian Bullseye Dovecot. Can remove when we only support TLS >=1.2.
      # WARNING: This applies to all processes that use openssl and respect these settings.
      sedfile -i -r \
        -e 's|^(MinProtocol).*|\1 = TLSv1|' \
        -e 's|^(CipherString).*|\1 = DEFAULT@SECLEVEL=1|' \
        /usr/lib/ssl/openssl.cnf

      _notify 'inf' "TLS configured with 'intermediate' ciphers"
      ;;

    ( * )
      _notify 'err' "TLS_LEVEL not found [ in ${FUNCNAME[0]} ]"
      ;;

  esac

  local SCOPE_SSL_TYPE="TLS Setup [SSL_TYPE=${SSL_TYPE}]"
  # SSL certificate Configuration
  # TODO: Refactor this feature, it's been extended multiple times for specific inputs/providers unnecessarily.
  # NOTE: Some `SSL_TYPE` logic uses mounted certs/keys directly, some make an internal copy either retaining filename or renaming.
  case "${SSL_TYPE}" in
    ( "letsencrypt" )
      _notify 'inf' "Configuring SSL using 'letsencrypt'"

      # letsencrypt folders and files mounted in /etc/letsencrypt
      local LETSENCRYPT_DOMAIN=""
      local LETSENCRYPT_KEY=""

      # 2020 feature intended for Traefik v2 support only:
      # https://github.com/docker-mailserver/docker-mailserver/pull/1553
      # Uses `key.pem` and `fullchain.pem`
      if [[ -f /etc/letsencrypt/acme.json ]]
      then
        if ! _extract_certs_from_acme "${SSL_DOMAIN}"
        then
          if ! _extract_certs_from_acme "${HOSTNAME}"
          then
            _extract_certs_from_acme "${DOMAINNAME}"
          fi
        fi
      fi

      # first determine the letsencrypt domain by checking both the full hostname or just the domainname if a SAN is used in the cert
      if [[ -e /etc/letsencrypt/live/${HOSTNAME}/fullchain.pem ]]
      then
        LETSENCRYPT_DOMAIN=${HOSTNAME}
      elif [[ -e /etc/letsencrypt/live/${DOMAINNAME}/fullchain.pem ]]
      then
        LETSENCRYPT_DOMAIN=${DOMAINNAME}
      else
        _notify 'err' "Cannot access '/etc/letsencrypt/live/${HOSTNAME}/fullchain.pem' or '/etc/letsencrypt/live/${DOMAINNAME}/fullchain.pem'"
        return 1
      fi

      # then determine the keyfile to use
      if [[ -n ${LETSENCRYPT_DOMAIN} ]]
      then
        if [[ -e /etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/privkey.pem ]]
        then
          LETSENCRYPT_KEY="privkey"
        elif [[ -e /etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/key.pem ]]
        then
          LETSENCRYPT_KEY="key"
        else
          _notify 'err' "Cannot access '/etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/privkey.pem' nor 'key.pem'"
          return 1
        fi
      fi

      # finally, make the changes to the postfix and dovecot configurations
      if [[ -n ${LETSENCRYPT_KEY} ]]
      then
        _notify 'inf' "Adding ${LETSENCRYPT_DOMAIN} SSL certificate to the postfix and dovecot configuration"

        # LetsEncrypt `fullchain.pem` and `privkey.pem` contents are detailed here from CertBot:
        # https://certbot.eff.org/docs/using.html#where-are-my-certificates
        # `key.pem` was added for `simp_le` support (2016): https://github.com/docker-mailserver/docker-mailserver/pull/288
        # `key.pem` is also a filename used by the `_extract_certs_from_acme` method (implemented for Traefik v2 only)
        local PRIVATE_KEY="/etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/${LETSENCRYPT_KEY}.pem"
        local CERT_CHAIN="/etc/letsencrypt/live/${LETSENCRYPT_DOMAIN}/fullchain.pem"

        _set_certificate "${PRIVATE_KEY}" "${CERT_CHAIN}"

        _notify 'inf' "SSL configured with 'letsencrypt' certificates"
      fi
      return 0
      ;;

    ( "custom" ) # (hard-coded path) Use a private key with full certificate chain all in a single PEM file.
      _notify 'inf' "Adding ${HOSTNAME} SSL certificate"

      # NOTE: Dovecot works fine still as both values are bundled into the keychain
      local COMBINED_PEM_NAME="${HOSTNAME}-full.pem"
      local TMP_KEY_WITH_FULLCHAIN="${TMP_DMS_TLS_PATH}/${COMBINED_PEM_NAME}"
      local KEY_WITH_FULLCHAIN="${DMS_TLS_PATH}/${COMBINED_PEM_NAME}"

      if [[ -f ${TMP_KEY_WITH_FULLCHAIN} ]]
      then
        cp "${TMP_KEY_WITH_FULLCHAIN}" "${KEY_WITH_FULLCHAIN}"
        chmod 600 "${KEY_WITH_FULLCHAIN}"

        _set_certificate "${KEY_WITH_FULLCHAIN}"

        _notify 'inf' "SSL configured with 'CA signed/custom' certificates"
      else
        dms_panic__no_file "${TMP_KEY_WITH_FULLCHAIN}" "${SCOPE_SSL_TYPE}"
      fi
      ;;

    ( "manual" ) # (dynamic path via ENV) Use separate private key and cert/chain files (should be PEM encoded)
      _notify 'inf' "Configuring certificates using key ${SSL_KEY_PATH} and cert ${SSL_CERT_PATH}"

      # Source files are copied internally to these destinations:
      local PRIVATE_KEY="${DMS_TLS_PATH}/key"
      local CERT_CHAIN="${DMS_TLS_PATH}/cert"

      # Fail early:
      if [[ -z ${SSL_KEY_PATH} ]] && [[ -z ${SSL_CERT_PATH} ]]
      then
        dms_panic__no_env 'SSL_KEY_PATH or SSL_CERT_PATH' "${SCOPE_SSL_TYPE}"
      fi

      if [[ -n ${SSL_ALT_KEY_PATH} ]] \
      && [[ -n ${SSL_ALT_CERT_PATH} ]] \
      && [[ ! -f ${SSL_ALT_KEY_PATH} ]] \
      && [[ ! -f ${SSL_ALT_CERT_PATH} ]]
      then
        dms_panic__no_file "(ALT) ${SSL_ALT_KEY_PATH} or ${SSL_ALT_CERT_PATH}" "${SCOPE_SSL_TYPE}"
      fi

      if [[ -f ${SSL_KEY_PATH} ]] && [[ -f ${SSL_CERT_PATH} ]]
      then
        cp "${SSL_KEY_PATH}" "${PRIVATE_KEY}"
        cp "${SSL_CERT_PATH}" "${CERT_CHAIN}"
        chmod 600 "${PRIVATE_KEY}"
        chmod 644 "${CERT_CHAIN}"

        _set_certificate "${PRIVATE_KEY}" "${CERT_CHAIN}"

        # Support for a fallback certificate, useful for hybrid/dual ECDSA + RSA certs
        if [[ -n ${SSL_ALT_KEY_PATH} ]] && [[ -n ${SSL_ALT_CERT_PATH} ]]
        then
          _notify 'inf' "Configuring fallback certificates using key ${SSL_ALT_KEY_PATH} and cert ${SSL_ALT_CERT_PATH}"

          _set_alt_certificate "${SSL_ALT_KEY_PATH}" "${SSL_ALT_CERT_PATH}"
        else
          # If the Dovecot settings for alt cert has been enabled (doesn't start with `#`),
          # but required ENV var is missing, reset to disabled state:
          sed -i -r \
            -e 's|^(ssl_alt_key =).*|#\1 </path/to/alternative/key.pem|' \
            -e 's|^(ssl_alt_cert =).*|#\1 </path/to/alternative/cert.pem|' \
            "${DOVECOT_CONFIG_SSL}"
        fi

        _notify 'inf' "SSL configured with 'Manual' certificates"
      else
        dms_panic__no_file "${SSL_KEY_PATH} or ${SSL_CERT_PATH}" "${SCOPE_SSL_TYPE}"
      fi
      ;;

    ( "self-signed" ) # (hard-coded path) Use separate private key and cert/chain files (should be PEM encoded), expects self-signed CA
      _notify 'inf' "Adding ${HOSTNAME} SSL certificate"

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

        _notify 'inf' "SSL configured with 'self-signed' certificates"
      else
        dms_panic__no_file "${SS_KEY} or ${SS_CERT}" "${SCOPE_SSL_TYPE}"
      fi
      ;;

    ( '' ) # No SSL/TLS certificate used/required, plaintext auth permitted over insecure connections
      _notify 'warn' "(INSECURE!) SSL configured with plain text access. DO NOT USE FOR PRODUCTION DEPLOYMENT."
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
      # smtpd_tls_wrappermode (default: 'yes' for service port 'smtps') | http://www.postfix.org/postconf.5.html#smtpd_tls_wrappermode
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
      # Inbound 465 (aka service port aliases: submissions / smtps) for Postfix to receive over implicit TLS (eg from MUA or functioning as a relay host).
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
      dms_panic__invalid_value 'SSL_TYPE' "${SCOPE_TLS_LEVEL}"
      ;;

  esac
}

function _setup_postfix_vhost
{
  _notify 'task' "Setting up Postfix vhost"

  if [[ -f /tmp/vhost.tmp ]]
  then
    sort < /tmp/vhost.tmp | uniq > /etc/postfix/vhost
    rm /tmp/vhost.tmp
  elif [[ ! -f /etc/postfix/vhost ]]
  then
    touch /etc/postfix/vhost
  fi
}

function _setup_inet_protocols
{
  _notify 'task' 'Setting up POSTFIX_INET_PROTOCOLS option'
  postconf -e "inet_protocols = ${POSTFIX_INET_PROTOCOLS}"
}

function _setup_docker_permit
{
  _notify 'task' 'Setting up PERMIT_DOCKER Option'

  local CONTAINER_IP CONTAINER_NETWORK

  unset CONTAINER_NETWORKS
  declare -a CONTAINER_NETWORKS

  CONTAINER_IP=$(ip addr show "${NETWORK_INTERFACE}" | \
    grep 'inet ' | sed 's|[^0-9\.\/]*||g' | cut -d '/' -f 1)
  CONTAINER_NETWORK="$(echo "${CONTAINER_IP}" | cut -d '.' -f1-2).0.0"

  if [[ -z ${CONTAINER_IP} ]]
  then
    _notify 'err' 'Detecting the container IP address failed.'
    dms_panic__misconfigured 'NETWORK_INTERFACE' 'Network Setup [docker_permit]'
  fi

  while read -r IP
  do
    CONTAINER_NETWORKS+=("${IP}")
  done < <(ip -o -4 addr show type veth | grep -E -o '[0-9\.]+/[0-9]+')

  case "${PERMIT_DOCKER}" in
    "host" )
      _notify 'inf' "Adding ${CONTAINER_NETWORK}/16 to my networks"
      postconf -e "$(postconf | grep '^mynetworks =') ${CONTAINER_NETWORK}/16"
      echo "${CONTAINER_NETWORK}/16" >> /etc/opendmarc/ignore.hosts
      echo "${CONTAINER_NETWORK}/16" >> /etc/opendkim/TrustedHosts
      ;;

    "network" )
      _notify 'inf' "Adding docker network in my networks"
      postconf -e "$(postconf | grep '^mynetworks =') 172.16.0.0/12"
      echo 172.16.0.0/12 >> /etc/opendmarc/ignore.hosts
      echo 172.16.0.0/12 >> /etc/opendkim/TrustedHosts
      ;;

    "connected-networks" )
      for NETWORK in "${CONTAINER_NETWORKS[@]}"
      do
        NETWORK=$(_sanitize_ipv4_to_subnet_cidr "${NETWORK}")
        _notify 'inf' "Adding docker network ${NETWORK} in my networks"
        postconf -e "$(postconf | grep '^mynetworks =') ${NETWORK}"
        echo "${NETWORK}" >> /etc/opendmarc/ignore.hosts
        echo "${NETWORK}" >> /etc/opendkim/TrustedHosts
      done
      ;;

    * )
      _notify 'inf' 'Adding container ip in my networks'
      postconf -e "$(postconf | grep '^mynetworks =') ${CONTAINER_IP}/32"
      echo "${CONTAINER_IP}/32" >> /etc/opendmarc/ignore.hosts
      echo "${CONTAINER_IP}/32" >> /etc/opendkim/TrustedHosts
      ;;

  esac
}

# Requires ENABLE_POSTFIX_VIRTUAL_TRANSPORT=1
function _setup_postfix_virtual_transport
{
  _notify 'task' 'Setting up Postfix virtual transport'

  if [[ -z ${POSTFIX_DAGENT} ]]
  then
    dms_panic__no_env 'POSTFIX_DAGENT' 'Postfix Setup [virtual_transport]'
    return 1
  fi

  postconf -e "virtual_transport = ${POSTFIX_DAGENT}"
}

function _setup_postfix_override_configuration
{
  _notify 'task' 'Setting up Postfix Override configuration'

  if [[ -f /tmp/docker-mailserver/postfix-main.cf ]]
  then
    while read -r LINE
    do
      # all valid postfix options start with a lower case letter
      # http://www.postfix.org/postconf.5.html
      if [[ ${LINE} =~ ^[a-z] ]]
      then
        postconf -e "${LINE}"
      fi
    done < /tmp/docker-mailserver/postfix-main.cf
    _notify 'inf' "Loaded '/tmp/docker-mailserver/postfix-main.cf'"
  else
    _notify 'inf' "No extra postfix settings loaded because optional '/tmp/docker-mailserver/postfix-main.cf' not provided."
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
    _notify 'inf' "Loaded '/tmp/docker-mailserver/postfix-master.cf'"
  else
    _notify 'inf' "No extra postfix settings loaded because optional '/tmp/docker-mailserver/postfix-master.cf' not provided."
  fi

  _notify 'inf' "set the compatibility level to 2"
  postconf compatibility_level=2
}

function _setup_postfix_sasl_password
{
  _notify 'task' 'Setting up Postfix SASL Password'

  # support general SASL password
  if [[ -n ${SASL_PASSWD} ]]
  then
    # create SASL password
    echo "${SASL_PASSWD}" > /etc/postfix/sasl_passwd
    _notify 'inf' "Loaded SASL_PASSWD"
  else
    rm -f /etc/postfix/sasl_passwd
    _notify 'inf' "Warning: 'SASL_PASSWD' is not provided. /etc/postfix/sasl_passwd not created."
  fi
}

function _setup_postfix_default_relay_host
{
  _notify 'task' 'Applying default relay host to Postfix'

  _notify 'inf' "Applying default relay host ${DEFAULT_RELAY_HOST} to /etc/postfix/main.cf"
  postconf -e "relayhost = ${DEFAULT_RELAY_HOST}"
}

function _setup_postfix_relay_hosts
{
  _notify 'task' 'Setting up Postfix Relay Hosts'

  _relayhost_default_port_fallback

  # shellcheck disable=SC2153
  _notify 'inf' "Setting up outgoing email relaying via ${RELAY_HOST}:${RELAY_PORT}"

  _relayhost_sasl
  _populate_relayhost_map
  _relayhost_configure_postfix
}

function _setup_postfix_dhparam
{
  _setup_dhparam 'postfix' '/etc/postfix/dhparams.pem'
}

function _setup_dovecot_dhparam
{
  _setup_dhparam 'dovecot' '/etc/dovecot/dh.pem'
}

function _setup_dhparam
{
  local DH_SERVICE=$1
  local DH_DEST=$2
  local DH_CUSTOM=/tmp/docker-mailserver/dhparams.pem

  _notify 'task' "Setting up ${DH_SERVICE} dhparam"

  if [[ -f ${DH_CUSTOM} ]]
  then # use custom supplied dh params (assumes they're probably insecure)
    _notify 'inf' "${DH_SERVICE} will use custom provided DH paramters."
    _notify 'warn' "Using self-generated dhparams is considered insecure. Unless you know what you are doing, please remove ${DH_CUSTOM}."

    cp -f "${DH_CUSTOM}" "${DH_DEST}"
  else # use official standardized dh params (provided via Dockerfile)
    _notify 'inf' "${DH_SERVICE} will use official standardized DH parameters (ffdhe4096)."
  fi
}

function _setup_security_stack
{
  _notify 'task' "Setting up Security Stack"

  # recreate auto-generated file
  local DMS_AMAVIS_FILE=/etc/amavis/conf.d/61-dms_auto_generated

  echo "# WARNING: this file is auto-generated." >"${DMS_AMAVIS_FILE}"
  echo "use strict;" >>"${DMS_AMAVIS_FILE}"

  # SpamAssassin
  if [[ ${ENABLE_SPAMASSASSIN} -eq 0 ]]
  then
    _notify 'warn' "Spamassassin is disabled. You can enable it with 'ENABLE_SPAMASSASSIN=1'"
    echo "@bypass_spam_checks_maps = (1);" >>"${DMS_AMAVIS_FILE}"
  elif [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]]
  then
    _notify 'inf' "Enabling and configuring spamassassin"

    # shellcheck disable=SC2016
    SA_TAG=${SA_TAG:="2.0"} && sed -i -r 's|^\$sa_tag_level_deflt (.*);|\$sa_tag_level_deflt = '"${SA_TAG}"';|g' /etc/amavis/conf.d/20-debian_defaults

    # shellcheck disable=SC2016
    SA_TAG2=${SA_TAG2:="6.31"} && sed -i -r 's|^\$sa_tag2_level_deflt (.*);|\$sa_tag2_level_deflt = '"${SA_TAG2}"';|g' /etc/amavis/conf.d/20-debian_defaults

    # shellcheck disable=SC2016
    SA_KILL=${SA_KILL:="6.31"} && sed -i -r 's|^\$sa_kill_level_deflt (.*);|\$sa_kill_level_deflt = '"${SA_KILL}"';|g' /etc/amavis/conf.d/20-debian_defaults

    SA_SPAM_SUBJECT=${SA_SPAM_SUBJECT:="***SPAM*** "}

    if [[ ${SA_SPAM_SUBJECT} == "undef" ]]
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
      _notify 'inf' 'Configuring Spamassassin/Amavis to send SPAM to inbox'

      sed -i "s|\$final_spam_destiny.*=.*$|\$final_spam_destiny = D_PASS;|g" /etc/amavis/conf.d/49-docker-mailserver
      sed -i "s|\$final_bad_header_destiny.*=.*$|\$final_bad_header_destiny = D_PASS;|g" /etc/amavis/conf.d/49-docker-mailserver
    else
      _notify 'inf' 'Configuring Spamassassin/Amavis to bounce SPAM'

      sed -i "s|\$final_spam_destiny.*=.*$|\$final_spam_destiny = D_BOUNCE;|g" /etc/amavis/conf.d/49-docker-mailserver
      sed -i "s|\$final_bad_header_destiny.*=.*$|\$final_bad_header_destiny = D_BOUNCE;|g" /etc/amavis/conf.d/49-docker-mailserver

      if [[ ${VARS[SPAMASSASSIN_SPAM_TO_INBOX_SET]} == 'not set' ]]
      then
        _notify 'warn' 'Spam messages WILL NOT BE DELIVERED, you will NOT be notified of ANY message bounced. Please define SPAMASSASSIN_SPAM_TO_INBOX explicitly.'
      fi
    fi
  fi

  # Clamav
  if [[ ${ENABLE_CLAMAV} -eq 0 ]]
  then
    _notify 'warn' "Clamav is disabled. You can enable it with 'ENABLE_CLAMAV=1'"
    echo '@bypass_virus_checks_maps = (1);' >>"${DMS_AMAVIS_FILE}"
  elif [[ ${ENABLE_CLAMAV} -eq 1 ]]
  then
    _notify 'inf' 'Enabling clamav'
  fi

  echo '1;  # ensure a defined return' >>"${DMS_AMAVIS_FILE}"
  chmod 444 "${DMS_AMAVIS_FILE}"

  # Fail2ban
  if [[ ${ENABLE_FAIL2BAN} -eq 1 ]]
  then
    _notify 'inf' 'Fail2ban enabled'

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
  sed -i -e 's|invoke-rc.d spamassassin reload|/etc/init\.d/spamassassin reload|g' /etc/cron.daily/spamassassin

  # Amavis
  if [[ ${ENABLE_AMAVIS} -eq 1 ]]
  then
    _notify 'inf' 'Amavis enabled'
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
  _notify 'inf' 'Setting up logrotate'

  LOGROTATE='/var/log/mail/mail.log\n{\n  compress\n  copytruncate\n  delaycompress\n'

  case "${LOGROTATE_INTERVAL}" in
    'daily' )
      _notify 'inf' 'Setting postfix logrotate interval to daily'
      LOGROTATE="${LOGROTATE}  rotate 4\n  daily\n"
      ;;

    'weekly' )
      _notify 'inf' 'Setting postfix logrotate interval to weekly'
      LOGROTATE="${LOGROTATE}  rotate 4\n  weekly\n"
      ;;

    'monthly' )
      _notify 'inf' 'Setting postfix logrotate interval to monthly'
      LOGROTATE="${LOGROTATE}  rotate 4\n  monthly\n"
      ;;

    * )
      _notify 'warn' 'LOGROTATE_INTERVAL not found in _setup_logrotate'
      ;;

  esac

  echo -e "${LOGROTATE}}" >/etc/logrotate.d/maillog
}

function _setup_mail_summary
{
  _notify 'inf' "Enable postfix summary with recipient ${PFLOGSUMM_RECIPIENT}"

  case "${PFLOGSUMM_TRIGGER}" in
    'daily_cron' )
      _notify 'inf' 'Creating daily cron job for pflogsumm report'

      echo '#! /bin/bash' > /etc/cron.daily/postfix-summary
      echo "/usr/local/bin/report-pflogsumm-yesterday ${HOSTNAME} ${PFLOGSUMM_RECIPIENT} ${PFLOGSUMM_SENDER}" >>/etc/cron.daily/postfix-summary

      chmod +x /etc/cron.daily/postfix-summary
      ;;

    'logrotate' )
      _notify 'inf' 'Add postrotate action for pflogsumm report'
      sed -i \
        "s|}|  postrotate\n    /usr/local/bin/postfix-summary ${HOSTNAME} ${PFLOGSUMM_RECIPIENT} ${PFLOGSUMM_SENDER}\n  endscript\n}\n|" \
        /etc/logrotate.d/maillog
      ;;

    'none' )
      _notify 'inf' 'Postfix log summary reports disabled.'
      ;;

    * )
      _notify 'err' 'PFLOGSUMM_TRIGGER not found in _setup_mail_summery'
      ;;

  esac
}

function _setup_logwatch
{
  _notify 'inf' "Enable logwatch reports with recipient ${LOGWATCH_RECIPIENT}"

  echo 'LogFile = /var/log/mail/freshclam.log' >>/etc/logwatch/conf/logfiles/clam-update.conf

  case "${LOGWATCH_INTERVAL}" in
    'daily' )
      _notify 'inf' "Creating daily cron job for logwatch reports"
      echo "#! /bin/bash" > /etc/cron.daily/logwatch
      echo "/usr/sbin/logwatch --range Yesterday --hostname ${HOSTNAME} --mailto ${LOGWATCH_RECIPIENT}" \
        >>/etc/cron.daily/logwatch
      chmod 744 /etc/cron.daily/logwatch
      ;;

    'weekly' )
      _notify 'inf' "Creating weekly cron job for logwatch reports"
      echo "#! /bin/bash" > /etc/cron.weekly/logwatch
      echo "/usr/sbin/logwatch --range 'between -7 days and -1 days' --hostname ${HOSTNAME} --mailto ${LOGWATCH_RECIPIENT}" \
        >>/etc/cron.weekly/logwatch
      chmod 744 /etc/cron.weekly/logwatch
      ;;

    'none' )
      _notify 'inf' 'Logwatch reports disabled.'
      ;;

    * )
      _notify 'warn' 'LOGWATCH_INTERVAL not found in _setup_logwatch'
      ;;

  esac
}

function _setup_user_patches
{
  local USER_PATCHES="/tmp/docker-mailserver/user-patches.sh"

  if [[ -f ${USER_PATCHES} ]]
  then
    _notify 'tasklog' 'Applying user patches'
    if [[ ! -x ${USER_PATCHES} ]]; then
      _notify 'inf' 'Making user patches script executable'
      chmod +x "${USER_PATCHES}"
    fi
    ${USER_PATCHES}
  else
    _notify 'inf' "No optional '/tmp/docker-mailserver/user-patches.sh' provided. Skipping."
  fi
}

function _setup_environment
{
  _notify 'task' 'Setting up /etc/environment'

  if ! grep -q "# Docker Mail Server" /etc/environment
  then
    echo "# Docker Mail Server" >>/etc/environment
    echo "VIRUSMAILS_DELETE_DELAY=${VIRUSMAILS_DELETE_DELAY}" >>/etc/environment
  fi
}

function _setup_fail2ban
{
  _notify 'task' 'Setting up fail2ban'
  if [[ ${FAIL2BAN_BLOCKTYPE} != "reject" ]]
  then
    echo -e "[Init]\nblocktype = DROP" > /etc/fail2ban/action.d/iptables-common.local
  fi
}
