#!/bin/bash

# -eE :: exit on error (do this in functions as well)
# -u  :: show (and exit) when using unset variables
# -o pipefail :: exit on error in pipes
set -eE -u -o pipefail

# shellcheck source=../helpers/log.sh
source /usr/local/bin/helpers/log.sh

# shellcheck disable=SC2310
_log_level_is 'trace' && QUIET='-y' || QUIET='-qq'

function _compile_dovecot_fts_xapian() {
  apt-get "${QUIET}" update
  apt-get "${QUIET}" install --no-install-recommends \
    automake libtool pkg-config libicu-dev libsqlite3-dev libxapian-dev make build-essential dh-make devscripts dovecot-dev

  local XAPIAN_VERSION='1.7.13'
  curl -sSfL -o dovecot-fts-xapian.tar.gz \
    "https://github.com/grosjo/fts-xapian/releases/download/${XAPIAN_VERSION}/dovecot-fts-xapian-${XAPIAN_VERSION}.tar.gz"
  tar xf dovecot-fts-xapian.tar.gz

  cd "fts-xapian-${XAPIAN_VERSION}"
  USER=root dh_make -p "dovecot-fts-xapian-${XAPIAN_VERSION}" --single --native --copyright gpl2 -y

  rm debian/*.ex
  cp PACKAGES/DEB/control debian/
  cp PACKAGES/DEB/changelog debian/
  cp PACKAGES/DEB/compat debian/

  sed -i -E "s|(dovecot-fts-xapian)-[1-9\.-]+|\1-${XAPIAN_VERSION}|g" debian/control
  sed -i -E "s|(dovecot-fts-xapian)-[1-9\.-]+ \(.*\)(.*)|\1-${XAPIAN_VERSION} (${XAPIAN_VERSION})\2|g" debian/changelog

  debuild -us -uc -B | tee /tmp/debuild.log 2>&1
}

_compile_dovecot_fts_xapian
