load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

NAME=tvial/docker-mailserver:testing

# default timeout is 60 seconds
TEST_TIMEOUT_IN_SECONDS=${TIMEOUT-60}

function repeat_until_success_or_timeout {
    if ![[ "$1" ~= '^[0-9]+$' ]]; then
        echo "First parameter for timeout must be an integer, recieved \"$1\""
        exit 1
    fi
    TIMEOUT=$1
    STARTTIME=$SECONDS
    shift 1
    until "$@"
    do
        sleep 5
        if [[ $(($SECONDS - $STARTTIME )) -gt $TIMEOUT ]]; then
            echo "Timed out on command: $@"
            exit 1
        fi
    done
}

# @param $1 name of the postfix container
function wait_for_smtp_port_in_container() {
    repeat_until_success_or_timeout $TEST_TIMEOUT_IN_SECONDS docker exec $1 /bin/sh -c "nc -z 0.0.0.0 25"
}

# @param $1 name of the postfix container
function wait_for_finished_setup_in_container() {
    repeat_until_success_or_timeout $TEST_TIMEOUT_IN_SECONDS sh -c "docker logs $1 | grep 'Starting mail server'"
}