#! /bin/bash

VERSION=$(</VERSION)
#VERSION_URL="https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/VERSION" # doesn't exist yet
VERSION_URL="https://raw.githubusercontent.com/casperklein/archive_docker-mailserver/update-check/VERSION"
CHANGELOG="https://github.com/docker-mailserver/docker-mailserver/blob/master/CHANGELOG.md"

while true
do
  DATE=$(date '+%F %T')

  # get remote version information
  LATEST=$(curl -Lsf "${VERSION_URL}")

  # did we get a valid response?
  if [[ ${LATEST} =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
  then
    echo "${DATE} Info: Remote version information fetched"

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

      echo "${DATE} Info: Update available [ ${VERSION} --> ${LATEST} ]" && \

      # only notify once
      exit 0
    else
      echo "${DATE} Info: No update available"
    fi
  else
    echo "${DATE} Error: Update check failed."
  fi
  # check again in one day
  sleep 1d
done
