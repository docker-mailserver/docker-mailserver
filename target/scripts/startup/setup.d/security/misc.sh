#!/bin/bash

function _setup_security_stack() {
  _log 'debug' 'Setting up Security Stack'

  __setup__security__postgrey
  __setup__security__postscreen

  # recreate auto-generated file
  local DMS_AMAVIS_FILE=/etc/amavis/conf.d/61-dms_auto_generated

  echo "# WARNING: this file is auto-generated." >"${DMS_AMAVIS_FILE}"
  echo "use strict;" >>"${DMS_AMAVIS_FILE}"

  __setup__security__spamassassin
  __setup__security__clamav

  echo '1;  # ensure a defined return' >>"${DMS_AMAVIS_FILE}"
  chmod 444 "${DMS_AMAVIS_FILE}"

  __setup__security__fail2ban
  __setup__security__amavis
}

function __setup__security__postgrey() {
  if [[ ${ENABLE_POSTGREY} -eq 1 ]]; then
    _log 'debug' 'Enabling and configuring Postgrey'

    sedfile -i -E \
      's|(^smtpd_recipient_restrictions =.*)|\1, check_policy_service inet:127.0.0.1:10023|' \
      /etc/postfix/main.cf

    sed -i -e \
      "s|\"--inet=127.0.0.1:10023\"|\"--inet=127.0.0.1:10023 --delay=${POSTGREY_DELAY} --max-age=${POSTGREY_MAX_AGE} --auto-whitelist-clients=${POSTGREY_AUTO_WHITELIST_CLIENTS}\"|" \
      /etc/default/postgrey

    if ! grep -i 'POSTGREY_TEXT' /etc/default/postgrey; then
      printf 'POSTGREY_TEXT=\"%s\"\n\n' "${POSTGREY_TEXT}" >>/etc/default/postgrey
    fi

    if [[ -f /tmp/docker-mailserver/whitelist_clients.local ]]; then
      cp -f /tmp/docker-mailserver/whitelist_clients.local /etc/postgrey/whitelist_clients.local
    fi

    if [[ -f /tmp/docker-mailserver/whitelist_recipients ]]; then
      cp -f /tmp/docker-mailserver/whitelist_recipients /etc/postgrey/whitelist_recipients
    fi
  else
    _log 'debug' 'Postgrey is disabled'
  fi
}

function __setup__security__postscreen() {
  _log 'debug' 'Configuring Postscreen'
  sed -i \
    -e "s|postscreen_dnsbl_action = enforce|postscreen_dnsbl_action = ${POSTSCREEN_ACTION}|" \
    -e "s|postscreen_greet_action = enforce|postscreen_greet_action = ${POSTSCREEN_ACTION}|" \
    -e "s|postscreen_bare_newline_action = enforce|postscreen_bare_newline_action = ${POSTSCREEN_ACTION}|" /etc/postfix/main.cf

  if [[ ${ENABLE_DNSBL} -eq 0 ]]; then
    _log 'debug' 'Disabling Postscreen DNSBLs'
    postconf 'postscreen_dnsbl_action = ignore'
    postconf 'postscreen_dnsbl_sites = '
  else
    _log 'debug' 'Postscreen DNSBLs are enabled'
  fi
}

