#!/bin/bash
function _setup_user_uid () {
  if [[ "${UID_DOCKER}" != "5000" ]]; then
    _log 'debug' "Setting 'docker' UID to ${UID_DOCKER}"
    usermod --uid "${UID_DOCKER}" docker
  fi
  if [[ "${GID_DOCKER}" != "5000" ]]; then
    _log 'debug' "Setting 'docker' GID to ${GID_DOCKER}"
    groupmod --gid "${GID_DOCKER}" docker
  fi
}
