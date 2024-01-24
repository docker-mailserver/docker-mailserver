#!/bin/bash

# -eE :: exit on error (do this in functions as well)
# -u  :: show (and exit) when using unset variables
# -o pipefail :: exit on error in pipes
set -eE -u -o pipefail

# shellcheck source=../helpers/log.sh
source /usr/local/bin/helpers/log.sh

_log_level_is 'trace' && QUIET='-y' || QUIET='-qq'

function _compile_dovecot_fts_xapian() {
  apt-get "${QUIET}" update
  apt-get "${QUIET}" --no-install-recommends install automake libtool pkg-config libicu-dev libsqlite3-dev libxapian-dev make build-essential dh-make devscripts dovecot-dev
  curl -Lso dovecot-fts-xapian.tar.gz https://github.com/grosjo/fts-xapian/releases/download/1.5.5/dovecot-fts-xapian-1.5.5.tar.gz
  tar xzvf dovecot-fts-xapian.tar.gz
  cd fts-xapian-1.5.5
  USER=root dh_make -p dovecot-fts-xapian-1.5.5 --single --native --copyright gpl2 -y
  rm debian/*.ex
  cp PACKAGES/DEB/control debian/
  cp PACKAGES/DEB/changelog debian/
  cp PACKAGES/DEB/compat debian/
  sed -i 's/1\.4\.11-6/1.5.5/g' debian/control
  sed -i 's/1\.4\.11-6/1.5.5/g' debian/changelog

  debuild -us -uc -B | tee /tmp/debuild.log 2>&1
}

_compile_dovecot_fts_xapian