function __setup__security__spamassassin() {
  if [[ ${ENABLE_AMAVIS} -ne 1 && ${ENABLE_SPAMASSASSIN} -eq 1 ]]; then
    _log 'warn' 'Spamassassin does not work when Amavis is disabled. Enable Amavis to fix it.'
    ENABLE_SPAMASSASSIN=0
  fi

  if [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]]; then
    _log 'debug' 'Enabling and configuring SpamAssassin'

    # Maintainers should take care in attempting to change these sed commands. Alternatives were already explored:
    # https://github.com/docker-mailserver/docker-mailserver/pull/3767#issuecomment-1885989591
    # shellcheck disable=SC2016
    sed -i -r 's|^\$sa_tag_level_deflt (.*);|\$sa_tag_level_deflt = '"${SA_TAG}"';|g' /etc/amavis/conf.d/20-debian_defaults

    # shellcheck disable=SC2016
    sed -i -r 's|^\$sa_tag2_level_deflt (.*);|\$sa_tag2_level_deflt = '"${SA_TAG2}"';|g' /etc/amavis/conf.d/20-debian_defaults

    # shellcheck disable=SC2016
    sed -i -r 's|^\$sa_kill_level_deflt (.*);|\$sa_kill_level_deflt = '"${SA_KILL}"';|g' /etc/amavis/conf.d/20-debian_defaults

    # disable rewriting the subject as this is handles by _setup_spam_subject (which uses Dovecot Sieve)
    # shellcheck disable=SC2016
    sed -i -r 's|^\$sa_spam_subject_tag (.*);|\$sa_spam_subject_tag = undef;|g' /etc/amavis/conf.d/20-debian_defaults

    # activate short circuits when SA BAYES is certain it has spam or ham.
    if [[ ${SA_SHORTCIRCUIT_BAYES_SPAM} -eq 1 ]]; then
      # automatically activate the Shortcircuit Plugin
      sed -i -r 's|^# loadplugin Mail::SpamAssassin::Plugin::Shortcircuit|loadplugin Mail::SpamAssassin::Plugin::Shortcircuit|g' /etc/spamassassin/v320.pre
      sed -i -r 's|^# shortcircuit BAYES_99|shortcircuit BAYES_99|g' /etc/spamassassin/local.cf
    fi

    if [[ ${SA_SHORTCIRCUIT_BAYES_HAM} -eq 1 ]]; then
      # automatically activate the Shortcircuit Plugin
      sed -i -r 's|^# loadplugin Mail::SpamAssassin::Plugin::Shortcircuit|loadplugin Mail::SpamAssassin::Plugin::Shortcircuit|g' /etc/spamassassin/v320.pre
      sed -i -r 's|^# shortcircuit BAYES_00|shortcircuit BAYES_00|g' /etc/spamassassin/local.cf
    fi

    if [[ -e /tmp/docker-mailserver/spamassassin-rules.cf ]]; then
      cp /tmp/docker-mailserver/spamassassin-rules.cf /etc/spamassassin/
    fi

    if [[ ${SPAMASSASSIN_SPAM_TO_INBOX} -eq 1 ]]; then
      _log 'trace' 'Configuring Spamassassin/Amavis to send SPAM to inbox'
      _log 'debug'  "'SPAMASSASSIN_SPAM_TO_INBOX=1' is set. The 'SA_KILL' ENV will be ignored."

      sed -i "s|\$final_spam_destiny.*=.*$|\$final_spam_destiny = D_PASS;|g" /etc/amavis/conf.d/49-docker-mailserver
      sed -i "s|\$final_bad_header_destiny.*=.*$|\$final_bad_header_destiny = D_PASS;|g" /etc/amavis/conf.d/49-docker-mailserver
    else
      _log 'trace' 'Configuring Spamassassin/Amavis to bounce SPAM'

      sed -i "s|\$final_spam_destiny.*=.*$|\$final_spam_destiny = D_BOUNCE;|g" /etc/amavis/conf.d/49-docker-mailserver
      sed -i "s|\$final_bad_header_destiny.*=.*$|\$final_bad_header_destiny = D_BOUNCE;|g" /etc/amavis/conf.d/49-docker-mailserver
    fi

    if [[ ${ENABLE_SPAMASSASSIN_KAM} -eq 1 ]]; then
      _log 'trace' 'Configuring Spamassassin KAM'
      local SPAMASSASSIN_KAM_CRON_FILE=/etc/cron.daily/spamassassin_kam

      sa-update --import /etc/spamassassin/kam/kam.sa-channels.mcgrail.com.key

      cat >"${SPAMASSASSIN_KAM_CRON_FILE}" <<"EOF"
#!/bin/bash

RESULT=$(sa-update --gpgkey 24C063D8 --channel kam.sa-channels.mcgrail.com 2>&1)
EXIT_CODE=${?}

# see https://spamassassin.apache.org/full/3.1.x/doc/sa-update.html#exit_codes
if [[ ${EXIT_CODE} -ge 4 ]]; then
  echo -e "Updating SpamAssassin KAM failed:\n${RESULT}\n" >&2
  exit 1
fi

exit 0

EOF

      chmod +x "${SPAMASSASSIN_KAM_CRON_FILE}"
    fi
  else
    _log 'debug' 'SpamAssassin is disabled'
    echo "@bypass_spam_checks_maps = (1);" >>"${DMS_AMAVIS_FILE}"
    rm -f /etc/cron.daily/spamassassin
  fi
}

