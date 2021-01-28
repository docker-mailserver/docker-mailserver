#! /bin/bash

# version   v0.2.4 stable
# executed  manually (via Make)
# task      wrapper for various setup scripts

SCRIPT='setup.sh'

set -euEo pipefail
trap '__log_err ${FUNCNAME[0]:-"?"} ${BASH_COMMAND:-"?"} ${LINENO:-"?"} ${?:-"?"}' ERR
trap '_unset_vars || :' EXIT

function __log_err
{
  printf "\n––– \e[1m\e[31mUNCHECKED ERROR\e[0m\n%s\n%s\n%s\n%s\n\n" \
    "  – script    = ${SCRIPT:-${0}}" \
    "  – function  = ${1} / ${2}" \
    "  – line      = ${3}" \
    "  – exit code = ${4}" >&2
}

function _unset_vars
{
  unset CDIR CRI INFO IMAGE_NAME CONTAINER_NAME DEFAULT_CONFIG_PATH
  unset USE_CONTAINER WISHED_CONFIG_PATH CONFIG_PATH VOLUME USE_TTY
  unset SCRIPT USING_SELINUX
}

function _get_current_directory
{
  if dirname "$(readlink -f "${0}")" &>/dev/null
  then
    CDIR="$(dirname "$(readlink -f "${0}")")"
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
CONTAINER_NAME=
DEFAULT_CONFIG_PATH="${CDIR}/config"
USE_CONTAINER=false
WISHED_CONFIG_PATH=
CONFIG_PATH=
VOLUME=
USE_TTY=
USING_SELINUX=

function _check_root
{
  if [[ ${EUID} -ne 0 ]]
  then
    echo "Curently docker-mailserver doesn't support podman's rootless mode, please run this script as root user."
    exit 1
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
  echo "${SCRIPT:-${0}} Bootstrapping Script

Usage: ${0} [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]

OPTIONS:

  -i IMAGE_NAME     The name of the docker-mailserver image
                    The default value is
                    'docker.io/mailserver/docker-mailserver:latest'

  -c CONTAINER_NAME The name of the running container.

  -p PATH           Config folder path (default: ${CDIR}/config)

  -h                Show this help dialogue

  -z                Allow container access to the bind mount content
                    that is shared among multiple containers
                    on a SELinux-enabled host.

  -Z                Allow container access to the bind mount content
                    that is private and unshared with other containers
                    on a SELinux-enabled host.

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

    ${0} config dkim <keysize> (default: 4096) <domain> (optional - for LDAP systems)
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
  ${CRI} history -q "${1}" &>/dev/null
  return ${?}
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
      -v "${CONFIG_PATH}":/tmp/docker-mailserver"${USING_SELINUX}" \
      "${USE_TTY}" "${IMAGE_NAME}" "${@}"
  fi
}

function _docker_container
{
  if [[ -n ${CONTAINER_NAME} ]]
  then
    ${CRI} exec "${USE_TTY}" "${CONTAINER_NAME}" "${@}"
  else
    echo "The mailserver is not running!"
    exit 1
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
    _check_root
  else
    echo "No supported Container Runtime Interface detected."
    exit 10
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
  while getopts ":c:i:p:hzZ" OPT
  do
    case ${OPT} in
      i ) IMAGE_NAME="${OPTARG}" ;;
      z ) USING_SELINUX=":z"     ;;
      Z ) USING_SELINUX=":Z"     ;;
      c )
        # container specified, connect to running instance
        CONTAINER_NAME="${OPTARG}"
        USE_CONTAINER=true
        ;;

      h )
        _usage
        return
        ;;

      p )
        case "${OPTARG}" in
          /* ) WISHED_CONFIG_PATH="${OPTARG}"         ;;
          *  ) WISHED_CONFIG_PATH="${CDIR}/${OPTARG}" ;;
        esac

        if [[ ! -d ${WISHED_CONFIG_PATH} ]]
        then
          echo "Directory doesn't exist"
          _usage
          exit 40
        fi
        ;;

      * )
        echo "Invalid option: -${OPTARG}" >&2
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
        *        ) _usage ;;
      esac
      ;;

    config)
      shift ; case ${1:-} in
        dkim     ) _docker_image generate-dkim-config "${2:-4096}" "${3:-}" ;;
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
        *        ) _usage ; exit 1 ;;
      esac
      ;;

    help ) _usage ;;
    *    ) _usage ; exit 1 ;;
  esac
}

_main "${@}"
