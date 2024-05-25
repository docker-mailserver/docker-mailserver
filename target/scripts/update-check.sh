#!/bin/bash

# shellcheck source=./helpers/log.sh
source /usr/local/bin/helpers/log.sh

VERSION="${DMS_RELEASE#v}"
VERSION_URL='https://github.com/docker-mailserver/docker-mailserver/releases/latest'
CHANGELOG_URL='https://github.com/docker-mailserver/docker-mailserver/blob/master/CHANGELOG.md'

# check for correct syntax
# number + suffix. suffix must be 's' for seconds, 'm' for minutes, 'h' for hours or 'd' for days.
if [[ ! ${UPDATE_CHECK_INTERVAL} =~ ^[0-9]+[smhd]{1}$ ]]; then
  _log 'warn' "Invalid 'UPDATE_CHECK_INTERVAL' value '${UPDATE_CHECK_INTERVAL}'"
  _log 'warn' 'Falling back to daily update checks'
  UPDATE_CHECK_INTERVAL='1d'
fi

while true; do
  # get remote version information
  # JSON response provides a field for the release tag, the `v` prefix is removed with `[1:]`
  LATEST=$(curl -sfL -H 'accept: application/json' "${VERSION_URL}" | jaq -r '.tag_name[1:]')

  # did we get a valid response?
  if [[ ${LATEST} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    _log 'debug' 'Remote version information fetched'

    # compare versions
    if dpkg --compare-versions "${VERSION}" lt "${LATEST}"; then
      # send mail notification to postmaster
      read -r -d '#' MAIL << EOF
Hello ${POSTMASTER_ADDRESS}!

There is a docker-mailserver update available on your host: $(hostname -f)

Current version: ${VERSION}
Latest  version: ${LATEST}

Changelog: ${CHANGELOG_URL}#END
EOF

      _log 'info' "Update available [ ${VERSION} --> ${LATEST} ]"

      # only notify once
      echo "${MAIL}" | mail -s "Mailserver update available! [ ${VERSION} --> ${LATEST} ]" "${POSTMASTER_ADDRESS}" && exit 0
    else
      _log 'info' 'No update available'
    fi
  else
    _log 'warn' 'Update check failed'
  fi

  # check again in 'UPDATE_CHECK_INTERVAL' time
  sleep "${UPDATE_CHECK_INTERVAL}"
done
