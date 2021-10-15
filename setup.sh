#! /bin/bash

# version   v1.0.0
# executed  manually / via Make
# task      wrapper for various setup scripts

CONFIG_PATH=
CONTAINER_NAME=
CRI=
DEFAULT_CONFIG_PATH=
DESIRED_CONFIG_PATH=
DIR="$(pwd)"
DMS_CONFIG='/tmp/docker-mailserver'
IMAGE_NAME=
DEFAULT_IMAGE_NAME='docker.io/mailserver/docker-mailserver:latest'
INFO=
PODMAN_ROOTLESS=false
USE_SELINUX=
USE_TTY=
VOLUME=

RED="\e[31m\e[1m"
WHITE="\e[37m"
ORANGE="\e[38;5;214m"
LBLUE="\e[94m"
RESET="\e[0m"

set -euEo pipefail
trap '__err "${BASH_SOURCE}" "${FUNCNAME[0]:-?}" "${BASH_COMMAND:-?}" "${LINENO:-?}" "${?:-?}"' ERR

function __err
{
  [[ ${5} -gt 1 ]] && exit 1

  local ERR_MSG="\n--- ${RED}UNCHECKED ERROR${RESET}"
  ERR_MSG+="\n  - script    = ${1}"
  ERR_MSG+="\n  - function  = ${2}"
  ERR_MSG+="\n  - command   = ${3}"
  ERR_MSG+="\n  - line      = ${4}"
  ERR_MSG+="\n  - exit code = ${5}"
  ERR_MSG+='\n\nThis should not have happened. Please file a bug report.\n'

  echo -e "${ERR_MSG}"
}

function _show_local_usage
{
  # shellcheck disable=SC2059
  printf "${ORANGE}OPTIONS${RESET}
    ${LBLUE}Config path, container or image adjustments${RESET}
        -i IMAGE_NAME
            Provides the name of the 'docker-mailserver' image. The default value is
            '${WHITE}${DEFAULT_IMAGE_NAME}${RESET}'

        -c CONTAINER_NAME
            Provides the name of the running container.

        -p PATH
            Provides the local path of the config folder to the temporary container instance.
            Does not work if an existing a 'docker-mailserver' container is already running.

    ${LBLUE}SELinux${RESET}
        -z
            Allows container access to the bind mount content that is shared among
            multiple containers on a SELinux-enabled host.

        -Z
            Allows container access to the bind mount content that is private and
            unshared with other containers on a SELinux-enabled host.

    ${LBLUE}Podman${RESET}
        -R
            Accept running in Podman rootless mode. Ignored when using Docker / Docker Compose.

"

  [[ ${1:-} == 'no-exit' ]] && return 0

  # shellcheck disable=SC2059
  printf "${ORANGE}EXIT STATUS${RESET}
    Exit status is 0 if the command was successful. If there was an unexpected error, an error
    message is shown describing the error. In case of an error, the script will exit with exit
    status 1.

"
}

function _get_absolute_script_directory
{
  if [[ "$(uname)" == 'Darwin' ]]
  then
    readlink() {
      # requires coreutils
      greadlink "${@:+$@}"
    }
  fi

  if dirname "$(readlink -f "${0}")" &>/dev/null
  then
    DIR="$(dirname "$(readlink -f "${0}")")"
  elif realpath -e -L "${0}" &>/dev/null
  then
    DIR="$(realpath -e -L "${0}")"
    DIR="${DIR%/setup.sh}"
  fi
}

function _set_default_config_path
{
  if [[ -d "${DIR}/config" ]]
  then
    # legacy path (pre v10.2.0)
    DEFAULT_CONFIG_PATH="${DIR}/config"
  else
    DEFAULT_CONFIG_PATH="${DIR}/docker-data/dms/config"
  fi
}

