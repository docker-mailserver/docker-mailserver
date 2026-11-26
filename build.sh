#!/bin/bash

set -eE -u -o pipefail
shopt -s inherit_errexit

VERSION_CODENAME='trixie'
ARCH_UNAME=$(uname --machine)
ARCH_DPKG=$(dpkg --print-architecture)
readonly VERSION_CODENAME ARCH_UNAME ARCH_DPKG

# shellcheck source=./rootfs/usr/local/lib/dms/helpers/log.sh
source /usr/local/lib/dms/helpers/log.sh

_log_level_is 'trace' && QUIET='-y' || QUIET='-qq'

function _pre_installation_steps() {
  _log 'info' 'Starting package installation'
  _log 'debug' 'Running pre-installation steps'

  _log 'trace' 'Refreshing local package index'
  apt-get "${QUIET}" update

  _log 'trace' 'Upgrading packages'
  apt-get "${QUIET}" upgrade

  _log 'trace' 'Installing packages that are needed early'
  local EARLY_PACKAGES=(
    # Avoid logging unnecessary warnings:
    apt-utils
    # Required to ensure correct `clamav` ownership (for associated COPY in Dockerfile):
    adduser
    # Required to support adding third-party repos (/etc/apt/sources.list.d) as alternative package sources (eg: Dovecot CE and Rspamd):
    apt-transport-https ca-certificates curl gnupg
    # Avoid problems with SA / Amavis (https://github.com/docker-mailserver/docker-mailserver/pull/3403#pullrequestreview-1596689953):
    systemd-standalone-sysusers
  )

  apt-get "${QUIET}" install --no-install-recommends "${EARLY_PACKAGES[@]}" 2>/dev/null

  # Ensure ownership is assigned to the `clamav` user/group (sync to the UID 200 ownership from the COPY instruction in the Dockerfile):
  # When the `clamav` package is later installed it will use this UID instead (otherwise value assigned would vary when modifying the package list).
  # https://github.com/docker-mailserver/docker-mailserver/issues/2942#issuecomment-1383512079
  adduser --quiet --system --group --disabled-password --home /var/lib/clamav --no-create-home --uid 200 clamav
}

# Install third-party commands to /usr/local/bin
function _install_utils() {
  # ? `*.tar.gz` releases tend to forget to reset UID/GID ownership when archiving. When extracting
  #   with `tar` as `root` the archived UID/GID is kept, unless using `--no-same-owner`. Likewise,
  #   when the binary is in a nested location the full archived path must be provided, and
  #   `--strip-components` to extract the file to the target directory. Doing this avoids the need
  #   for (`mv` + `rm`) or (`--to-stdout` + `chmod +x`)
  _log 'debug' 'Installing utilities from Github'

  _log 'trace' 'Installing jaq'
  local JAQ_VERSION='v3.1.2'
  curl -sSfL -o /usr/local/bin/jaq \
    "https://github.com/01mf02/jaq/releases/download/${JAQ_VERSION}/jaq-${ARCH_UNAME}-unknown-linux-gnu"
  chmod +x /usr/local/bin/jaq

  _log 'trace' 'Installing step'
  local STEP_CLI_VERSION='0.31.0'
  curl -sSfL -o /tmp/step-cli.deb \
    "https://github.com/smallstep/cli/releases/download/v${STEP_CLI_VERSION}/step-cli_${ARCH_DPKG}.deb"
  dpkg -i /tmp/step-cli.deb
  rm /tmp/step-cli.deb
}

