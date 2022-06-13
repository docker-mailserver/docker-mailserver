#! /bin/bash

# Used from /usr/local/bin/helpers/index.sh:
# _create_lock, _log, CHKSUM_FILE

function _account_update_password_in_db
{
  local MAIL_ACCOUNT=${1}
  local PASSWD=${2}
  local DATABASE=${3}

  touch "${DATABASE}"
  _create_lock # Protect config file with lock to avoid race conditions

  _account_should_already_exist
  _password_request_if_missing

  local PASSWD_HASH=$(_password_hash "${MAIL_ACCOUNT}" "${PASSWD}")
  # Update password for an account in the DATABASE:
  sed -i "s/^${MAIL_ACCOUNT}|.*/${MAIL_ACCOUNT}|${PASSWD_HASH}/" "${DATABASE}"
}

function _account_add_to_db
{
  local MAIL_ACCOUNT=${1}
  local PASSWD=${2}
  local DATABASE=${3}

  touch "${DATABASE}"
  _create_lock # Protect config file with lock to avoid race conditions

  _account_should_not_exist_yet
  _password_request_if_missing

  local PASSWD_HASH=$(_password_hash "${MAIL_ACCOUNT}" "${PASSWD}")
  # Add an account entry with hashed password into the DATABASE:
  echo "${MAIL_ACCOUNT}|${PASSWD_HASH}" >>"${DATABASE}"
}

# TODO: Remove this method or at least it's usage in `addmailuser`. If tests are failing, correct the tests.
#
# This method was added delay command completion until a change detection event had processed the added user,
# so that the mail account was created. It was a workaround to accomodate the test suite apparently, but otherwise
# prevents batch adding users (each one would have to go through a change detection event individually currently..)
#
# Originally introduced in PR 1980 (then later two futher PRs deleted, and then reverted the deletion):
# https://github.com/docker-mailserver/docker-mailserver/pull/1980
# Not much details/discussion in the PR, these are the specific commits:
# - Initial commit: https://github.com/docker-mailserver/docker-mailserver/pull/1980/commits/2ed402a12cedd412abcf577e8079137ea05204fe#diff-92d2047e4a9a7965f6ef2f029dd781e09265b0ce171b5322a76e35b66ab4cbf4R67
# - Follow-up commit: https://github.com/docker-mailserver/docker-mailserver/pull/1980/commits/27542867b20c617b63bbec6fdcba421b65a44fbb#diff-92d2047e4a9a7965f6ef2f029dd781e09265b0ce171b5322a76e35b66ab4cbf4R67
#
# Original reasoning for this method (sounds like a network storage I/O issue):
# Tests fail if the creation of /var/mail/${DOMAIN}/${USER} doesn't happen fast enough after addmailuser executes (check-for-changes.sh race-condition)
# Prevent infinite loop in tests like "checking accounts: user3 should have been added to /tmp/docker-mailserver/postfix-accounts.cf even when that file does not exist"
function _wait_until_account_maildir_exists
{
  if [[ -f ${CHKSUM_FILE} ]]
  then
    local USER="${MAIL_ACCOUNT%@*}"
    local DOMAIN="${MAIL_ACCOUNT#*@}"

    local MAIL_ACCOUNT_STORAGE_DIR="/var/mail/${DOMAIN}/${USER}"
    while [[ ! -d ${MAIL_ACCOUNT_STORAGE_DIR} ]]
    do
      _log 'info' "Waiting for dovecot to create '${MAIL_ACCOUNT_STORAGE_DIR}'"
      sleep 1
    done
  fi
}
