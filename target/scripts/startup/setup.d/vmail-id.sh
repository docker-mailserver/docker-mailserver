#!/bin/bash

function _setup_vmail_id() {
  if [[ "${DMS_VMAIL_UID}" != "5000" ]]; then
    _log 'debug' "Setting 'docker' UID to ${DMS_VMAIL_UID}"
    usermod --uid "${DMS_VMAIL_UID}" docker
  fi
  if [[ "${DMS_VMAIL_GID}" != "5000" ]]; then
    _log 'debug' "Setting 'docker' GID to ${DMS_VMAIL_GID}"
    groupmod --gid "${DMS_VMAIL_GID}" docker
  fi
}
