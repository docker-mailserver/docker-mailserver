#! /bin/bash

set -eE -u -o pipefail

# shellcheck source=../helpers/log.sh
source /usr/local/bin/helpers/log.sh

export DEBIAN_FRONTEND=noninteractive
QUIET='-qq' ; _log_level_is_trace && QUIET='-y'

function _pre_installation_steps() {
  _log 'info' 'Starting package installation'
  _log 'debug' 'Running pre-installation steps'

  _log 'trace' 'Updating package signatures'
  apt-get "${QUIET}" update

  _log 'trace' 'Installing packages that are needed early'
  apt-get "${QUIET}" install --no-install-recommends \
    apt-transport-https apt-utils ca-certificates \
    curl gnupg2 ssl-cert 2>/dev/null

  _log 'trace' 'Upgrading packages'
  apt-get "${QUIET}" dist-upgrade

  _log 'trace' 'Updating CA certificates'
  update-ca-certificates
}

function _install_postfix() {
  _log 'debug' 'Installing Postfix'

  _log 'warn' "Applying workaround for Postfix bug (see https://github.com/docker-mailserver/docker-mailserver/issues/2023#issuecomment-855326403)"

  mv /bin/hostname /bin/hostname.bak
  echo "echo 'docker-mailserver.invalid'" >/bin/hostname
  chmod +x /bin/hostname
  apt-get "${QUIET}" install --no-install-recommends postfix
  mv /bin/hostname.bak /bin/hostname
}

function _setup_apt_sources() {
  _log 'debug' 'Acquiring package sources (PPAs)'

  _log 'trace' 'Getting RSPAMD GPG keys and PPA'
  local RSPAMD_GPG_KEY_LOCATION='/etc/apt/trusted.gpg.d/rspamd.gpg'
  curl -sSfL https://rspamd.com/apt-stable/gpg.key \
    | gpg --dearmor >"${RSPAMD_GPG_KEY_LOCATION}"
  echo \
    "deb [arch=amd64 signed-by=${RSPAMD_GPG_KEY_LOCATION}] http://rspamd.com/apt-stable/ bullseye main" \
    >/etc/apt/sources.list.d/rspamd.list

  _log 'trace' 'Updating package signatures again'
  apt-get "${QUIET}" update
}

function _install_packages() {
  _log 'debug' 'Installing all packages now'

  declare -a DOVECOT_PACKAGES
  DOVECOT_PACKAGES=(
    dovecot-core
    dovecot-fts-xapian
    dovecot-imapd
    dovecot-ldap
    dovecot-lmtpd
    dovecot-managesieved
    dovecot-pop3d
    dovecot-sieve
    dovecot-solr
  )

  apt-get "${QUIET}" --no-install-recommends install \
    amavisd-new binutils cron dbconfig-no-thanks \
    clamav clamav-daemon \
    "${DOVECOT_PACKAGES[@]}" dumb-init \
    fetchmail fail2ban gzip htop iproute2 \
    locales logwatch libldap-common netcat-openbsd nftables \
    opendkim opendkim-tools opendmarc \
    pflogsumm postgrey p7zip-full \
    postfix-ldap postfix-pcre postfix-policyd-spf-python \
    postsrsd pyzor razor redis-server rspamd rsyslog sasl2-bin \
    spamassassin supervisor uuid xz-utils
}

function _post_installation_steps() {
  _log 'debug' 'Running post-installation steps (cleanup)'
  apt-get "${QUIET}" autoremove
  apt-get "${QUIET}" autoclean
  apt-get "${QUIET}" clean
  rm -rf /var/lib/apt/lists/*
  c_rehash &>/dev/null

  _log 'info' 'Finished installing packages'
}

_pre_installation_steps
_install_postfix
_setup_apt_sources
_install_packages
_post_installation_steps