function _install_packages() {
  _log 'debug' 'Installing all packages now'

  local ANTI_VIRUS_SPAM_PACKAGES=(
    clamav clamav-daemon
    # spamassassin is used only with amavisd-new
    amavisd-new spamassassin
  )

  # predominantly for Amavis support
  local CODECS_PACKAGES=(
    altermime arj bzip2
    cabextract cpio file
    gzip lhasa lz4
    lrzip lzop nomarch
    p7zip-full pax rpm2cpio
    unrar-free unzip xz-utils
  )

  local MISCELLANEOUS_PACKAGES=(
    binutils bsd-mailx
    dbconfig-no-thanks dumb-init iproute2
    libdate-manip-perl libldap-common libmail-spf-perl libnet-dns-perl
    locales logwatch netcat-openbsd
    nftables # primarily for Fail2Ban
    swaks perl-doc # required for `swaks --help` to work
    rsyslog supervisor
    # provides the default "snakeoil" cert for Dovecot and Postfix, Debian's `dovecot-core`
    # depends on it but the Dovecot CE package does not:
    ssl-cert
    uuid # used for file-locking
    whois
  )

  local POSTFIX_PACKAGES=(
    pflogsumm postgrey postfix postfix-ldap postfix-mta-sts-resolver
    postfix-pcre postfix-policyd-spf-python postsrsd
  )

  local MAIL_PROGRAMS_PACKAGES=(
    opendkim opendkim-tools
    opendmarc libsasl2-modules sasl2-bin
  )

  # These packages support community contributed features.
  # If they cause too much maintenance burden in future, they are liable for removal.
  local COMMUNITY_PACKAGES=(
    fetchmail getmail6
  )

  # `bind9-dnsutils` provides the `dig` command
  # `iputils-ping` provides the `ping` command
  DEBUG_PACKAGES=(
    bind9-dnsutils iputils-ping less nano
  )

  apt-get "${QUIET}" install --no-install-recommends \
    "${ANTI_VIRUS_SPAM_PACKAGES[@]}" \
    "${CODECS_PACKAGES[@]}" \
    "${MISCELLANEOUS_PACKAGES[@]}" \
    "${POSTFIX_PACKAGES[@]}" \
    "${MAIL_PROGRAMS_PACKAGES[@]}" \
    "${DEBUG_PACKAGES[@]}" \
    "${COMMUNITY_PACKAGES[@]}"
}

function _install_dovecot() {
  local DOVECOT_PACKAGES=(
    dovecot-core
    dovecot-lmtpd
    dovecot-imapd
    dovecot-pop3d
    dovecot-sieve
    dovecot-managesieved
    dovecot-ldap
    dovecot-flatcurve

    # Additional Dovecot packages for supporting the DMS community (docs-only guide contributions)
    dovecot-auth-lua
    dovecot-solr
  )

  # NOTE: (Opt-in via ENV) Change repo source for dovecot packages
  #       to a third-party repo maintained by Dovecot.
  # NOTE: Arch restriction required because AMD64 / x86_64 is the
  #       only arch supported from the Dovecot CE repo.
  # Repo: https://repo.dovecot.org/ce-2.4-latest/debian/trixie/dists/trixie/main/
  # Docs: https://repo.dovecot.org/#debian
  if [[ ${DOVECOT_COMMUNITY_REPO:-0} -eq 1 ]] && [[ $(uname --machine) == 'x86_64' ]]; then
    _log 'trace' 'Adding third-party package repository (Dovecot)'
    curl -fsSL https://repo.dovecot.org/DOVECOT-REPO-GPG-2.4 \
      | gpg --dearmor > /usr/share/keyrings/upstream-dovecot.gpg
    cat >/etc/apt/sources.list.d/upstream-dovecot.sources <<EOF
Types: deb
URIs: https://repo.dovecot.org/ce-2.4-latest/debian/${VERSION_CODENAME}
Suites: ${VERSION_CODENAME}
Components: main
Signed-By: /usr/share/keyrings/upstream-dovecot.gpg
EOF

    apt-get "${QUIET}" update

    # This repo instead provides `dovecot-auth-lua` as a transitional package to `dovecot-lua`,
    # thus this extra package is required to retain lua support:
    DOVECOT_PACKAGES+=(dovecot-lua)
  fi

  _log 'debug' 'Installing Dovecot'
  apt-get "${QUIET}" install --no-install-recommends "${DOVECOT_PACKAGES[@]}"

  # DMS ships its own Dovecot config (`rootfs/etc/dovecot/`, copied by the Dockerfile) that does not depend on the
  # layout of Debian's or the Dovecot CE packages. This includes FTS (flatcurve) being disabled by default.
  rm -rf /etc/dovecot/dovecot.conf /etc/dovecot/conf.d
}

