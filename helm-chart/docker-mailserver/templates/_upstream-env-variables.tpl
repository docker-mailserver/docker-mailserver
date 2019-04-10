{{/*
There are a _lot_ of upstream env variables used to customize docker-mailserver.
We list them here (and include this template in deployment.yaml) to keep deployment.yaml neater
*/}}
{{- define "dockermailserver.upstream-env-variables" -}}
- name: OVERRIDE_HOSTNAME
  value: {{ .Values.pod.dockermailserver.override_hostname | quote }}
- name: DMS_DEBUG
  value: {{ .Values.pod.dockermailserver.dms_debug | quote }}              
- name: ENABLE_CLAMAV
  value: {{ .Values.pod.dockermailserver.enable_clamav | quote }}
- name: ONE_DIR
  value: {{ .Values.pod.dockermailserver.one_dir | quote }}
- name: ENABLE_POP3
  value: {{ .Values.pod.dockermailserver.enable_pop3 | quote }}
- name: ENABLE_FAIL2BAN
  value: {{ .Values.pod.dockermailserver.enable_fail2ban | quote }}
- name: SMTP_ONLY
  value: {{ .Values.pod.dockermailserver.smtp_only | quote }}
- name: SSL_TYPE
  value: {{ default "manual" .Values.pod.dockermailserver.ssl_type | quote }}
- name: SSL_CERT_PATH
  value: {{ default "/tmp/ssl/tls.crt" .Values.pod.dockermailserver.ssl_cert_path | quote }}   
- name: SSL_KEY_PATH
  value: {{ default "/tmp/ssl/tls.key" .Values.pod.dockermailserver.ssl_key_path | quote }}                            
- name: TLS_LEVEL
  value: {{ .Values.pod.dockermailserver.tls_level | quote }}
- name: SPOOF_PROTECTION
  value: {{ .Values.pod.dockermailserver.spoof_protection | quote }}
- name: ENABLE_SRS
  value: {{ .Values.pod.dockermailserver.enable_srs | quote }}
- name: PERMIT_DOCKER
  value: {{ .Values.pod.dockermailserver.permit_docker | quote }}
- name: VIRUSMAILS_DELETE_DELAY
  value: {{ .Values.pod.dockermailserver.virusmails_delete_delay | quote }}
- name: ENABLE_POSTFIX_VIRTUAL_TRANSPORT
  value: {{ .Values.pod.dockermailserver.enable_postfix_virtual_transport | quote }}
- name: POSTFIX_DAGENT
  value: {{ .Values.pod.dockermailserver.postfix_dagent | quote }}
- name: POSTFIX_MAILBOX_SIZE_LIMIT
  value: {{ .Values.pod.dockermailserver.postfix_mailbox_size_limit | quote }}
- name: POSTFIX_MESSAGE_SIZE_LIMIT
  value: {{ .Values.pod.dockermailserver.postfix_message_size_limit | quote }}
- name: ENABLE_MANAGESIEVE
  value: {{ .Values.pod.dockermailserver.enable_managesieve | quote }}
- name: POSTMASTER_ADDRESS
  value: {{ .Values.pod.dockermailserver.postmaster_address | quote }}
- name: POSTSCREEN_ACTION
  value: {{ .Values.pod.dockermailserver.postscreen_action | quote }}
- name: REPORT_RECIPIENT
  value: {{ .Values.pod.dockermailserver.report_recipient | quote }}
- name: REPORT_SENDER
  value: {{ .Values.pod.dockermailserver.report_sender | quote }}
- name: REPORT_INTERVAL
  value: {{ .Values.pod.dockermailserver.report_interval | quote }}
- name: ENABLE_SPAMASSASSIN
  value: {{ .Values.pod.dockermailserver.enable_spamassassin | quote }}
- name: SA_TAG
  value: {{ .Values.pod.dockermailserver.sa_tag | quote }}
- name: SA_TAG2
  value: {{ .Values.pod.dockermailserver.sa_tag2 | quote }}
- name: SA_KILL
  value: {{ .Values.pod.dockermailserver.sa_kill | quote }}
- name: SA_SPAM_SUBJECT
  value: {{ .Values.pod.dockermailserver.sa_spam_subject | quote }}
- name: ENABLE_FETCHMAIL
  value: {{ .Values.pod.dockermailserver.enable_fetchmail | quote }}
- name: FETCHMAIL_POLL
  value: {{ .Values.pod.dockermailserver.fetchmail_poll | quote }}
- name: ENABLE_LDAP
  value: {{ .Values.pod.dockermailserver.enable_ldap | quote }}
- name: LDAP_START_TLS
  value: {{ .Values.pod.dockermailserver.ldap_start_tls | quote }}
- name: LDAP_SERVER_HOST
  value: {{ .Values.pod.dockermailserver.ldap_server_host | quote }}
