#!/bin/bash
function _setup_user_uid () {
  _log 'debug' 'Setting Custom UID if needed'
  if "${UID_DOCKER}" != 5000; then
    usermod -u "${UID_DOCKER}" docker
    groupmod -u "${UID_DOCKER}" docker
  fi

}