# ? DMS only supports the Rspamd package built by the Rspamd project (AMD64 + ARM64),
#   as the version in Debian stable is a major version behind.
#
#   The release is pinned: The package index of the Rspamd APT repo only lists the newest
#   release, so the `.deb` of the pinned release is downloaded from the repo's pool instead
#   and verified. The apt repo is not added, so an upgrade of the system packages never
#   replaces Rspamd. To update Rspamd, change the version and both checksums.
#
# > https://rspamd.com/apt-stable/pool/main/r/rspamd/
#   https://rspamd.com/downloads.html#debian-and-ubuntu-linux
function _install_rspamd() {
  local RSPAMD_VERSION="4.3.0-1~25c9ecc~${VERSION_CODENAME}"
  local RSPAMD_ARCH RSPAMD_SHA256

  RSPAMD_ARCH=$(dpkg --print-architecture)
  case "${RSPAMD_ARCH}" in
    ( 'amd64' ) RSPAMD_SHA256='f188cc4a2500ac3b14f5ee0da21143556daf4a23c323d17893291e47009453ac' ;;
    ( 'arm64' ) RSPAMD_SHA256='834b597d49ce0bd78dae7bb4502b494ca48323d416f1f3b1f6c623aee9c21843' ;;
    ( * )
      _log 'error' "Unsupported arch: '${RSPAMD_ARCH}'"
      return 1
      ;;
  esac

  local RSPAMD_DEB="rspamd_${RSPAMD_VERSION}_${RSPAMD_ARCH}.deb"

  _log 'debug' 'Installing Rspamd'
  apt-get "${QUIET}" update
  curl -fsSLo "/tmp/${RSPAMD_DEB}" "https://rspamd.com/apt-stable/pool/main/r/rspamd/${RSPAMD_DEB}"
  echo "${RSPAMD_SHA256}  /tmp/${RSPAMD_DEB}" | sha256sum --check --quiet
  apt-get "${QUIET}" install "/tmp/${RSPAMD_DEB}" valkey-server
  rm "/tmp/${RSPAMD_DEB}"
}

function _install_fail2ban() {
  local FAIL2BAN_VERSION=1.1.1
  # upstream1 was withdrawn (wrong install paths); use upstream2:
  # https://github.com/fail2ban/fail2ban/issues/4222
  local FAIL2BAN_DEB_URL="https://github.com/fail2ban/fail2ban/releases/download/${FAIL2BAN_VERSION}/fail2ban_${FAIL2BAN_VERSION}-1.upstream2_all.deb"
  local FAIL2BAN_DEB_ASC_URL="${FAIL2BAN_DEB_URL}.asc"
  local FAIL2BAN_GPG_FINGERPRINT='8738 559E 26F6 71DF 9E2C  6D9E 683B F1BE BD0A 882C'
  local FAIL2BAN_GPG_PUBLIC_KEY_ID='0x683BF1BEBD0A882C'
  local FAIL2BAN_GPG_PUBLIC_KEY_SERVER='hkps://keyserver.ubuntu.com'

  _log 'debug' 'Installing Fail2ban'
  # Dependencies (https://github.com/docker-mailserver/docker-mailserver/pull/3403#discussion_r1306581431):
  apt-get "${QUIET}" install --no-install-recommends python3-pyinotify python3-dnspython python3-systemd

  gpg --keyserver "${FAIL2BAN_GPG_PUBLIC_KEY_SERVER}" --recv-keys "${FAIL2BAN_GPG_PUBLIC_KEY_ID}" 2>&1

  curl -fsSLo fail2ban.deb "${FAIL2BAN_DEB_URL}"
  curl -fsSLo fail2ban.deb.asc "${FAIL2BAN_DEB_ASC_URL}"

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
}

function _post_installation_steps() {
  _log 'debug' 'Running post-installation steps (cleanup)'
  _log 'debug' 'Deleting sensitive files (secrets)'
  rm /etc/postsrsd.secret

  _log 'debug' 'Deleting default logwatch cronjob'
  rm /etc/cron.daily/00logwatch

  _log 'trace' 'Removing leftovers from APT'
  apt-get "${QUIET}" clean
  rm -rf /var/lib/apt/lists/*

  _log 'trace' 'Removing locales, man pages and documentation'
  rm -rf /usr/share/locale/* /usr/share/man/* /usr/share/doc/*
  update-locale

  # Irrelevant config for DMS:
  # Creating a separate syslog socket was necessary as Debian configured
  # Postfix to run via chroot jail (DMS avoids that intentionally).
  rm /etc/rsyslog.d/postfix.conf
}

_pre_installation_steps
_install_utils
_install_packages
_install_dovecot
_install_rspamd
_install_fail2ban
_post_installation_steps
