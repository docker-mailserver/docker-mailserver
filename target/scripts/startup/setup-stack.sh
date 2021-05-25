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

  # moved from docker file, copy or generate default self-signed cert
  if [[ -f /var/mail-state/lib-dovecot/dovecot.pem ]] && [[ ${ONE_DIR} -eq 1 ]]
  then
    _notify 'inf' "Copying default dovecot cert"
    cp /var/mail-state/lib-dovecot/dovecot.key /etc/dovecot/ssl/
    cp /var/mail-state/lib-dovecot/dovecot.pem /etc/dovecot/ssl/
  fi

  if [[ ! -f /etc/dovecot/ssl/dovecot.pem ]]
  then
    _notify 'inf' 'Generating default Dovecot cert'
    /usr/share/dovecot/mkcert.sh

    if [[ ${ONE_DIR} -eq 1 ]]
    then
      mkdir -p /var/mail-state/lib-dovecot
      cp /etc/dovecot/ssl/dovecot.key /var/mail-state/lib-dovecot/
      cp /etc/dovecot/ssl/dovecot.pem /var/mail-state/lib-dovecot/
    fi
  fi

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
        _notify 'inf' "'config/docker-mailserver/dovecot-quotas.cf' is not provided. Using default quotas."
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
    echo "# WARNING: this file is auto-generated. Modify config/postfix-accounts.cf to edit user list." > /etc/postfix/vmailbox

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
    _notify 'inf' "'config/docker-mailserver/postfix-accounts.cf' is not provided. No mail account created."
  fi

  if ! grep '@' /tmp/docker-mailserver/postfix-accounts.cf 2>/dev/null | grep -q '|'
  then
    if [[ ${ENABLE_LDAP} -eq 0 ]]
    then
      _notify 'fatal' 'Unless using LDAP, you need at least 1 email account to start Dovecot.'
      _defunc
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
    _notify 'inf' "Warning 'config/postfix-virtual.cf' is not provided. No mail alias/forward created."
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
    _notify 'inf' "'config/postfix-aliases.cf' is not provided and will be auto created."
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
  local DOVECOT_CONFIG_SSL='/etc/dovecot/conf.d/10-ssl.conf'

  # Primary certificate to serve for TLS
  function _set_certificate
  {
    local POSTFIX_KEY_WITH_FULLCHAIN=${1}
    local DOVECOT_KEY=${1}
    local DOVECOT_CERT=${1}

    # If 2nd param is provided, we've been provided separate key and cert instead of a fullkeychain
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
    # May be a single PEM file or a sequence of files, so long as the order is key->leaf->chain
    sed -i "s|^smtpd_tls_chain_files =.*|smtpd_tls_chain_files = ${POSTFIX_KEY_WITH_FULLCHAIN}|" "${POSTFIX_CONFIG_MAIN}"

    # Dovecot configuration
    sed -i "s|^ssl_key = <.*|ssl_key = <${DOVECOT_KEY}|" "${DOVECOT_CONFIG_SSL}"
    sed -i "s|^ssl_cert = <.*|ssl_cert = <${DOVECOT_CERT}|" "${DOVECOT_CONFIG_SSL}"
  }

  # Enables supporting two certificate types such as ECDSA with an RSA fallback
  function _set_alt_certificate
  {
    local COPY_KEY_FROM_PATH=$1
    local COPY_CERT_FROM_PATH=$2
    local PRIVATE_KEY_ALT='/etc/postfix/ssl/fallback_key'
    local CERT_CHAIN_ALT='/etc/postfix/ssl/fallback_cert'

    cp "${COPY_KEY_FROM_PATH}" "${PRIVATE_KEY_ALT}"
    cp "${COPY_CERT_FROM_PATH}" "${CERT_CHAIN_ALT}"
    chmod 600 "${PRIVATE_KEY_ALT}"
    chmod 600 "${CERT_CHAIN_ALT}"

    # Postfix configuration
    # NOTE: This operation doesn't replace the line, it appends to the end of the line.
    # Thus this method should only be used when this line has explicitly been replaced earlier in the script.
    # Otherwise without `docker-compose down` first, a `docker-compose up` may
    # persist previous container state and cause a failure in postfix configuration.
    sed -i "s|^smtpd_tls_chain_files =.*|& ${PRIVATE_KEY_ALT} ${CERT_CHAIN_ALT}|" "${POSTFIX_CONFIG_MAIN}"

    # Dovecot configuration
    # Conditionally checks for `#`, in the event that internal container state is accidentally persisted,
    # can be caused by: `docker-compose up` run again after a `ctrl+c`, without running `docker-compose down`
    sed -i "s|^#\?ssl_alt_key = <.*|ssl_alt_key = <${PRIVATE_KEY_ALT}|" "${DOVECOT_CONFIG_SSL}"
    sed -i "s|^#\?ssl_alt_cert = <.*|ssl_alt_cert = <${CERT_CHAIN_ALT}|" "${DOVECOT_CONFIG_SSL}"
  }

  function _apply_tls_level
  {
    local TLS_CIPHERS_ALLOW=$1
    local TLS_PROTOCOL_IGNORE=$2
    local TLS_PROTOCOL_MINIMUM=$3

    # Postfix configuration
    sed -i "s|^smtpd_tls_mandatory_protocols =.*|smtpd_tls_mandatory_protocols = ${TLS_PROTOCOL_IGNORE}|" "${POSTFIX_CONFIG_MAIN}"
    sed -i "s|^smtpd_tls_protocols =.*|smtpd_tls_protocols = ${TLS_PROTOCOL_IGNORE}|" "${POSTFIX_CONFIG_MAIN}"
    sed -i "s|^smtp_tls_protocols =.*|smtp_tls_protocols = ${TLS_PROTOCOL_IGNORE}|" "${POSTFIX_CONFIG_MAIN}"
    sed -i "s|^tls_high_cipherlist =.*|tls_high_cipherlist = ${TLS_CIPHERS_ALLOW}|" "${POSTFIX_CONFIG_MAIN}"

    # Dovecot configuration (secure by default though)
    sed -i "s|^ssl_min_protocol =.*|ssl_min_protocol = ${TLS_PROTOCOL_MINIMUM}|" "${DOVECOT_CONFIG_SSL}"
    sed -i "s|^ssl_cipher_list =.*|ssl_cipher_list = ${TLS_CIPHERS_ALLOW}|" "${DOVECOT_CONFIG_SSL}"
  }

  # TLS strength/level configuration
  case "${TLS_LEVEL}" in
    "modern" )
      local TLS_MODERN_SUITE='ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384'
      local TLS_MODERN_IGNORE='!SSLv2,!SSLv3,!TLSv1,!TLSv1.1'
      local TLS_MODERN_MIN='TLSv1.2'

      _apply_tls_level "${TLS_MODERN_SUITE}" "${TLS_MODERN_IGNORE}" "${TLS_MODERN_MIN}"

      _notify 'inf' "TLS configured with 'modern' ciphers"
      ;;

    "intermediate" )
      local TLS_INTERMEDIATE_SUITE='ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES256-SHA'
      local TLS_INTERMEDIATE_IGNORE='!SSLv2,!SSLv3'
      local TLS_INTERMEDIATE_MIN='TLSv1'

      _apply_tls_level "${TLS_INTERMEDIATE_SUITE}" "${TLS_INTERMEDIATE_IGNORE}" "${TLS_INTERMEDIATE_MIN}"

      _notify 'inf' "TLS configured with 'intermediate' ciphers"
      ;;

    * )
      _notify 'err' "TLS_LEVEL not found [ in ${FUNCNAME[0]} ]"
      ;;

  esac

  # SSL certificate Configuration
  # TODO: Refactor this feature, it's been extended multiple times for specific inputs/providers unnecessarily.
  # NOTE: Some `SSL_TYPE` logic uses mounted certs/keys directly, some make an internal copy either retaining filename or renaming, chmod inconsistent.
  case "${SSL_TYPE}" in
    "letsencrypt" )
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
    "custom" )
      # Adding CA signed SSL certificate if provided in 'postfix/ssl' folder
      if [[ -e /tmp/docker-mailserver/ssl/${HOSTNAME}-full.pem ]]
      then
        _notify 'inf' "Adding ${HOSTNAME} SSL certificate"

        mkdir -p /etc/postfix/ssl
        cp "/tmp/docker-mailserver/ssl/${HOSTNAME}-full.pem" /etc/postfix/ssl

        # Private key with full certificate chain all in a single PEM file
        # NOTE: Dovecot works fine still as both values are bundled into the keychain
        local KEY_WITH_FULLCHAIN='/etc/postfix/ssl/'"${HOSTNAME}"'-full.pem'

        _set_certificate "${KEY_WITH_FULLCHAIN}"

        _notify 'inf' "SSL configured with 'CA signed/custom' certificates"
      fi
      ;;
    "manual" )
      # Lets you manually specify the location of the SSL Certs to use. This gives you some more control over this whole processes (like using kube-lego to generate certs)
      if [[ -n ${SSL_CERT_PATH} ]] && [[ -n ${SSL_KEY_PATH} ]]
      then
        _notify 'inf' "Configuring certificates using cert ${SSL_CERT_PATH} and key ${SSL_KEY_PATH}"

        mkdir -p /etc/postfix/ssl
        cp "${SSL_KEY_PATH}" /etc/postfix/ssl/key
        cp "${SSL_CERT_PATH}" /etc/postfix/ssl/cert
        chmod 600 /etc/postfix/ssl/key
        chmod 600 /etc/postfix/ssl/cert

        local PRIVATE_KEY='/etc/postfix/ssl/key'
        local CERT_CHAIN='/etc/postfix/ssl/cert'

        _set_certificate "${PRIVATE_KEY}" "${CERT_CHAIN}"

        # Support for a fallback certificate, useful for hybrid/dual ECDSA + RSA certs
        if [[ -n ${SSL_ALT_KEY_PATH} ]] && [[ -n ${SSL_ALT_CERT_PATH} ]]
        then
          _notify 'inf' "Configuring alternative certificates using cert ${SSL_ALT_CERT_PATH} and key ${SSL_ALT_KEY_PATH}"

          _set_alt_certificate "${SSL_ALT_KEY_PATH}" "${SSL_ALT_CERT_PATH}"
        else
          # If the Dovecot settings for alt cert has been enabled (doesn't start with `#`),
          # but required ENV var is missing, reset to disabled state:
          sed -i 's|^ssl_alt_key = <.*|#ssl_alt_key = </path/to/alternative/key.pem|' "${DOVECOT_CONFIG_SSL}"
          sed -i 's|^ssl_alt_cert = <.*|#ssl_alt_cert = </path/to/alternative/cert.pem|' "${DOVECOT_CONFIG_SSL}"
        fi

        _notify 'inf' "SSL configured with 'Manual' certificates"
      fi
      ;;
    "self-signed" )
      # Adding self-signed SSL certificate if provided in 'postfix/ssl' folder
      if [[ -e /tmp/docker-mailserver/ssl/${HOSTNAME}-key.pem ]] \
      && [[ -e /tmp/docker-mailserver/ssl/${HOSTNAME}-cert.pem ]] \
      && [[ -e /tmp/docker-mailserver/ssl/demoCA/cacert.pem ]]
      then
        _notify 'inf' "Adding ${HOSTNAME} SSL certificate"

        mkdir -p /etc/postfix/ssl
        cp "/tmp/docker-mailserver/ssl/${HOSTNAME}-key.pem" /etc/postfix/ssl
        cp "/tmp/docker-mailserver/ssl/${HOSTNAME}-cert.pem" /etc/postfix/ssl
        chmod 600 "/etc/postfix/ssl/${HOSTNAME}-key.pem"

        local PRIVATE_KEY="/etc/postfix/ssl/${HOSTNAME}-key.pem"
        local CERT_CHAIN="/etc/postfix/ssl/${HOSTNAME}-cert.pem"

        _set_certificate "${PRIVATE_KEY}" "${CERT_CHAIN}"

        cp /tmp/docker-mailserver/ssl/demoCA/cacert.pem /etc/postfix/ssl
        # Have Postfix trust the self-signed CA (which is not installed within the OS trust store)
        sed -i -r 's|^#?smtpd_tls_CAfile =.*|smtpd_tls_CAfile = /etc/postfix/ssl/cacert.pem|' "${POSTFIX_CONFIG_MAIN}"
        sed -i -r 's|^#?smtp_tls_CAfile =.*|smtp_tls_CAfile = /etc/postfix/ssl/cacert.pem|' "${POSTFIX_CONFIG_MAIN}"
        # Part of the original `self-signed` support, unclear why this symlink was required?
        # May have been to support the now removed `Courier` (Dovecot replaced it):
        # https://github.com/docker-mailserver/docker-mailserver/commit/1fb3aeede8ac9707cc9ea11d603e3a7b33b5f8d5
        local PRIVATE_CA="/etc/ssl/certs/cacert-${HOSTNAME}.pem"
        ln -s /etc/postfix/ssl/cacert.pem "${PRIVATE_CA}"

        _notify 'inf' "SSL configured with 'self-signed' certificates"
      fi
      ;;
    '' )
      # no SSL certificate, plain text access
      # TODO: Postfix configuration still responds to TLS negotiations using snakeoil cert from default config
      # TODO: Dovecot `ssl = yes` also allows TLS, both cases this is insecure and should probably instead enforce no TLS?

      # Dovecot configuration
      # WARNING: This may not be corrected(reset?) if `SSL_TYPE` is changed and internal config state persisted
      sed -i -e 's|^#disable_plaintext_auth = yes|disable_plaintext_auth = no|g' /etc/dovecot/conf.d/10-auth.conf
      sed -i -e 's|^ssl = required|ssl = yes|g' "${DOVECOT_CONFIG_SSL}"

      _notify 'warn' "(INSECURE!) SSL configured with plain text access. DO NOT USE FOR PRODUCTION DEPLOYMENT."
      ;;
    * )
      # Unknown option, default behavior, no action is required
      _notify 'warn' "(INSECURE!) ENV var 'SSL_TYPE' is invalid. DO NOT USE FOR PRODUCTION DEPLOYMENT."
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

