#! /bin/bash

# version   v0.2.5 stable
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
  # shellcheck disable=SC2059
  printf "\e[35mSETUP\e[31m(\e[93m1\e[31m)

\e[38;5;214mNAME\e[39m
    ${SCRIPT:-${0}} - docker-mailserver administration script

\e[38;5;214mSYNOPSIS\e[39m
    ./${SCRIPT:-${0}} [ OPTIONS\e[31m...\e[39m ] COMMAND [ help \e[31m|\e[39m ARGUMENTS\e[31m...\e[39m ]

    COMMAND \e[31m:=\e[39m { email \e[31m|\e[39m alias \e[31m|\e[39m quota \e[31m|\e[39m config \e[31m|\e[39m relay \e[31m|\e[39m debug } SUBCOMMAND

\e[38;5;214mDESCRIPTION\e[39m
    This is the main administration script that you use for all interactions with your
    mail server. Setup, configuration and much more is done with this script.

    Please note that the script executes most of the commands inside the container itself.
    If the image was not found, this script will pull the \e[37m:latest\e[39m tag of
    \e[37mmailserver/docker-mailserver\e[39m. This tag refers to the latest release,
    see the tagging convention in the README under
    \e[34mhttps://github.com/docker-mailserver/docker-mailserver/blob/master/README.md\e[39m

    You will be able to see detailed information about the script you're invoking and
    its arguments by appending \e[37mhelp\e[39m after your command. Currently, this
    does not work with all scripts.

\e[38;5;214mOPTIONS\e[39m
    \e[94mConfig path, container or image adjustments\e[39m
        -i IMAGE_NAME
            Provides the name of the docker-mailserver image. The default value is
            \e[37mdocker.io/mailserver/docker-mailserver:latest\e[39m

        -c CONTAINER_NAME
            Provides the name of the running container.

        -p PATH
            Provides the config folder path. The default is
            \e[37m${CDIR}/config/\e[39m

    \e[94mSELinux\e[39m
        -z
            Allows container access to the bind mount content that is shared among
            multiple containers on a SELinux-enabled host.

        -Z
            Allows container access to the bind mount content that is private and
            unshared with other containers on a SELinux-enabled host.

    \e[94mOthers\e[39m
        -h \e[31m|\e[39m help
            Shows this help dialogue.

\e[31m[\e[38;5;214mSUB\e[31m]\e[38;5;214mCOMMANDS\e[39m
    \e[94mCOMMAND\e[39m email \e[31m:=\e[39m
        ${0} email add <EMAIL ADDRESS> [<PASSWORD>]
        ${0} email update <EMAIL ADDRESS> [<PASSWORD>]
        ${0} email del [ OPTIONS\e[31m...\e[39m ] <EMAIL ADDRESS>
        ${0} email restrict <add\e[31m|\e[39mdel\e[31m|\e[39mlist> <send\e[31m|\e[39mreceive> [<EMAIL ADDRESS>]
        ${0} email list

    \e[94mCOMMAND\e[39m alias \e[31m:=\e[39m
        ${0} alias add <EMAIL ADDRESS> <RECIPIENT>
        ${0} alias del <EMAIL ADDRESS> <RECIPIENT>
        ${0} alias list

    \e[94mCOMMAND\e[39m quota \e[31m:=\e[39m
        ${0} quota set <EMAIL ADDRESS> [<QUOTA>]
        ${0} quota del <EMAIL ADDRESS>

    \e[94mCOMMAND\e[39m config \e[31m:=\e[39m
        ${0} config dkim [ ARGUMENTS\e[31m...\e[39m ]
        ${0} config ssl <FQDN> (\e[96mATTENTION\e[39m: This is deprecated and will be removed soon.)

    \e[94mCOMMAND\e[39m relay \e[31m:=\e[39m
        ${0} relay add-domain <DOMAIN> <HOST> [<PORT>]
        ${0} relay add-auth <DOMAIN> <USERNAME> [<PASSWORD>]
        ${0} relay exclude-domain <DOMAIN>

    \e[94mCOMMAND\e[39m debug \e[31m:=\e[39m
        ${0} debug fetchmail
        ${0} debug fail2ban [unban <IP>]
        ${0} debug show-mail-logs
        ${0} debug inspect
        ${0} debug login <COMMANDS>

\e[38;5;214mEXAMPLES\e[39m
    \e[37m./setup.sh email add test@domain.tld\e[39m
        Add the email account \e[37mtest@domain.tld\e[39m. You will be prompted
        to input a password afterwards since no password was supplied.

    \e[37m./setup.sh config dkim size 2048 domain 'whoami.com,whoareyou.org'\e[39m
        Creates keys of length 2048 but in an LDAP setup where domains are not known to
        Postfix by default, so you need to provide them yourself in a comma-separated list.

    \e[37m./setup.sh config dkim help\e[39m
        This will provide you with a detailed explanation on how to use the \e[37m
        config dkim\e[39m command, showing what arguments can be passed and what they do.

\e[38;5;214mEXIT STATUS\e[39m
    Exit status is 0 if the command was successful. If there was an unexpected error, an error
    message is shown describing the error. In case of an error, the script will exit with exit
    status 1.

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
      -v "${CONFIG_PATH}:/tmp/docker-mailserver${USING_SELINUX}" \
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

    email )
      case ${2:-} in
        add      ) shift 2 ; _docker_image addmailuser "${@}" ;;
        update   ) shift 2 ; _docker_image updatemailuser "${@}" ;;
        del      ) shift 2 ; _docker_image delmailuser "${@}" ;;
        restrict ) shift 2 ; _docker_container restrict-access "${@}" ;;
        list     ) _docker_image listmailuser ;;
        *        ) _usage ;;
      esac
      ;;

    alias )
      case ${2:-} in
        add      ) shift 2 ; _docker_image addalias "${1}" "${2}" ;;
        del      ) shift 2 ; _docker_image delalias "${1}" "${2}" ;;
        list     ) shift 2 ; _docker_image listalias ;;
        *        ) _usage ;;
      esac
      ;;

    quota )
      shift ; case ${1:-} in
        set      ) shift ; _docker_image setquota "${@}" ;;
        del      ) shift ; _docker_image delquota "${@}" ;;
        *        ) _usage ;;
      esac
      ;;

    config )
      case ${2:-} in
        dkim     ) shift 2 ; _docker_image open-dkim "${@}" ;;
        ssl      ) shift 2 ; _docker_image generate-ssl-certificate "${1}" ;;
        *        ) _usage ;;
      esac
      ;;

    relay )
      case ${2:-} in
        add-domain     ) shift 2 ; _docker_image addrelayhost "${@}" ;;
        add-auth       ) shift 2 ; _docker_image addsaslpassword "${@}" ;;
        exclude-domain ) shift 2 ; _docker_image excluderelaydomain "${@}" ;;
        *              ) _usage ;;
      esac
      ;;

    debug )
      case ${2:-} in
        fetchmail      ) _docker_image debug-fetchmail ;;
        fail2ban       ) shift 2 ; _docker_container fail2ban "${@}" ;;
        show-mail-logs ) _docker_container cat /var/log/mail/mail.log ;;
        inspect        ) _inspect ;;
        login          )
          shift 2
          if [[ -z ${1:-} ]]
          then
            _docker_container /bin/bash
          else
            _docker_container /bin/bash -c "${@}"
          fi
          ;;
        * ) _usage ; exit 1 ;;
      esac
      ;;

    help ) _usage ;;
    *    ) _usage ; exit 1 ;;
  esac
}

_main "${@}"
