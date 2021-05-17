#! /bin/bash

while true
do
  DATE=$(date '+%F %T')

  # get remote version information
  LATEST=$(curl -Lsf https://api.github.com/repos/docker-mailserver/docker-mailserver/releases/latest | jq -r '.tag_name')

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

Changelog: https://github.com/docker-mailserver/docker-mailserver/blob/master/CHANGELOG.md
EOM
      echo "${MAIL}" | mail -s "Update available! [ ${DMS_VERSION} --> ${LATEST} ]" "${POSTMASTER_ADDRESS}" && \

      echo "${DATE} Info: Update available [ ${DMS_VERSION} --> ${LATEST} ]" && \

      # only notify once
      exit 0
    else
      echo "${DATE} Info: No update available"
    fi
  else
    echo "${DATE} Error: Update-check failed."
  fi
  # check again in one day
  sleep 1d
done