function _setup_postfix_virtual_transport
{
  _notify 'task' 'Setting up Postfix virtual transport'

  if [[ -z ${POSTFIX_DAGENT} ]]
  then
    _notify 'err' "${POSTFIX_DAGENT} not set."
    kill -15 "$(< /var/run/supervisord.pid)"
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
    _notify 'inf' "Loaded 'config/postfix-main.cf'"
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
    _notify 'inf' "Loaded 'config/postfix-master.cf'"
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
  rm -f /etc/postfix/sasl_passwd
  if [[ -n ${SASL_PASSWD} ]]
  then
    echo "${SASL_PASSWD}" >> /etc/postfix/sasl_passwd
  fi

  # install SASL passwords
  if [[ -f /etc/postfix/sasl_passwd ]]
  then
    chown root:root /etc/postfix/sasl_passwd
    chmod 0600 /etc/postfix/sasl_passwd
    _notify 'inf' "Loaded SASL_PASSWD"
  else
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

  [[ -z ${RELAY_PORT} ]] && RELAY_PORT=25

  # shellcheck disable=SC2153
  _notify 'inf' "Setting up outgoing email relaying via ${RELAY_HOST}:${RELAY_PORT}"

  # setup /etc/postfix/sasl_passwd
  # --
  # @domain1.com        postmaster@domain1.com:your-password-1
  # @domain2.com        postmaster@domain2.com:your-password-2
  # @domain3.com        postmaster@domain3.com:your-password-3
  #
  # [smtp.mailgun.org]:587  postmaster@domain2.com:your-password-2

  if [[ -f /tmp/docker-mailserver/postfix-sasl-password.cf ]]
  then
    _notify 'inf' "Adding relay authentication from postfix-sasl-password.cf"

    while read -r LINE
    do
      if ! echo "${LINE}" | grep -q -e "^\s*#"
      then
        echo "${LINE}" >> /etc/postfix/sasl_passwd
      fi
    done < /tmp/docker-mailserver/postfix-sasl-password.cf
  fi

  # add default relay
  if [[ -n ${RELAY_USER} ]] && [[ -n ${RELAY_PASSWORD} ]]
  then
    echo "[${RELAY_HOST}]:${RELAY_PORT}		${RELAY_USER}:${RELAY_PASSWORD}" >> /etc/postfix/sasl_passwd
  else
    if [[ ! -f /tmp/docker-mailserver/postfix-sasl-password.cf ]]
    then
      _notify 'warn' "No relay auth file found and no default set"
    fi
  fi

  if [[ -f /etc/postfix/sasl_passwd ]]
  then
    chown root:root /etc/postfix/sasl_passwd
    chmod 0600 /etc/postfix/sasl_passwd
  fi
  # end /etc/postfix/sasl_passwd

  _populate_relayhost_map

  postconf -e \
    "smtp_sasl_auth_enable = yes" \
    "smtp_sasl_security_options = noanonymous" \
    "smtp_sasl_password_maps = texthash:/etc/postfix/sasl_passwd" \
    "smtp_use_tls = yes" \
    "smtp_tls_security_level = encrypt" \
    "smtp_tls_note_starttls_offer = yes" \
    "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt" \
    "sender_dependent_relayhost_maps = texthash:/etc/postfix/relayhost_map" \
    "smtp_sender_dependent_authentication = yes"
}