- name: LDAP_SEARCH_BASE
  value: {{ .Values.pod.dockermailserver.ldap_search_base | quote }}
- name: LDAP_BIND_DN
  value: {{ .Values.pod.dockermailserver.ldap_bind_dn | quote }}
- name: LDAP_BIND_PW
  value: {{ .Values.pod.dockermailserver.ldap_bind_pw | quote }}
- name: LDAP_QUERY_FILTER_USER
  value: {{ .Values.pod.dockermailserver.ldap_query_filter_user | quote }}
- name: LDAP_QUERY_FILTER_GROUP
  value: {{ .Values.pod.dockermailserver.ldap_query_filter_group | quote }}
- name: LDAP_QUERY_FILTER_ALIAS
  value: {{ .Values.pod.dockermailserver.ldap_query_filter_alias | quote }}
- name: LDAP_QUERY_FILTER_DOMAIN
  value: {{ .Values.pod.dockermailserver.ldap_query_filter_domain | quote }}
- name: DOVECOT_TLS
  value: {{ .Values.pod.dockermailserver.dovecot_tls | quote }}
- name: DOVECOT_USER_FILTER
  value: {{ .Values.pod.dockermailserver.dovecot_user_filter | quote }}
- name: DOVECOT_USER_ATTR
  value: {{ .Values.pod.dockermailserver.dovecot_user_attr | quote }}
- name: DOVECOT_PASS_FILTER
  value: {{ .Values.pod.dockermailserver.dovecot_pass_filter | quote }}
- name: DOVECOT_PASS_ATTR
  value: {{ .Values.pod.dockermailserver.dovecot_pass_attr | quote }}
- name: ENABLE_POSTGREY
  value: {{ .Values.pod.dockermailserver.enable_postgrey | quote }}
- name: POSTGREY_DELAY
  value: {{ .Values.pod.dockermailserver.postgrey_delay | quote }}
- name: POSTGREY_MAX_AGE
  value: {{ .Values.pod.dockermailserver.postgrey_max_age | quote }}
- name: POSTGREY_AUTO_WHITELIST_CLIENTS
  value: {{ .Values.pod.dockermailserver.postgrey_auto_whitelist_clients | quote }}
- name: POSTGREY_TEXT
  value: {{ .Values.pod.dockermailserver.postgrey_text | quote }}
- name: ENABLE_SASLAUTHD
  value: {{ .Values.pod.dockermailserver.enable_saslauthd | quote }}
- name: SASLAUTHD_MECHANISMS
  value: {{ .Values.pod.dockermailserver.saslauthd_mechanisms | quote }}
- name: SASLAUTHD_MECH_OPTIONS
  value: {{ .Values.pod.dockermailserver.saslauthd_mech_options | quote }}
- name: SASLAUTHD_LDAP_SERVER
  value: {{ .Values.pod.dockermailserver.saslauthd_ldap_server | quote }}
- name: SASLAUTHD_LDAP_SSL
  value: {{ .Values.pod.dockermailserver.saslauthd_ldap_ssl | quote }}
- name: SASLAUTHD_LDAP_BIND_DN
  value: {{ .Values.pod.dockermailserver.saslauthd_ldap_bind_dn | quote }}
- name: SASLAUTHD_LDAP_PASSWORD
  value: {{ .Values.pod.dockermailserver.saslauthd_ldap_password | quote }}
- name: SASLAUTHD_LDAP_SEARCH_BASE
  value: {{ .Values.pod.dockermailserver.saslauthd_ldap_search_base | quote }}
- name: SASLAUTHD_LDAP_FILTER
  value: {{ .Values.pod.dockermailserver.saslauthd_ldap_filter | quote }}
- name: SASL_PASSWD
  value: {{ .Values.pod.dockermailserver.sasl_passwd | quote }}
- name: SRS_EXCLUDE_DOMAINS
  value: {{ .Values.pod.dockermailserver.srs_exclude_domains | quote }}
- name: SRS_SECRET
  value: {{ .Values.pod.dockermailserver.srs_secret | quote }}
- name: SRS_DOMAINNAME
  value: {{ .Values.pod.dockermailserver.srs_domainname | quote }}
- name: DEFAULT_RELAY_HOST
  value: {{ .Values.pod.dockermailserver.default_relay_host | quote }}
- name: RELAY_HOST
  value: {{ .Values.pod.dockermailserver.relay_host | quote }}
- name: RELAY_PORT
  value: {{ .Values.pod.dockermailserver.relay_port | quote }}
- name: RELAY_USER
  value: {{ .Values.pod.dockermailserver.relay_user | quote }}
- name: RELAY_PASSWORD
  value: {{ .Values.pod.dockermailserver.relay_password | quote }}
{{- end -}}