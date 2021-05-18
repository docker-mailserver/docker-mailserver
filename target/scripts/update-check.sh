#! /bin/bash

VERSION=$(</VERSION)
#VERSION_URL="https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/VERSION" # doesn't exist yet
VERSION_URL="https://raw.githubusercontent.com/casperklein/archive_docker-mailserver/update-check/VERSION"
CHANGELOG="https://github.com/docker-mailserver/docker-mailserver/blob/master/CHANGELOG.md"

_log() {
  DATE=$(date '+%F %T')
  echo "${DATE} ${1}"
}

# check for correct syntax
if [[ ! ${UPDATE_CHECK_INTERVAL} =~ ^[0-9]+[smhd]{1}$ ]]
then
  _log "Error: Invalid UPDATE_CHECK_INTERVAL value: ${UPDATE_CHECK_INTERVAL}"
  _log "Info: Fallback to daily update checks"
  UPDATE_CHECK_INTERVAL="1d"
fi

while true
do
  # get remote version information
  LATEST=$(curl -Lsf "${VERSION_URL}")

  # did we get a valid response?
  if [[ ${LATEST} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  then
    _log "Info: Remote version information fetched"

    # compare versions
    if dpkg --compare-versions "${VERSION}" lt "${LATEST}"
    then
      # send mail notification to postmaster
      read -r -d '' MAIL << EOM
Hello ${POSTMASTER_ADDRESS}!

There is a docker-mailserver update available on your host: $(hostname -f)

Current version: ${VERSION}
Latest  version: ${LATEST}

Changelog: ${CHANGELOG}
EOM
      echo "${MAIL}" | mail -s "Mailserver update available! [ ${VERSION} --> ${LATEST} ]" "${POSTMASTER_ADDRESS}" && \

      _log "Info: Update available [ ${VERSION} --> ${LATEST} ]" && \

      # only notify once
      exit 0
    else
      _log "Info: No update available"
    fi
  else
    _log "Error: Update check failed."
  fi
  # check again in one day
  sleep "${UPDATE_CHECK_INTERVAL}"
done
