#!/bin/bash

# Outputs the DNS label count (delimited by `.`) for the given input string.
# Useful for determining an FQDN like `mail.example.com` (3), vs `example.com` (2).
function _get_label_count() {
  awk -F '.' '{ print NF }' <<< "${1}"
}

# Sets HOSTNAME and DOMAINNAME globals used throughout the scripts,
# and any subprocesses called that intereact with it.
function _obtain_hostname_and_domainname() {
  # Normally this value would match the output of `hostname` which mirrors `/proc/sys/kernel/hostname`,
  # However for legacy reasons, the system ENV `HOSTNAME` was replaced here with `hostname -f` instead.
  #
  # TODO: Consider changing to `DMS_FQDN`; a more accurate name, and removing the `export`, assuming no
  # subprocess like postconf would be called that would need access to the same value via `$HOSTNAME` ENV.
  #
  # ! There is already a stub in variables.sh which contains DMS_FQDN. One will just need to uncomment the
  # ! correct lines in variables.sh.
  #
  # TODO: `OVERRIDE_HOSTNAME` was introduced for non-Docker runtimes that could not configure an explicit hostname.
  # Kubernetes was the particular runtime in 2017. This does not update `/etc/hosts` or other locations, thus risking
  # inconsistency with expected behaviour. Investigate if it's safe to remove support. (--net=host also uses this as a workaround)
  export HOSTNAME="${OVERRIDE_HOSTNAME:-$(hostname -f)}"

  # If the container is misconfigured.. `hostname -f` (which derives it's return value from `/etc/hosts` or DNS query),
  # will result in an error that returns an empty value. This warrants a panic.
  if [[ -z ${HOSTNAME} ]]; then
    _dms_panic__misconfigured 'obtain_hostname' '/etc/hosts'
  fi

  # If the `HOSTNAME` is more than 2 labels long (eg: mail.example.com),
  # We take the FQDN from it, minus the 1st label (aka _short hostname_, `hostname -s`).
  #
  # TODO: For some reason we're explicitly separating out a domain name from our FQDN,
  # `hostname -d` was probably not the correct command for this intention either.
  # Needs further investigation for relevance, and if `/etc/hosts` is important for consumers
  # of this variable or if a more deterministic approach with `cut` should be relied on.
  if [[ $(_get_label_count "${HOSTNAME}") -gt 2 ]]; then
    if [[ -n ${OVERRIDE_HOSTNAME:-} ]]; then
      # Emulates the intended behaviour of `hostname -d`:
      # Assign the HOSTNAME value minus everything up to and including the first `.`
      DOMAINNAME=${HOSTNAME#*.}
    else
      # Operates on the FQDN returned from querying `/etc/hosts` or fallback DNS:
      #
      # Note if you want the actual NIS `domainname`, use the `domainname` command,
      # or `cat /proc/sys/kernel/domainname`.
      # Our usage of `domainname` is under consideration as legacy, and not advised
      # going forward. In future our docs should drop any mention of it.

      #shellcheck disable=SC2034
      DOMAINNAME=$(hostname -d)
    fi
  fi

  # Otherwise we assign the same value (eg: example.com):
  # Not an else statement in the previous conditional in the event that `hostname -d` fails.
  DOMAINNAME="${DOMAINNAME:-${HOSTNAME}}"
}
