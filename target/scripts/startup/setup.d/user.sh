#!/bin/bash
function _setup_user_uid () {
  _log 'debug' 'Setting Custom UID if needed'
  if "${UID_DOCKER}" != 5000; then
    usermod -u "${UID_DOCKER}" docker
  fi
  if "${GID_DOCKER}" != 5000; then
    groupmod -u "${GID_DOCKER}" docker
  fi
}
