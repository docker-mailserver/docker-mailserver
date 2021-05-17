#! /bin/bash

# DMS_VERSION == Commit hash?
if [[ ${DMS_VERSION} =~ ^[a-f0-9]{40}$ ]]
then
  DATE=$(date '+%F %T')
  echo "${DATE} Info: You are using an edge build. Update checks are not supported."
  exit 0
fi

API="https://api.github.com/repos/docker-mailserver/docker-mailserver/releases/latest"
CHANGELOG="https://github.com/docker-mailserver/docker-mailserver/blob/master/CHANGELOG.md"

while true
do
  DATE=$(date '+%F %T')

  # get remote version information
  LATEST=$(curl -Lsf "${API}" | jq -r '.tag_name')

  # did we get a valid response?
  if [[ ${LATEST} =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
  then
    LATEST=${LATEST:1}
    echo "${DATE} Info: Remote version information fetched"

    # compare versions
    if dpkg --compare-versions "${DMS_VERSION}" lt "${LATEST}"
    then
      # send mail notification to postmaster
      read -r -d '' MAIL << EOM
Hello ${POSTMASTER_ADDRESS}!

There is a docker-mailserver update available on your host: $(hostname -f)

Current version: ${DMS_VERSION}
Latest  version: ${LATEST}

Changelog: ${CHANGELOG}
EOM
      echo "${MAIL}" | mail -s "Mailserver update available! [ ${DMS_VERSION} --> ${LATEST} ]" "${POSTMASTER_ADDRESS}" && \

      echo "${DATE} Info: Update available [ ${DMS_VERSION} --> ${LATEST} ]" && \

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