function _setup_postfix_dhparam
{
  _notify 'task' 'Setting up Postfix dhparam'

  if [[ ${ONE_DIR} -eq 1 ]]
  then
    DHPARAMS_FILE=/var/mail-state/lib-shared/dhparams.pem

    if [[ ! -f ${DHPARAMS_FILE} ]]
    then
      _notify 'inf' "Use ffdhe4096 for dhparams (postfix)"
      cp -f /etc/postfix/shared/ffdhe4096.pem /etc/postfix/dhparams.pem
    else
      _notify 'inf' "Use postfix dhparams that was generated previously"
      _notify 'warn' "Using self-generated dhparams is considered as insecure."
      _notify 'warn' "Unless you known what you are doing, please remove /var/mail-state/lib-shared/dhparams.pem."

      # Copy from the state directory to the working location
      cp -f "${DHPARAMS_FILE}" /etc/postfix/dhparams.pem
    fi
  else
    if [[ ! -f /etc/postfix/dhparams.pem ]]
    then
      if [[ -f /etc/dovecot/dh.pem ]]
      then
        _notify 'inf' "Copy dovecot dhparams to postfix"
        cp /etc/dovecot/dh.pem /etc/postfix/dhparams.pem
      elif [[ -f /tmp/docker-mailserver/dhparams.pem ]]
      then
        _notify 'inf' "Copy pre-generated dhparams to postfix"
        _notify 'warn' "Using self-generated dhparams is considered as insecure."
        _notify 'warn' "Unless you known what you are doing, please remove /var/mail-state/lib-shared/dhparams.pem."
        cp /tmp/docker-mailserver/dhparams.pem /etc/postfix/dhparams.pem
      else
        _notify 'inf' "Use ffdhe4096 for dhparams (postfix)"
        cp /etc/postfix/shared/ffdhe4096.pem /etc/postfix/dhparams.pem
      fi
    else
      _notify 'inf' "Use existing postfix dhparams"
      _notify 'warn' "Using self-generated dhparams is considered insecure."
      _notify 'warn' "Unless you known what you are doing, please remove /etc/postfix/dhparams.pem."
    fi
  fi
}

