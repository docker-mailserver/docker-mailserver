#! /bin/bash

# -eE :: exit on error (do this in functions as well)
# -u  :: show (and exit) when using unset variables
# -o pipefail :: exit on error in pipes
set -eE -u -o pipefail

# shellcheck source=../helpers/log.sh
source /usr/local/bin/helpers/log.sh

QUIET='-qq' ; [[ ${LOG_LEVEL} =~ ^trace$ ]] && QUIET='-y'

function _pre_installation_steps
{
  _log 'info' 'Starting package installation'
  _log 'debug' 'Running pre-installation steps'

  _log 'trace' 'Updating package signatures'
  apt-get "${QUIET}" update

  _log 'trace' 'Installing packages that are needed early'
  apt-get "${QUIET}" install --no-install-recommends \
    apt-transport-https apt-utils ca-certificates \
    curl gnupg2 ssl-cert 2>/dev/null

  _log 'trace' 'Upgrading packages'
  apt-get "${QUIET}" upgrade
}

function _install_postfix
{
  _log 'debug' 'Installing Postfix'

  _log 'warn' 'Applying workaround for Postfix bug (see https://github.com//issues/2023#issuecomment-855326403)'

  # Debians postfix package has a post-install script that expects a valid FQDN hostname to work:
  mv /bin/hostname /bin/hostname.bak
  echo "echo 'docker-mailserver.invalid'" >/bin/hostname
  chmod +x /bin/hostname
  apt-get "${QUIET}" install --no-install-recommends postfix
  mv /bin/hostname.bak /bin/hostname
}

function _install_packages
{
  _log 'debug' 'Installing all packages now'

  declare -a DOVECOT_PACKAGES ANTI_VIRUS_SPAM_PACKAGES
  declare -a CODECS_PACKAGES MISCELLANEOUS_PACKAGES
  declare -a POSTFIX_PACKAGES MAIL_PROGRAMS_PACKAGES

  DOVECOT_PACKAGES=(
    dovecot-core dovecot-fts-xapian dovecot-imapd
    dovecot-ldap dovecot-lmtpd dovecot-managesieved
    dovecot-pop3d dovecot-sieve dovecot-solr
  )

  ANTI_VIRUS_SPAM_PACKAGES=(
    amavisd-new clamav clamav-daemon
    fail2ban pyzor razor spamassassin
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
    binutils bsd-mailx dbconfig-no-thanks
    dumb-init ed gamin gnupg iproute2
    libdate-manip-perl libldap-common
    libmail-spf-perl libnet-dns-perl
    locales logwatch netcat-openbsd
    nftables rsyslog supervisor
    uuid whois
  )

  POSTFIX_PACKAGES=(
    pflogsumm postgrey postfix-ldap
    postfix-pcre postfix-policyd-spf-python postsrsd
  )

  MAIL_PROGRAMS_PACKAGES=(
    fetchmail opendkim opendkim-tools
    opendmarc libsasl2-modules sasl2-bin
  )

  apt-get "${QUIET}" --no-install-recommends install \
    "${DOVECOT_PACKAGES[@]}" \
    "${ANTI_VIRUS_SPAM_PACKAGES[@]}" \
    "${CODECS_PACKAGES[@]}" \
    "${MISCELLANEOUS_PACKAGES[@]}" \
    "${POSTFIX_PACKAGES[@]}" \
    "${MAIL_PROGRAMS_PACKAGES[@]}"
}

function _post_installation_steps
{
  _log 'debug' 'Running post-installation steps (cleanup)'
  apt-get "${QUIET}" clean
  rm -rf /var/lib/apt/lists/*

  _log 'info' 'Finished installing packages'
}

_pre_installation_steps
_install_postfix
_install_packages
_post_installation_steps
