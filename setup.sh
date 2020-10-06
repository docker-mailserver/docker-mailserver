#!/bin/bash

# Wrapper for various setup scripts
# included in the docker-mailserver

SCRIPT='SETUP'

set -euEo pipefail
trap '__log_err ${FUNCNAME[0]:-"?"} ${_:-"?"} ${LINENO:-"?"} ${?:-"?"}' ERR

function __log_err
{
  local FUNC_NAME LINE EXIT_CODE
  FUNC_NAME="${1} / ${2}"
  LINE="${3}"
  EXIT_CODE="${4}"

  printf "\n––– \e[1m\e[31mUNCHECKED ERROR\e[0m\n%s\n%s\n%s\n%s\n\n" \
    "  – script    = ${SCRIPT,,}.sh" \
    "  – function  = ${FUNC_NAME}" \
    "  – line      = ${LINE}" \
    "  – exit code = ${EXIT_CODE}"

  _unset_vars
}

function _unset_vars
{
  unset CDIR CRI INFO IMAGE_NAME CONTAINER_NAME DEFAULT_CONFIG_PATH
  unset USE_CONTAINER WISHED_CONFIG_PATH CONFIG_PATH VOLUME USE_TTY
}

function _get_current_directory
{
  if dirname "$(readlink -f "${0}")" &>/dev/null
  then
    CDIR="$(cd "$(dirname "$(readlink -f "${0}")")" && pwd)"
  elif realpath -e -L "${0}" &>/dev/null
  then
    CDIR="$(realpath -e -L "${0}")"
    CDIR="${CDIR%/setup.sh}"
  fi
}

CDIR="$(pwd)"
_get_current_directory

CRI=
INFO=
IMAGE_NAME=
CONTAINER_NAME='mail'
DEFAULT_CONFIG_PATH="${CDIR}/config"
USE_CONTAINER=false
WISHED_CONFIG_PATH=
CONFIG_PATH=
VOLUME=
USE_TTY=

function _check_root
{
  if [[ ${EUID} -ne 0 ]]
  then
    echo "Curently docker-mailserver doesn't support podman's rootless mode, please run this script as root user."
    return 1
  fi
}

function _update_config_path
{
  if [[ -n ${CONTAINER_NAME} ]]
  then
    VOLUME=$(${CRI} inspect "${CONTAINER_NAME}" \
      --format="{{range .Mounts}}{{ println .Source .Destination}}{{end}}" | \
      grep "/tmp/docker-mailserver$" 2>/dev/null)
  fi

  if [[ -n ${VOLUME} ]]
  then
    CONFIG_PATH=$(echo "${VOLUME}" | awk '{print $1}')
  fi
}

function _inspect
{
  if _docker_image_exists "${IMAGE_NAME}"
  then
    echo "Image: ${IMAGE_NAME}"
  else
    echo "Image: '${IMAGE_NAME}' can’t be found."
  fi

  if [[ -n ${CONTAINER_NAME} ]]
  then
    echo "Container: ${CONTAINER_NAME}"
    echo "Config mount: ${CONFIG_PATH}"
  else
    echo "Container: Not running, please start docker-mailserver."
  fi
}

function _usage
{
  echo "${SCRIPT,,}.sh Bootstrapping Script

Usage: ${0} [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]

OPTIONS:

  -i IMAGE_NAME     The name of the docker-mailserver image, by default
                    'tvial/docker-mailserver:latest' for docker, and
                    'docker.io/tvial/docker-mailserver:latest' for podman.

  -c CONTAINER_NAME The name of the running container.

  -p PATH           Config folder path (default: ${CDIR}/config)

  -h                Show this help dialogue

SUBCOMMANDS:

  email:

    ${0} email add <email> [<password>]
    ${0} email update <email> [<password>]
    ${0} email del <email>
    ${0} email restrict <add|del|list> <send|receive> [<email>]
    ${0} email list

  alias:
    ${0} alias add <email> <recipient>
    ${0} alias del <email> <recipient>
    ${0} alias list

  quota:
    ${0} quota set <email> [<quota>]
    ${0} quota del <email>

  config:

    ${0} config dkim <keysize> (default: 2048)
    ${0} config ssl <fqdn>

  relay:

    ${0} relay add-domain <domain> <host> [<port>]
    ${0} relay add-auth <domain> <username> [<password>]
    ${0} relay exclude-domain <domain>

  debug:

    ${0} debug fetchmail
    ${0} debug fail2ban [<unban> <ip-address>]
    ${0} debug show-mail-logs
    ${0} debug inspect
    ${0} debug login <commands>

  help: Show this help dialogue

"
}

