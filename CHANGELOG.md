# Changelog

## 6.2.0+

see https://github.com/tomav/docker-mailserver/releases

## 6.1.0

* Deliver root mail (#952)
* don't update permissions on non-existent file (#956)
* Update docker-configomat (#959)
* Support for detecting running container mount (#884)
* Report sender (#965)
  added REPORT_SENDER env variable to the container.
* Add saslauthd option for ldap_start_tls & ldap_tls_check_peer - (#979, #980)
* fix SASL domain (#892, #970)
* DOMAINNAME can fail to be set in postsrsd-wrapper.sh (#989)

## 6.0.0

* Implementation of multi-domain relay hosts (#922, #926)
  AWS_SES_HOST and AWS_SES_PORT are deprecated now.
  RELAY_HOST and RELAY_PORT are introduced to replace them.
* Password creation fix (#908, #914)
* Fixes 'duplicate log entry for /var/log/mail/mail.log' (#925, #927)
* fixed cleanup (mail_with_relays didn't get cleaned up) (#930)
* fix line breaks in postfix-summary mail error case (#936)
* Set default virus delete time (#932, #935)
  This defaults to 7 days
* Ensure that the account contains a @ (#923, #924)
* Introducing global filters. (#934)
* add missing env vars to docker-compose.yml (#937)
* set postmaster address to a sensible default (#938, #939,  #940)
* Testfixes & more (#942)

## 5.8.1

* add headers to postfix summary mail (#919)
* quotes needed to run multi-word command inside
  container (#921)
* Fix uncommented lines in .env file (#920)
* Tls level fix (#916)
* test/config backup & restore (#907)
* Restore userdb for tests (#913)

## 5.8.0

* Adding daily mail review from Issue 839 (#881)
  You can enable REPORT_RECIPIENT for REPORT_INTERVAL
  reports. Default is disabled.
* introducing ENABLE_SRS env variable (#906, #852)
  In v3.2.0 was SRS introduced and enabled by default
  Now it is disabled by default and can be enabled with
  the new env variable.
* fixed delalias, added additional tests (#909)
  Fixes to setup where made for deletion and addition.

## 5.7.0
* Delmailuser (#878)
  You can now delete users and the mailbox
* Backup config folder while testing (#901)
* added error messages to letsencrypt on startup (#898)

## 5.6.1
*  Update docker-configomat (#680)

## 5.6.0
* Generate SRS secret on first run and store it (#891)
  The secret will be constant afther this.

## 5.5.0
* Add /var/lib/dovecot to mailstate persistence (#887)

## 5.4.0
* Allow configuring SRS secrets using the environment (#885)
  You can set your own secret with the env SRS_SECRET
  By default it uses the docker generated secret
* Removed unneeded check for Let's encrypt cert.pem (#843)

## 5.3.0
* Added reject_authenticated_sender_login_mismatch (#872)
  You can enable it with the env SPOOF_PROTECTION
  It is not enabled by default

## 5.2.0
* Setting quiet mode on invoke-rc.d (#792)
* Implement undef option for SA_SPAM_SUBJECT (#767)

## 5.1.0
* Dkim key size can be changed (#868)
  It defaults to 2048 bits

## 5.0.1
* update postmaster_address in dovecot config according to
  POSTMASTER_ADDRESS env var (#866)

## 5.0.0
* Use Nist tls recommendations (#831)
  This might break access with older email clients that use
  an older version of openssl. You can TLS_LEVEL to lower
  the ciphers.

## 4.2.0
*  Add environment variable to allow for customizing postsrsd's
   SRS_EXCLUDE_DOMAINS setting (#849, #842)

## 4.1.0
* fixed greedy postgrey sed command (#845)
* postscreen implementation altered (#846)
  You can now apply sender and receives restrictions

## 4.0.0
* moved fail2ban function from setup.sh to own file (#837)
  This might break automatic scripting and you need to use
  fail2ban now

## 3.4.0
* Generate new DH param weekly instead of daily (#834, #836)

## 3.3.1
* added config-path option to setup.sh script (#698)

## 3.3.0
* Restrict access (#452, #816)

## 3.2.3
* Introduce .env for docker-compose examples (#815)

## 3.2.2
* Changed Junk folder to be created and subscribed by default (#806)

## 3.2.1 (2018-02-06)
* Added  reject_sender_login_mismatch (#811)

## 3.2.0 (2018-02-06)
* Add SRS to fix SPF issues on redirect (#611, #814)

## 3.1.0 (2018-02-04)
* Introduced Postscreen
  Breaks email submission on port 25. Sending emails should be done on port 465 or 587

## 3.0.0 (2018-02-04)
* Image rebased on Debian stable

## 2.0.0 (2016-05-09)
* New version
* Major redesign of configuration