function _setup_dovecot_dhparam
{
  _notify 'task' 'Setting up Dovecot dhparam'

  if [[ ${ONE_DIR} -eq 1 ]]
  then
    DHPARAMS_FILE=/var/mail-state/lib-shared/dhparams.pem

    if [[ ! -f ${DHPARAMS_FILE} ]]
    then
      _notify 'inf' "Use ffdhe4096 for dhparams (dovecot)"
      cp -f /etc/postfix/shared/ffdhe4096.pem /etc/dovecot/dh.pem
    else
      _notify 'inf' "Use dovecot dhparams that was generated previously"
      _notify 'warn' "Using self-generated dhparams is considered as insecure."
      _notify 'warn' "Unless you known what you are doing, please remove /var/mail-state/lib-shared/dhparams.pem."

      # Copy from the state directory to the working location
      cp -f "${DHPARAMS_FILE}" /etc/dovecot/dh.pem
    fi
  else
    if [[ ! -f /etc/dovecot/dh.pem ]]
    then
      if [[ -f /etc/postfix/dhparams.pem ]]
      then
        _notify 'inf' "Copy postfix dhparams to dovecot"
        cp /etc/postfix/dhparams.pem /etc/dovecot/dh.pem
      elif [[ -f /tmp/docker-mailserver/dhparams.pem ]]
      then
        _notify 'inf' "Copy pre-generated dhparams to dovecot"
        _notify 'warn' "Using self-generated dhparams is considered as insecure."
        _notify 'warn' "Unless you known what you are doing, please remove /tmp/docker-mailserver/dhparams.pem."

        cp /tmp/docker-mailserver/dhparams.pem /etc/dovecot/dh.pem
      else
        _notify 'inf' "Use ffdhe4096 for dhparams (dovecot)"
        cp /etc/postfix/shared/ffdhe4096.pem /etc/dovecot/dh.pem
      fi
    else
      _notify 'inf' "Use existing dovecot dhparams"
      _notify 'warn' "Using self-generated dhparams is considered as insecure."
      _notify 'warn' "Unless you known what you are doing, please remove /etc/dovecot/dh.pem."
    fi
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
      _notify 'inf' 'Configure Spamassassin/Amavis to put SPAM inbox'

      sed -i "s|\$final_spam_destiny.*=.*$|\$final_spam_destiny = D_PASS;|g" /etc/amavis/conf.d/49-docker-mailserver
      sed -i "s|\$final_bad_header_destiny.*=.*$|\$final_bad_header_destiny = D_PASS;|g" /etc/amavis/conf.d/49-docker-mailserver
    else
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
    chmod +x "${USER_PATCHES}"
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