function __setup__security__clamav() {
  if [[ ${ENABLE_CLAMAV} -eq 1 ]]; then
    _log 'debug' 'Enabling and configuring ClamAV'

    if [[ ${CLAMAV_MESSAGE_SIZE_LIMIT} != '25M' ]]; then
      _log 'trace' "Setting ClamAV message scan size limit to '${CLAMAV_MESSAGE_SIZE_LIMIT}'"

      # do a short sanity check: ClamAV does not support setting a maximum size greater than 4000M (at all)
      if [[ $(numfmt --from=si "${CLAMAV_MESSAGE_SIZE_LIMIT}") -gt $(numfmt --from=si 4000M) ]]; then
        _log 'warn' "You set 'CLAMAV_MESSAGE_SIZE_LIMIT' to a value larger than 4 Gigabyte, but the maximum value is 4000M for this value - you should correct your configuration"
      fi
      # For more details, see
      # https://github.com/docker-mailserver/docker-mailserver/pull/3341
      if [[ $(numfmt --from=si "${CLAMAV_MESSAGE_SIZE_LIMIT}") -ge $(numfmt --from=iec 2G) ]]; then
        _log 'warn' "You set 'CLAMAV_MESSAGE_SIZE_LIMIT' to a value larger than 2 Gibibyte but ClamAV does not scan files larger or equal to 2 Gibibyte"
      fi

      sedfile -i -E \
        "s|^(MaxFileSize).*|\1 ${CLAMAV_MESSAGE_SIZE_LIMIT}|" \
        /etc/clamav/clamd.conf
      sedfile -i -E \
        "s|^(MaxScanSize).*|\1 ${CLAMAV_MESSAGE_SIZE_LIMIT}|" \
        /etc/clamav/clamd.conf
    fi
  else
    _log 'debug' 'Disabling ClamAV'
    echo '@bypass_virus_checks_maps = (1);' >>"${DMS_AMAVIS_FILE}"
    rm -f /etc/logrotate.d/clamav-* /etc/cron.d/clamav-freshclam
  fi
}

function __setup__security__fail2ban() {
  if [[ ${ENABLE_FAIL2BAN} -eq 1 ]]; then
    _log 'debug' 'Enabling and configuring Fail2Ban'

    if [[ -e /tmp/docker-mailserver/fail2ban-fail2ban.cf ]]; then
      _log 'trace' 'Custom fail2ban-fail2ban.cf found'
      cp /tmp/docker-mailserver/fail2ban-fail2ban.cf /etc/fail2ban/fail2ban.local
    fi

    if [[ -e /tmp/docker-mailserver/fail2ban-jail.cf ]]; then
      _log 'trace' 'Custom fail2ban-jail.cf found'
      cp /tmp/docker-mailserver/fail2ban-jail.cf /etc/fail2ban/jail.d/user-jail.local
    fi

    if [[ ${FAIL2BAN_BLOCKTYPE} != 'reject' ]]; then
      _log 'trace' "Setting fail2ban blocktype to 'drop'"
      echo -e '[Init]\nblocktype = drop' >/etc/fail2ban/action.d/nftables-common.local
    fi

    echo '[Definition]' >/etc/fail2ban/filter.d/custom.conf

    _log 'trace' 'Configuring fail2ban logrotate rotate count and interval'
    [[ ${LOGROTATE_COUNT} -ne 4 ]]          && sedfile -i "s|rotate 4$|rotate ${LOGROTATE_COUNT}|" /etc/logrotate.d/fail2ban
    [[ ${LOGROTATE_INTERVAL} != "weekly" ]] && sedfile -i "s|weekly$|${LOGROTATE_INTERVAL}|"       /etc/logrotate.d/fail2ban
  else
    _log 'debug' 'Fail2Ban is disabled'
    rm -f /etc/logrotate.d/fail2ban
  fi
}

function __setup__security__amavis() {
  if [[ ${ENABLE_AMAVIS} -eq 1 ]]; then
    _log 'debug' 'Configuring Amavis'
    if [[ -f /tmp/docker-mailserver/amavis.cf ]]; then
      cp /tmp/docker-mailserver/amavis.cf /etc/amavis/conf.d/50-user
    fi

    sed -i -E \
      "s|(log_level).*|\1 = ${AMAVIS_LOGLEVEL};|g" \
      /etc/amavis/conf.d/49-docker-mailserver

    cat /etc/dms/postfix/master.d/postfix-amavis.cf >>/etc/postfix/master.cf
    postconf 'content_filter = smtp-amavis:[127.0.0.1]:10024'

    sed -i \
      "s|^#\$myhostname = \"mail.example.com\";|\$myhostname = \"${HOSTNAME}\";|" \
      /etc/amavis/conf.d/05-node_id
  else
    _log 'debug' 'Disabling Amavis'

    _log 'trace' 'Disabling Amavis cron job'
    mv /etc/cron.d/amavisd-new /etc/cron.d/amavisd-new.disabled
    chmod 0 /etc/cron.d/amavisd-new.disabled

    if [[ ${ENABLE_CLAMAV} -eq 1 ]] && [[ ${ENABLE_RSPAMD} -eq 0 ]]; then
      _log 'warn' 'ClamAV will not work when Amavis & rspamd are disabled. Enable either Amavis or rspamd to fix it.'
    fi
  fi
}

