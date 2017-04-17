#! /bin/sh

##
# Wrapper for various setup scripts included in the docker-mailserver
#

INFO=$(docker ps \
  --no-trunc \
  --format="{{.Image}}\t{{.Names}}\t{{.Command}}" | \
  grep '/bin/sh -c /usr/local/bin/start-mailserver.sh')

IMAGE_NAME=$(echo $INFO | awk '{print $1}')
CONTAINER_NAME=$(echo $INFO | awk '{print $2}')

if [ -z "$IMAGE_NAME" ]; then
  IMAGE_NAME=tvial/docker-mailserver:latest
fi

_inspect() {
  if _docker_image_exists "$IMAGE_NAME"; then
    echo "Image: $IMAGE_NAME"
  else
    echo "Image: '$IMAGE_NAME' can’t be found."
  fi
  if [ -n "$CONTAINER_NAME" ]; then
    echo "Container: $CONTAINER_NAME"
  else
    echo "Container: Not running, please start docker-mailserver."
  fi
}

_usage() {
  echo "Usage: $0 [-i IMAGE_NAME] [-c CONTAINER_NAME] <subcommand> <subcommand> [args]

OPTIONS:

  -i IMAGE_NAME     The name of the docker-mailserver image, by default
                    'tvial/docker-mailserver:latest'.
  -c CONTAINER_NAME The name of the running container.

SUBCOMMANDS:

  email:

    $0 email add <email> <password>
    $0 email update <email> <password>
    $0 email del <email>
    $0 email list

  alias:
    $0 alias add <email> <recipient>
    $0 alias del <email> <recipient>
    $0 alias list

  config:

    $0 config dkim
    $0 config ssl

  debug:

    $0 debug fetchmail
    $0 debug show-mail-logs
    $0 debug inspect
    $0 debug login <commands>
"
  exit 1
}

_docker_image_exists() {
  if docker history -q "$1" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

_docker_image() {
  if ! _docker_image_exists "$IMAGE_NAME"; then
    echo "Image '$IMAGE_NAME' not found. Pulling ..."
    docker pull "$IMAGE_NAME"
  fi
    docker run \
      --rm \
      -v "$(pwd)/config":/tmp/docker-mailserver \
      -ti "$IMAGE_NAME" $@
}

_docker_container() {
  if [ -n "$CONTAINER_NAME" ]; then
    docker exec -ti "$CONTAINER_NAME" $@
  else
    echo "The docker-mailserver is not running!"
    exit 1
  fi
}

while getopts ":c:i:" OPT; do
  case $OPT in
    c)
      CONTAINER_NAME="$OPTARG"
      ;;
    i)
      IMAGE_NAME="$OPTARG"
      ;;
   \?)
     echo "Invalid option: -$OPTARG" >&2
     ;;
  esac
done

shift $((OPTIND-1))

case $1 in

  email)
    shift
    case $1 in

      add)
        shift
        _docker_image addmailuser $@
        ;;
      update)
        shift
        _docker_image updatemailuser $@
        ;;
      del)
        shift
        _docker_image delmailuser $@
        ;;
      list)
        _docker_image listmailuser
        ;;
      *)
        _usage
        ;;
    esac
    ;;

  alias)
    shift
    case $1 in
        add)
          shift
          _docker_image addalias $@
          ;;
        del)
          shift
          _docker_image delalias $@
          ;;
        list)
          shift
          _docker_image listalias $@
          ;;
        *)
          _usage
          ;;
    esac
    ;;

  config)
    shift
    case $1 in
      dkim)
        _docker_image generate-dkim-config
        ;;
      ssl)
        _docker_image generate-ssl-certificate
        ;;
      *)
        _usage
        ;;
    esac
    ;;

  debug)
    shift
    case $1 in
      fetchmail)
        _docker_image debug-fetchmail
        ;;
      show-mail-logs)
        _docker_container cat /var/log/mail/mail.log
        ;;
      inspect)
        _inspect
        ;;
      login)
        shift
	if [ -z "$1" ]; then
          _docker_container /bin/bash
        else
          _docker_container /bin/bash -c "$@"
        fi
        ;;
      *)
        _usage
        ;;
    esac
    ;;

  *)
    _usage
    ;;
esac
