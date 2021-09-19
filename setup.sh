#! /bin/bash

# version   v1.0.0
# executed  manually / via Make
# task      wrapper for various setup scripts

SCRIPT='setup.sh'

set -euEo pipefail
trap '__err "${FUNCNAME[0]:-?}" "${BASH_COMMAND:-?}" "${LINENO:-?}" "${?:-?}"' ERR

function __err
{
  [[ ${4} -gt 1 ]] && exit 1

  local ERR_MSG='--- \e[31m\e[1mUNCHECKED ERROR\e[0m'
  ERR_MSG+="\n  - script    = ${SCRIPT:-${0}}"
  ERR_MSG+="\n  - function  = ${1} / ${2}"
  ERR_MSG+="\n  - line      = ${3}"
  ERR_MSG+="\n  - exit code = ${4}"
  ERR_MSG+='\n'

  echo -e "${ERR_MSG}"
}

function _show_local_usage
{
  local WHITE="\e[37m"
  local ORANGE="\e[38;5;214m"
  local LBLUE="\e[94m"
  local RESET="\e[0m"

  # shellcheck disable=SC2059
  printf "${ORANGE}OPTIONS${RESET}
    ${LBLUE}Config path, container or image adjustments${RESET}
        -i IMAGE_NAME
            Provides the name of the docker-mailserver image. The default value is
            ${WHITE}docker.io/mailserver/docker-mailserver:latest${RESET}

        -c CONTAINER_NAME
            Provides the name of the running container.

        -p PATH
            Provides the config folder path to the temporary container (does not work if docker-mailserver container already exists).

    ${LBLUE}SELinux${RESET}
        -z
            Allows container access to the bind mount content that is shared among
            multiple containers on a SELinux-enabled host.

        -Z
            Allows container access to the bind mount content that is private and
            unshared with other containers on a SELinux-enabled host.

${ORANGE}EXIT STATUS${RESET}
    Exit status is 0 if the command was successful. If there was an unexpected error, an error
    message is shown describing the error. In case of an error, the script will exit with exit
    status 1.

"
}

function _get_absolute_script_directory
{
  if [[ "$(uname)" == "Darwin" ]]
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

DIR="$(pwd)"
_get_absolute_script_directory

CRI=
CONFIG_PATH=
CONTAINER_NAME=
DEFAULT_CONFIG_PATH="${DIR}/config"
IMAGE_NAME=
INFO=
USE_TTY=
USE_SELINUX=
VOLUME=
WISHED_CONFIG_PATH=

function _check_root
{
  if [[ ${EUID} -ne 0 ]]
  then
    echo "Curently, DMS doesn't support podman's rootless mode.
Please run this script as root user."

    exit 1
  fi
}

function _update_config_path
{
  if [[ -n ${CONTAINER_NAME} ]]
  then
    VOLUME=$(${CRI} inspect "${CONTAINER_NAME}" \
      --format="{{range .Mounts}}{{ println .Source .Destination}}{{end}}" | \
      grep "/tmp/docker-mailserver$" 2>/dev/null || :)
  fi

  if [[ -n ${VOLUME} ]]
  then
    CONFIG_PATH=$(echo "${VOLUME}" | awk '{print $1}')
  fi
}

function _docker_image_exists
{
  ${CRI} history -q "${1}" &>/dev/null
  return ${?}
}

function _docker_image
{
  # start temporary container with specified image
  if ! _docker_image_exists "${IMAGE_NAME}"
  then
    echo "Image '${IMAGE_NAME}' not found. Pulling ..."
    ${CRI} pull "${IMAGE_NAME}"
  fi

  ${CRI} run --rm "${USE_TTY}" \
    -v "${CONFIG_PATH}:/tmp/docker-mailserver${USE_SELINUX}" \
    "${IMAGE_NAME}" "${@:+$@}"
}

function _docker_container
{
  if [[ -n ${CONTAINER_NAME} ]]
  then
    ${CRI} exec "${USE_TTY}" "${CONTAINER_NAME}" "${@:+$@}"
  else
    # if no container is running, run a temporary one:
    # https://github.com/docker-mailserver/docker-mailserver/pull/1874#issuecomment-809781531
    _docker_image "${@:+$@}"
  fi
}

function _main
{
  if command -v docker &>/dev/null
  then
    CRI=docker
  elif command -v podman &>/dev/null
  then
    CRI=podman
    if [[ ${EUID} -ne 0 ]]
    then
      read -r -p "You are now running Podman in rootless mode. Are you sure you want to continue? [Y/n] "
      [[ -n ${REPLY} ]] && [[ ${REPLY} =~ (n|N) ]] && exit 0
    fi
  else
    echo "No supported Container Runtime Interface detected."
    exit 1
  fi

  INFO=$(${CRI} ps --no-trunc --format "{{.Image}};{{.Names}}" --filter \
    label=org.opencontainers.image.title="docker-mailserver" | tail -1)

  IMAGE_NAME=${INFO%;*}
  CONTAINER_NAME=${INFO#*;}

  if [[ -z ${IMAGE_NAME} ]]
  then
    IMAGE_NAME=${NAME:-docker.io/mailserver/docker-mailserver:latest}
  fi

  if test -t 0
  then
    USE_TTY="-ti"
  else
    # GitHub Actions will fail (or really anything else
    #   lacking an interactive tty) if we don't set a
    #   value here; "-t" alone works for these cases.
    USE_TTY="-t"
  fi

  local OPTIND
  while getopts ":c:i:p:zZ" OPT
  do
    case ${OPT} in
      ( i ) IMAGE_NAME="${OPTARG}"       ;;
      ( z | Z ) USE_SELINUX=":${OPTARG}" ;;
      ( c ) CONTAINER_NAME="${OPTARG}"   ;;

      ( p )
        case "${OPTARG}" in
          ( /* ) WISHED_CONFIG_PATH="${OPTARG}"        ;;
          ( *  ) WISHED_CONFIG_PATH="${DIR}/${OPTARG}" ;;
        esac

        if [[ ! -d ${WISHED_CONFIG_PATH} ]]
        then
          echo "Specified directory '${WISHED_CONFIG_PATH}' doesn't exist" >&2
          exit 1
        fi
        ;;

      ( * )
        echo "Invalid option: -${OPT}" >&2
        exit 1
        ;;

    esac
  done

  shift $(( OPTIND - 1 ))

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

  _docker_container setup "${@:+$@}"
  [[ ${1} == 'help' ]] && _show_local_usage

  return 0
}

_main "${@:+$@}"
