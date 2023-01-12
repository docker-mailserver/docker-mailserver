#!/bin/bash

function _escape
{
  echo "${1//./\\.}"
}

# Returns input after filtering out lines that are:
# empty, white-space, comments (`#` as the first non-whitespace character)
function _get_valid_lines_from_file
{
  grep --extended-regexp --invert-match "^\s*$|^\s*#" "${1}" || true
}

# Provide the name of an environment variable to this function
# and it will return its value stored in /etc/dms-settings
function _get_dms_env_value
{
  grep "^${1}=" /etc/dms-settings | cut -d "'" -f 2
}

# TODO: `chown -R 5000:5000 /var/mail` has existed since the projects first commit.
# It later received a depth guard to apply the fix only when it's relevant for a dir.
# Assess if this still appropriate, it appears to be problematic for some LDAP users.
#
# `helpers/accounts.sh:_create_accounts` (mkdir, cp) appears to be the only writer to
# /var/mail folders (used during startup and change detection handling).
function _chown_var_mail_if_necessary
{
  # fix permissions, but skip this if 3 levels deep the user id is already set
  if find /var/mail -maxdepth 3 -a \( \! -user 5000 -o \! -group 5000 \) | read -r
  then
    _log 'trace' 'Fixing /var/mail permissions'
    chown -R 5000:5000 /var/mail || return 1
  fi
}

function _require_n_parameters_or_print_usage
{
  local COUNT
  COUNT=${1}
  shift

  [[ ${1:-} == 'help' ]]  && { __usage ; exit 0 ; }
  [[ ${#} -lt ${COUNT} ]] && { __usage ; exit 1 ; }
}

# NOTE: Postfix commands that read `main.cf` will stall execution,
# until the config file has not be written to for at least 2 seconds.
# After we modify the config explicitly, we can safely assume (reasonably)
# that the write stream has completed, and it is safe to read the config.
# https://github.com/docker-mailserver/docker-mailserver/issues/2985
function _adjust_mtime_for_postfix_maincf
{
  if [[ $(( $(date '+%s') - $(stat -c '%Y' '/etc/postfix/main.cf') )) -lt 2 ]]
  then
    touch -d '2 seconds ago' /etc/postfix/main.cf
  fi
}

function _reload_postfix
{
  _adjust_mtime_for_postfix_maincf
  postfix reload
}
