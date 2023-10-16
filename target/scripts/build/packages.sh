#!/bin/bash

# -eE :: exit on error (do this in functions as well)
# -u  :: show (and exit) when using unset variables
# -o pipefail :: exit on error in pipes
set -eE -u -o pipefail

# shellcheck source=../helpers/log.sh
source /usr/local/bin/helpers/log.sh

_log_level_is 'trace' && QUIET='-y' || QUIET='-qq'

function _pre_installation_steps() {
  _log 'info' 'Starting package installation'
  _log 'debug' 'Running pre-installation steps'

  _log 'trace' 'Updating package signatures'
  apt-get "${QUIET}" update

  _log 'trace' 'Installing packages that are needed early'
  apt-get "${QUIET}" install --no-install-recommends apt-utils 2>/dev/null

  _log 'trace' 'Upgrading packages'
  apt-get "${QUIET}" upgrade
}

function _install_postfix() {
  _log 'debug' 'Installing Postfix'

  _log 'warn' 'Applying workaround for Postfix bug (see https://github.com//issues/2023#issuecomment-855326403)'

  # Debians postfix package has a post-install script that expects a valid FQDN hostname to work:
  mv /bin/hostname /bin/hostname.bak
  echo "echo 'docker-mailserver.invalid'" >/bin/hostname
  chmod +x /bin/hostname
  apt-get "${QUIET}" install --no-install-recommends postfix
  mv /bin/hostname.bak /bin/hostname

  # Irrelevant - Debian's default `chroot` jail config for Postfix needed a separate syslog socket:
  rm /etc/rsyslog.d/postfix.conf
}

function _install_packages() {
  _log 'debug' 'Installing all packages now'

  ANTI_VIRUS_SPAM_PACKAGES=(
    amavisd-new clamav clamav-daemon
    pyzor razor spamassassin
  )

  CODECS_PACKAGES=(
    altermime arj bzip2
    cabextract cpio file
    gzip lhasa liblz4-tool
    lrzip lzop nomarch
    p7zip-full pax rpm2cpio
    unrar-free unzip xz-utils
  )

  MISCELLANEOUS_PACKAGES=(
    apt-transport-https binutils bsd-mailx
    ca-certificates curl dbconfig-no-thanks
    dumb-init gnupg iproute2 libdate-manip-perl
    libldap-common libmail-spf-perl
    libnet-dns-perl locales logwatch
    netcat-openbsd nftables rsyslog
    supervisor uuid whois
  )

  POSTFIX_PACKAGES=(
    pflogsumm postgrey postfix-ldap
    postfix-pcre postfix-policyd-spf-python postsrsd
  )

  MAIL_PROGRAMS_PACKAGES=(
    fetchmail opendkim opendkim-tools
    opendmarc libsasl2-modules sasl2-bin
  )

  # `bind9-dnsutils` provides the `dig` command
  # `iputils-ping` provides the `ping` command
  DEBUG_PACKAGES=(
    bind9-dnsutils iputils-ping less nano
  )

  apt-get "${QUIET}" --no-install-recommends install \
    "${ANTI_VIRUS_SPAM_PACKAGES[@]}" \
    "${CODECS_PACKAGES[@]}" \
    "${MISCELLANEOUS_PACKAGES[@]}" \
    "${POSTFIX_PACKAGES[@]}" \
    "${MAIL_PROGRAMS_PACKAGES[@]}" \
    "${DEBUG_PACKAGES[@]}"
}

function _install_dovecot() {
  declare -a DOVECOT_PACKAGES

  DOVECOT_PACKAGES=(
    dovecot-core dovecot-imapd
    dovecot-ldap dovecot-lmtpd dovecot-managesieved
    dovecot-pop3d dovecot-sieve dovecot-solr
  )

  if [[ ${DOVECOT_COMMUNITY_REPO} -eq 1 ]]; then
    _log 'trace' 'Using Dovecot community repository'
    curl https://repo.dovecot.org/DOVECOT-REPO-GPG | gpg --import
    gpg --export ED409DA1 > /etc/apt/trusted.gpg.d/dovecot.gpg
    echo "deb https://repo.dovecot.org/ce-2.3-latest/debian/bullseye bullseye main" > /etc/apt/sources.list.d/dovecot.list

    _log 'trace' 'Updating Dovecot package signatures'
    apt-get "${QUIET}" update
  fi

  _log 'debug' 'Installing Dovecot'
  apt-get "${QUIET}" --no-install-recommends install "${DOVECOT_PACKAGES[@]}"

  # dependency for fts_xapian
  apt-get "${QUIET}" --no-install-recommends install libxapian30
}