function _docker_image_exists
{
  if ${CRI} history -q "${1}" >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

function _docker_image
{
  if ${USE_CONTAINER}
  then
    # reuse existing container specified on command line
    ${CRI} exec "${USE_TTY}" "${CONTAINER_NAME}" "${@}"
  else
    # start temporary container with specified image
    if ! _docker_image_exists "${IMAGE_NAME}"
    then
      echo "Image '${IMAGE_NAME}' not found. Pulling ..."
      ${CRI} pull "${IMAGE_NAME}"
    fi

    ${CRI} run --rm \
      -v "${CONFIG_PATH}":/tmp/docker-mailserver \
      "${USE_TTY}" "${IMAGE_NAME}" "${@}"
  fi
}

function _docker_container
{
  if [[ -n ${CONTAINER_NAME} ]]
  then
    ${CRI} exec "${USE_TTY}" "${CONTAINER_NAME}" "${@}"
  else
    echo "The docker-mailserver is not running!"
    exit 5
  fi
}

function _main
{
  if [[ -n $(command -v docker) ]]
  then
    CRI=docker
  elif [[ -n $(command -v podman) ]]
  then
    CRI=podman
    _check_root
  else
    echo "No supported Container Runtime Interface detected."
    exit 10
  fi

  INFO=$(${CRI} ps \
    --no-trunc \
    --format "{{.Image}};{{.Names}}" \
    --filter label=org.label-schema.name="docker-mailserver" | \
    tail -1)

  IMAGE_NAME=${INFO%;*}
  CONTAINER_NAME=${INFO#*;}

  if [[ -z ${IMAGE_NAME} ]]
  then
    if [[ ${CRI} == "docker" ]]
    then
      IMAGE_NAME=tvial/docker-mailserver:latest
    elif [[ ${CRI} == "podman" ]]
    then
      IMAGE_NAME=docker.io/tvial/docker-mailserver:latest
    fi
  fi

  if tty -s
  then
    USE_TTY="-ti"
  fi

  local OPTIND
  while getopts ":c:i:p:h" OPT
  do
    case ${OPT} in
      c) CONTAINER_NAME="${OPTARG}" ; USE_CONTAINER=true ;; # container specified, connect to running instance
      i) IMAGE_NAME="${OPTARG}" ;;
      p)
        case "${OPTARG}" in
          /*) WISHED_CONFIG_PATH="${OPTARG}" ;;
          * ) WISHED_CONFIG_PATH="${CDIR}/${OPTARG}" ;;
        esac

        if [[ ! -d ${WISHED_CONFIG_PATH} ]]
        then
          echo "Directory doesn't exist"
          _usage
          exit 40
        fi
        ;;
      h) _usage ; return ;;
     *) echo "Invalid option: -${OPTARG}" >&2 ;;
    esac
  done
  shift $((OPTIND-1))

  if [[ -z ${WISHED_CONFIG_PATH} ]]
  then
    # no wished config path
    _update_config_path

    if [[ -z ${CONFIG_PATH} ]]
    then
      CONFIG_PATH=${DEFAULT_CONFIG_PATH}
    fi
  else
    CONFIG_PATH=${WISHED_CONFIG_PATH}
  fi


  case ${1:-} in

    email)
      shift ; case ${1:-} in
        add      ) shift ; _docker_image addmailuser "${@}" ;;
        update   ) shift ; _docker_image updatemailuser "${@}" ;;
        del      ) shift ; _docker_image delmailuser "${@}" ;;
        restrict ) shift ; _docker_container restrict-access "${@}" ;;
        list     ) _docker_image listmailuser ;;
        *        ) _usage ;;
      esac
      ;;

    alias)
      shift ; case ${1:-} in
        add      ) shift ; _docker_image addalias "${1}" "${2}" ;;
        del      ) shift ; _docker_image delalias "${1}" "${2}" ;;
        list     ) shift ; _docker_image listalias ;;
        *        ) _usage ;;
      esac
      ;;

    quota)
      shift ; case ${1:-} in
        set      ) shift ; _docker_image setquota "${@}" ;;
        del      ) shift ; _docker_image delquota "${@}" ;;
        *        )   _usage ;;
      esac
      ;;

    config)
      shift ; case ${1:-} in
        dkim     ) _docker_image generate-dkim-config "${2:-2048}" ;;
        ssl      ) _docker_image generate-ssl-certificate "${2}" ;;
        *        ) _usage ;;
      esac
      ;;

    relay)
      shift ; case ${1:-} in
        add-domain     ) shift ; _docker_image addrelayhost "${@}" ;;
        add-auth       ) shift ; _docker_image addsaslpassword "${@}" ;;
        exclude-domain ) shift ; _docker_image excluderelaydomain "${@}" ;;
        *              ) _usage ;;
      esac
      ;;

    debug)
      shift ; case ${1:-} in
        fetchmail      ) _docker_image debug-fetchmail ;;
        fail2ban       ) shift ; _docker_container fail2ban "${@}" ;;
        show-mail-logs ) _docker_container cat /var/log/mail/mail.log ;;
        inspect        ) _inspect ;;
        login          )
          shift
          if [[ -z ${1:-''} ]]
          then
            _docker_container /bin/bash
          else
            _docker_container /bin/bash -c "${@}"
          fi
          ;;
        *        ) _usage ; _unset_vars ; exit 1 ;;
      esac
      ;;

    help) _usage ;;

    *            ) _usage ; _unset_vars ; exit 1 ;;
  esac

  _unset_vars
}

_main "${@}"
