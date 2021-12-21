#!/bin/bash

# CI ENV `GITHUB_REF` from Github Actions CI provides the tag or branch that triggered the build
# See `github.ref`: https://docs.github.com/en/actions/reference/context-and-expression-syntax-for-github-actions#github-context
# https://docs.github.com/en/actions/reference/environment-variables
function _update_versions_json
{
  # Extract the version tag, truncate `<PATCH>` version and any suffix beyond it.
  local MAJOR_MINOR
  MAJOR_MINOR=$(grep -oE 'v[0-9]+\.[0-9]+' <<< "${GITHUB_REF}")
  # Github Actions CI method for exporting ENV vars to share across a jobs steps
  # https://docs.github.com/en/actions/reference/workflow-commands-for-github-actions#setting-an-environment-variable
  echo "DOCS_VERSION=${MAJOR_MINOR}" >> "${GITHUB_ENV}"

  if [[ -z "${MAJOR_MINOR}" ]]
  then
    echo "Could not extract valid \`v<MAJOR>.<MINOR>\` substring, exiting.."
    exit 1
  fi

  local VERSIONS_JSON='versions.json'
  local IS_VALID
  IS_VALID=$(jq '.' "${VERSIONS_JSON}")

  if [[ ! -f "${VERSIONS_JSON}" ]] || [[ -z "${IS_VALID}" ]]
  then
    echo "'${VERSIONS_JSON}' doesn't exist or is invalid. Creating.."
    echo '[{"version": "edge", "title": "edge", "aliases": []}]' > "${VERSIONS_JSON}"
  fi


  # Only add this tag version the first time it's encountered:
  local VERSION_EXISTS
  VERSION_EXISTS=$(jq --arg version "${MAJOR_MINOR}" '[.[].version == $version] | any' "${VERSIONS_JSON}")

  if [[ ${VERSION_EXISTS} == "true" ]]
  then
    echo "${MAJOR_MINOR} docs are already supported. Nothing to change, exiting.."
    exit 1
  else
    echo "Added support for ${MAJOR_MINOR} docs."
    # Add any logic here if you want the version selector to have a different label (`title`) than the `version` URL/subdirectory.
    local TITLE=${TITLE:-${MAJOR_MINOR}}

    # Assumes the first element is always the "latest" unreleased version (`edge` for us), and then newest version to oldest.
    # `jq` takes the first array element of array as slice, concats with new element, then takes the slice of remaining original elements to concat.
    # Thus assumes this script is always triggered by newer versions, no older major/minor releases as our build workflow isn't setup to support rebuilding older docs.
    local UPDATED_JSON
    UPDATED_JSON=$(jq --arg version "${MAJOR_MINOR}" --arg title "${TITLE}" \
      '.[:1] + [{version: $version, title: $title, aliases: []}] + .[1:]' \
      "${VERSIONS_JSON}"
    )

    # See `jq` FAQ advising this approach to update file:
    # https://github.com/stedolan/jq/wiki/FAQ
    echo "${UPDATED_JSON}" > tmp.json && mv tmp.json "${VERSIONS_JSON}"
  fi
}

_update_versions_json
