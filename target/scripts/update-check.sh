#! /bin/bash

# shellcheck source=./helpers/index.sh
source /usr/local/bin/helpers/index.sh

VERSION=$(</VERSION)
VERSION_URL='https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/VERSION'
CHANGELOG_URL='https://github.com/docker-mailserver/docker-mailserver/blob/master/CHANGELOG.md'

# check for correct syntax
# number + suffix. suffix must be 's' for seconds, 'm' for minutes, 'h' for hours or 'd' for days.
if [[ ! ${UPDATE_CHECK_INTERVAL} =~ ^[0-9]+[smhd]{1}$ ]]
then
  _log 'warn' "Invalid 'UPDATE_CHECK_INTERVAL' value '${UPDATE_CHECK_INTERVAL}'"
  _log 'warn' 'Falling back to daily update checks'
  UPDATE_CHECK_INTERVAL='1d'
fi

while true
do
  # get remote version information
  LATEST=$(curl -Lsf "${VERSION_URL}")

  # did we get a valid response?
  if [[ ${LATEST} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  then
    _log 'debug' "$(_print_date) Remote version information fetched"

    # compare versions
    if dpkg --compare-versions "${VERSION}" lt "${LATEST}"
    then
      # send mail notification to postmaster
      read -r -d '' MAIL << EOM
Hello ${POSTMASTER_ADDRESS}!

There is a docker-mailserver update available on your host: $(hostname -f)

Current version: ${VERSION}
Latest  version: ${LATEST}

Changelog: ${CHANGELOG_URL}
EOM
      echo "${MAIL}" | mail -s "Mailserver update available! [ ${VERSION} --> ${LATEST} ]" "${POSTMASTER_ADDRESS}" && \

      # only notify once
      _log 'info' "$(_print_date) Update available [ ${VERSION} --> ${LATEST} ]" && exit 0
    else
      _log 'debug' "$(_print_date) No update available"
    fi
  else
    _log 'warn' "$(_print_date) Update check failed"
  fi

  # check again in 'UPDATE_CHECK_INTERVAL' time
  sleep "${UPDATE_CHECK_INTERVAL}"
done