function _handle_config_path
{
  if [[ -z ${DESIRED_CONFIG_PATH} ]]
  then
    # no desired config path
    if [[ -n ${CONTAINER_NAME} ]]
    then
      VOLUME=$(${CRI} inspect "${CONTAINER_NAME}" \
        --format="{{range .Mounts}}{{ println .Source .Destination}}{{end}}" | \
        grep "${DMS_CONFIG}$" 2>/dev/null || :)
    fi

    if [[ -n ${VOLUME} ]]
    then
      CONFIG_PATH=$(echo "${VOLUME}" | awk '{print $1}')
    fi

    if [[ -z ${CONFIG_PATH} ]]
    then
      CONFIG_PATH=${DEFAULT_CONFIG_PATH}
    fi
  else
    CONFIG_PATH=${DESIRED_CONFIG_PATH}
  fi
}

function _run_in_new_container
{
  # start temporary container with specified image
  if ! ${CRI} history -q "${IMAGE_NAME}" &>/dev/null
  then
    echo "Image '${IMAGE_NAME}' not found. Pulling ..."
    ${CRI} pull "${IMAGE_NAME}"
  fi

  ${CRI} run --rm "${USE_TTY}" \
    -v "${CONFIG_PATH}:${DMS_CONFIG}${USE_SELINUX}" \
    "${IMAGE_NAME}" "${@:+$@}"
}

function _main
{
  _get_absolute_script_directory
  _set_default_config_path

  local OPTIND
  while getopts ":c:i:p:zZR" OPT
  do
    case ${OPT} in
      ( i )     IMAGE_NAME="${OPTARG}"     ;;
      ( z | Z ) USE_SELINUX=":${OPT}"      ;;
      ( c )     CONTAINER_NAME="${OPTARG}" ;;
      ( R )     PODMAN_ROOTLESS=true       ;;
      ( p )
        case "${OPTARG}" in
          ( /* ) DESIRED_CONFIG_PATH="${OPTARG}"        ;;
          ( *  ) DESIRED_CONFIG_PATH="${DIR}/${OPTARG}" ;;
        esac

        if [[ ! -d ${DESIRED_CONFIG_PATH} ]]
        then
          echo "Specified directory '${DESIRED_CONFIG_PATH}' doesn't exist" >&2
          exit 1
        fi
        ;;

      ( * )
        echo "Invalid option: '-${OPTARG}'" >&2
        echo -e "Use './setup.sh help' to get a complete overview.\n" >&2
        _show_local_usage 'no-exit'
        exit 1
        ;;

    esac
  done
  shift $(( OPTIND - 1 ))

  if command -v docker &>/dev/null
  then
    CRI=docker
  elif command -v podman &>/dev/null
  then
    CRI=podman
    if ! ${PODMAN_ROOTLESS} && [[ ${EUID} -ne 0 ]]
    then
      read -r -p "You are running Podman in rootless mode. Continue? [Y/n] "
      [[ -n ${REPLY} ]] && [[ ${REPLY} =~ (n|N) ]] && exit 0
    fi
  else
    echo 'No supported Container Runtime Interface detected.'
    exit 1
  fi

  INFO=$(${CRI} ps --no-trunc --format "{{.Image}};{{.Names}}" --filter \
    label=org.opencontainers.image.title="docker-mailserver" | tail -1)

  CONTAINER_NAME=${INFO#*;}
  [[ -z ${IMAGE_NAME} ]] && IMAGE_NAME=${INFO%;*}
  if [[ -z ${IMAGE_NAME} ]]
  then
    IMAGE_NAME=${NAME:-${DEFAULT_IMAGE_NAME}}
  fi

  if test -t 0
  then
    USE_TTY="-it"
  else
    # GitHub Actions will fail (or really anything else
    #   lacking an interactive tty) if we don't set a
    #   value here; "-t" alone works for these cases.
    USE_TTY="-t"
  fi

  _handle_config_path

  if [[ -n ${CONTAINER_NAME} ]]
  then
    ${CRI} exec "${USE_TTY}" "${CONTAINER_NAME}" setup "${@:+$@}"
  else
    _run_in_new_container setup "${@:+$@}"
  fi

  [[ ${1} == 'help' ]] && _show_local_usage

  return 0
}

_main "${@:+$@}"
