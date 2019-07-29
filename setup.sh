#! /bin/sh

##
# Wrapper for various setup scripts included in the docker-mailserver
#

INFO=$(docker ps \
  --no-trunc \
  --format="{{.Image}}\t{{.Names}}\t{{.Command}}" | \
  grep "supervisord -c /etc/supervisor/supervisord.conf")

IMAGE_NAME=$(echo $INFO | awk '{print $1}')
CONTAINER_NAME=$(echo $INFO | awk '{print $2}')
DEFAULT_CONFIG_PATH="$(pwd)/config"

_update_config_path() {
  VOLUME=$(docker inspect $CONTAINER_NAME \
    --format="{{range .Mounts}}{{ println .Source .Destination}}{{end}}" | \
    grep "/tmp/docker-mailserver$" 2>/dev/null)

  if [ ! -z "$VOLUME" ]; then
    CONFIG_PATH=$(echo $VOLUME | awk '{print $1}')
  fi
}

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
    echo "Config mount: $CONFIG_PATH"
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

  -p PATH           config folder path (default: $(pwd)/config)

SUBCOMMANDS:

  email:

    $0 email add <email> [<password>]
    $0 email update <email> [<password>]
    $0 email del <email>
    $0 email restrict <add|del|list> <send|receive> [<email>]
    $0 email list

  alias:
    $0 alias add <email> <recipient>
    $0 alias del <email> <recipient>
    $0 alias list

  config:

    $0 config dkim <keysize> (default: 2048)
    $0 config ssl <fqdn>

  relay:

    $0 relay add-domain <domain> <host> [<port>]
    $0 relay add-auth <domain> <username> [<password>]
    $0 relay exclude-domain <domain>

  debug:

    $0 debug fetchmail
    $0 debug fail2ban [<unban> <ip-address>]
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
      -v "$CONFIG_PATH":/tmp/docker-mailserver \
      -ti "$IMAGE_NAME" $@
}

_docker_container() {
  if [ -n "$CONTAINER_NAME" ]; then
    docker exec -ti "$CONTAINER_NAME" "$@"
  else
    echo "The docker-mailserver is not running!"
    exit 1
  fi
}

while getopts ":c:i:p:" OPT; do
  case $OPT in
    c)
      CONTAINER_NAME="$OPTARG"
      ;;
    i)
      IMAGE_NAME="$OPTARG"
      ;;
    p)
      case "$OPTARG" in
      /*)
          WISHED_CONFIG_PATH="$OPTARG"
          ;;
      *)
          WISHED_CONFIG_PATH="$(pwd)/$OPTARG"
          ;;
      esac
      if [ ! -d "$WISHED_CONFIG_PATH" ]; then
        echo "Directory doesn't exist"
        _usage
        exit 1
      fi
      ;;
   \?)
     echo "Invalid option: -$OPTARG" >&2
     ;;
  esac
done

if [ ! -n "$WISHED_CONFIG_PATH" ]; then
  # no wished config path
  _update_config_path

  if [ ! -n "$CONFIG_PATH" ]; then
    CONFIG_PATH=$DEFAULT_CONFIG_PATH
  fi
else
  CONFIG_PATH=$WISHED_CONFIG_PATH
fi

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
      restrict)
        shift
        _docker_container restrict-access $@
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
        _docker_image generate-dkim-config $2
        ;;
      ssl)
        _docker_image generate-ssl-certificate "$2"
        ;;
      *)
        _usage
        ;;
    esac
    ;;

  relay)
    shift
    case $1 in
      add-domain)
        shift
        _docker_image addrelayhost $@
        ;;
      add-auth)
        shift
        _docker_image addsaslpassword $@
        ;;
      exclude-domain)
        shift
        _docker_image excluderelaydomain $@
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
      fail2ban)
        shift
        _docker_container fail2ban $@
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