# If `SPAM_SUBJECT` is not empty, we create a Sieve script that alters the `Subject`
# header, in order to prepend a user-defined string.
function _setup_spam_subject() {
  if [[ -z ${SPAM_SUBJECT} ]]
  then
    _log 'debug' 'Spam subject is not set - no prefix will be added to spam e-mails'
  else
    _log 'debug' "Spam subject is set - the prefix '${SPAM_SUBJECT}' will be added to spam e-mails"

    _log 'trace' "Enabling '+editheader' Sieve extension"
    # check whether sieve_global_extensions is disabled (and enabled it if so)
    sed -i -E 's|#(sieve_global_extensions.*)|\1|' /etc/dovecot/conf.d/90-sieve.conf
    # then append the extension
    sedfile -i -E 's|(sieve_global_extensions.*)|\1 +editheader|' /etc/dovecot/conf.d/90-sieve.conf

    _log 'trace' "Adding global (before) Sieve script for subject rewrite"
    # This directory contains Sieve scripts that are executed before user-defined Sieve
    # scripts run.
    local DOVECOT_SIEVE_GLOBAL_BEFORE_DIR='/usr/lib/dovecot/sieve-global/before'
    local DOVECOT_SIEVE_FILE='spam_subject'
    readonly DOVECOT_SIEVE_GLOBAL_BEFORE_DIR DOVECOT_SIEVE_FILE

    mkdir -p "${DOVECOT_SIEVE_GLOBAL_BEFORE_DIR}"
    # ref: https://superuser.com/a/1502589
    cat >"${DOVECOT_SIEVE_GLOBAL_BEFORE_DIR}/${DOVECOT_SIEVE_FILE}.sieve" << EOF
require ["editheader","variables"];

if anyof (header :contains "X-Spam-Flag" "YES",
          header :contains "X-Spam" "Yes")
{
    # Match the entire subject ...
    if header :matches "Subject" "*" {
        # ... to get it in a match group that can then be stored in a variable:
        set "subject" "\${1}";
    }

    # We can't "replace" a header, but we can delete (all instances of) it and
    # re-add (a single instance of) it:
    deleteheader "Subject";

    # Note that the header is added ":last" (so it won't appear before possible
    # "Received" headers).
    addheader :last "Subject" "${SPAM_SUBJECT}\${subject}";
}
EOF

    sievec "${DOVECOT_SIEVE_GLOBAL_BEFORE_DIR}/${DOVECOT_SIEVE_FILE}.sieve"
    chown dovecot:root "${DOVECOT_SIEVE_GLOBAL_BEFORE_DIR}/${DOVECOT_SIEVE_FILE}."{sieve,svbin}
  fi
}

# We can use Sieve to move spam emails to the "Junk" folder.
function _setup_spam_to_junk() {
  if [[ ${MOVE_SPAM_TO_JUNK} -eq 1 ]]; then
    _log 'debug' 'Spam emails will be moved to the Junk folder'
    mkdir -p /usr/lib/dovecot/sieve-global/after/
    cat >/usr/lib/dovecot/sieve-global/after/spam_to_junk.sieve << EOF
require ["fileinto","special-use"];

if anyof (header :contains "X-Spam-Flag" "YES",
          header :contains "X-Spam" "Yes") {
    fileinto :specialuse "\\\\Junk" "Junk";
}
EOF
    sievec /usr/lib/dovecot/sieve-global/after/spam_to_junk.sieve
    chown dovecot:root /usr/lib/dovecot/sieve-global/after/spam_to_junk.{sieve,svbin}

    if [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]] && [[ ${SPAMASSASSIN_SPAM_TO_INBOX} -eq 0 ]]; then
      _log 'warn' "'SPAMASSASSIN_SPAM_TO_INBOX=0' but it is required to be 1 for 'MOVE_SPAM_TO_JUNK=1' to work"
    fi
  else
    _log 'debug' 'Spam emails will not be moved to the Junk folder'
  fi
}

function _setup_spam_mark_as_read() {
  if [[ ${MARK_SPAM_AS_READ} -eq 1 ]]; then
    _log 'debug' 'Spam emails will be marked as read'
    mkdir -p /usr/lib/dovecot/sieve-global/after/

    # Header support: `X-Spam-Flag` (SpamAssassin), `X-Spam` (Rspamd)
    cat >/usr/lib/dovecot/sieve-global/after/spam_mark_as_read.sieve << EOF
require ["mailbox","imap4flags"];

if anyof (header :contains "X-Spam-Flag" "YES",
          header :contains "X-Spam" "Yes") {
    setflag "\\\\Seen";
}
EOF
    sievec /usr/lib/dovecot/sieve-global/after/spam_mark_as_read.sieve
    chown dovecot:root /usr/lib/dovecot/sieve-global/after/spam_mark_as_read.{sieve,svbin}

    if [[ ${ENABLE_SPAMASSASSIN} -eq 1 ]] && [[ ${SPAMASSASSIN_SPAM_TO_INBOX} -eq 0 ]]; then
      _log 'warn' "'SPAMASSASSIN_SPAM_TO_INBOX=0' but it is required to be 1 for 'MARK_SPAM_AS_READ=1' to work"
    fi
  else
    _log 'debug' 'Spam emails will not be marked as read'
  fi
}
