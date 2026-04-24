#!/bin/bash

# -eE :: exit on error (do this in functions as well)
# -u  :: show (and exit) when using unset variables
# -o pipefail :: exit on error in pipes
set -eE -u -o pipefail

# shellcheck source=../helpers/log.sh
source /usr/local/bin/helpers/log.sh

# shellcheck disable=SC2310
_log_level_is 'trace' && QUIET='-y' || QUIET='-qq'

function _install_build_deps() {
  apt-get "${QUIET}" update
  apt-get "${QUIET}" install --no-install-recommends \
    automake libtool pkg-config libicu-dev libsqlite3-dev libxapian-dev make build-essential dh-make devscripts dovecot-dev
}

function _build_package() {
  local XAPIAN_DEBIAN_VERSION='1.9.1-1~bpo12+1'
  local XAPIAN_VERSION="${XAPIAN_DEBIAN_VERSION%-*}"
  curl -fsSL "https://deb.debian.org/debian/pool/main/d/dovecot-fts-xapian/dovecot-fts-xapian_${XAPIAN_VERSION}.orig.tar.gz" \
    | tar -xz
  cd "fts-xapian-${XAPIAN_VERSION}"

  # Prepare for building DEB source package:
  # Add required package metadata:
  # https://www.debian.org/doc/manuals/maint-guide/dreq.en.html#control
  curl -fsSL "https://deb.debian.org/debian/pool/main/d/dovecot-fts-xapian/dovecot-fts-xapian_${XAPIAN_DEBIAN_VERSION}.debian.tar.xz" | tar -xJ

  # Build arch specific binary package via debuild:
  # https://manpages.debian.org/bookworm/devscripts/debuild.1.en.html
  # https://manpages.debian.org/bookworm/dpkg-dev/dpkg-buildpackage.1.en.html
  debuild --no-sign --build=any | tee /tmp/debuild.log 2>&1
}

_install_build_deps
_build_package
