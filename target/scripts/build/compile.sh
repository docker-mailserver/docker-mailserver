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
  local XAPIAN_VERSION='1.9'
  curl -fsSL "https://github.com/grosjo/fts-xapian/releases/download/${XAPIAN_VERSION}/dovecot-fts-xapian-${XAPIAN_VERSION}.tar.gz" \
    | tar -xz
  cd "fts-xapian-${XAPIAN_VERSION}"

  # Prepare for building DEB source package:
  # https://manpages.debian.org/bookworm/dh-make/dh_make.1.en.html
  # License LGPL 2.1: https://github.com/grosjo/fts-xapian/issues/174#issuecomment-2422404568
  USER=root dh_make --packagename "dovecot-fts-xapian-${XAPIAN_VERSION}" --single --native --copyright lgpl2 -y
  # Remove generated example files:
  rm debian/*.ex
  # Add required package metadata:
  # https://www.debian.org/doc/manuals/maint-guide/dreq.en.html#control
  curl -fsSL https://raw.githubusercontent.com/grosjo/fts-xapian/refs/tags/1.7.16/PACKAGES/DEB/control > debian/control
  # Replace version number:
  sed -i -E "s|(dovecot-fts-xapian)-[1-9\.-]+|\1-${XAPIAN_VERSION}|g" debian/control
  # Required to proceed with debuild:
  # https://www.debian.org/doc/manuals/maint-guide/dother.en.html#compat
  # (13 is the default debhelper version from the original `dh_make` generated `debian/control`):
  echo '13' > debian/compat

  # Build arch specific binary package via debuild:
  # https://manpages.debian.org/bookworm/devscripts/debuild.1.en.html
  # https://manpages.debian.org/bookworm/dpkg-dev/dpkg-buildpackage.1.en.html
  debuild --no-sign --build=any | tee /tmp/debuild.log 2>&1
}

_install_build_deps
_build_package