function _install_rspamd() {
  _log 'trace' 'Adding Rspamd package signatures'
  local DEB_FILE='/etc/apt/sources.list.d/rspamd.list'
  local RSPAMD_PACKAGE_NAME

  # We try getting the most recent version of Rspamd for aarch64 (from an official source, which
  # is the backports repository). The version for aarch64 is 3.2; the most recent version for amd64
  # that we get with the official PPA is 3.4.
  #
  # Not removing it later is fine as you have to explicitly opt into installing a backports package
  # which is not something you could be doing by accident.
  if [[ $(uname --machine) == 'aarch64' ]]; then
    echo '# Official Rspamd PPA does not support aarch64, so we use the Bullseye backports' >"${DEB_FILE}"
    echo 'deb [arch=arm64] http://deb.debian.org/debian bullseye-backports main' >>"${DEB_FILE}"
    RSPAMD_PACKAGE_NAME='rspamd/bullseye-backports'
  else
    curl -sSfL https://rspamd.com/apt-stable/gpg.key | gpg --dearmor >/etc/apt/trusted.gpg.d/rspamd.gpg
    local URL='[arch=amd64 signed-by=/etc/apt/trusted.gpg.d/rspamd.gpg] http://rspamd.com/apt-stable/ bullseye main'
    echo "deb ${URL}" >"${DEB_FILE}"
    echo "deb-src ${URL}" >>"${DEB_FILE}"
    RSPAMD_PACKAGE_NAME='rspamd'
  fi

  _log 'debug' 'Installing Rspamd'
  apt-get "${QUIET}" update
  apt-get "${QUIET}" --no-install-recommends install "${RSPAMD_PACKAGE_NAME}" 'redis-server'
}

function _install_fail2ban() {
  local FAIL2BAN_DEB_URL='https://github.com/fail2ban/fail2ban/releases/download/1.0.2/fail2ban_1.0.2-1.upstream1_all.deb'
  local FAIL2BAN_DEB_ASC_URL="${FAIL2BAN_DEB_URL}.asc"
  local FAIL2BAN_GPG_FINGERPRINT='8738 559E 26F6 71DF 9E2C  6D9E 683B F1BE BD0A 882C'
  local FAIL2BAN_GPG_PUBLIC_KEY_ID='0x683BF1BEBD0A882C'
  local FAIL2BAN_GPG_PUBLIC_KEY_SERVER='hkps://keyserver.ubuntu.com'

  _log 'debug' 'Installing Fail2ban'
  apt-get "${QUIET}" --no-install-recommends install python3-pyinotify python3-dnspython

  gpg --keyserver "${FAIL2BAN_GPG_PUBLIC_KEY_SERVER}" --recv-keys "${FAIL2BAN_GPG_PUBLIC_KEY_ID}" 2>&1

  curl -Lkso fail2ban.deb "${FAIL2BAN_DEB_URL}"
  curl -Lkso fail2ban.deb.asc "${FAIL2BAN_DEB_ASC_URL}"

  FINGERPRINT=$(LANG=C gpg --verify fail2ban.deb.asc fail2ban.deb |& sed -n 's#Primary key fingerprint: \(.*\)#\1#p')

  if [[ -z ${FINGERPRINT} ]]; then
    echo 'ERROR: Invalid GPG signature!' >&2
    exit 1
  fi

  if [[ ${FINGERPRINT} != "${FAIL2BAN_GPG_FINGERPRINT}" ]]; then
    echo "ERROR: Wrong GPG fingerprint!" >&2
    exit 1
  fi

  dpkg -i fail2ban.deb 2>&1
  rm fail2ban.deb fail2ban.deb.asc

  _log 'debug' 'Patching Fail2ban to enable network bans'
  # Enable network bans
  # https://github.com/docker-mailserver/docker-mailserver/issues/2669
  sedfile -i -r 's/^_nft_add_set = .+/_nft_add_set = <nftables> add set <table_family> <table> <addr_set> \\{ type <addr_type>\\; flags interval\\; \\}/' /etc/fail2ban/action.d/nftables.conf
}

# Presently the getmail6 package is v6.14, which is too old.
# v6.18 contains fixes for Google and Microsoft OAuth support.
# using pip to install getmail.
# TODO This can be removed when the base image is updated to Debian 12 (Bookworm)
function _install_getmail() {
  _log 'debug' 'Installing getmail6'
  apt-get "${QUIET}" --no-install-recommends install python3-pip
  pip3 install --no-cache-dir 'getmail6~=6.18.12'
  ln -s /usr/local/bin/getmail /usr/bin/getmail
  ln -s /usr/local/bin/getmail-gmail-xoauth-tokens /usr/bin/getmail-gmail-xoauth-tokens
  apt-get "${QUIET}" purge python3-pip
  apt-get "${QUIET}" autoremove
}

function _remove_data_after_package_installations() {
  _log 'debug' 'Deleting sensitive files (secrets)'
  rm /etc/postsrsd.secret

  _log 'debug' 'Deleting default logwatch cronjob'
  rm /etc/cron.daily/00logwatch
}

function _post_installation_steps() {
  _log 'debug' 'Running post-installation steps (cleanup)'
  apt-get "${QUIET}" clean
  rm -rf /var/lib/apt/lists/*

  _log 'info' 'Finished installing packages'
}

_pre_installation_steps
_install_postfix
_install_packages
_install_dovecot
_install_rspamd
_install_fail2ban
_install_getmail
_remove_data_after_package_installations
_post_installation_steps
