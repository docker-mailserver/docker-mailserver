load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

NAME=tvial/docker-mailserver:testing

# default timeout is 120 seconds
TEST_TIMEOUT_IN_SECONDS=${TEST_TIMEOUT_IN_SECONDS-120}
NUMBER_OF_LOG_LINES=${NUMBER_OF_LOG_LINES-10}

function repeat_until_success_or_timeout {
    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "First parameter for timeout must be an integer, recieved \"$1\""
        return 1
    fi
    TIMEOUT=$1
    STARTTIME=$SECONDS
    shift 1
    until "$@"
    do
        sleep 5
        if [[ $(($SECONDS - $STARTTIME )) -gt $TIMEOUT ]]; then
            echo "Timed out on command: $@"
            return 1
        fi
    done
}

# @param $1 port
# @param $2 container name
function wait_for_tcp_port_in_container() {
    repeat_until_success_or_timeout $TEST_TIMEOUT_IN_SECONDS docker exec $2 /bin/sh -c "nc -z 0.0.0.0 $1"
}

# @param $1 name of the postfix container
function wait_for_smtp_port_in_container() {
    wait_for_tcp_port_in_container 25 $1
}

# @param $1 name of the postfix container
function wait_for_amavis_port_in_container() {
    wait_for_tcp_port_in_container 10024 $1
}

# @param $1 name of the postfix container
function wait_for_finished_setup_in_container() {
    local status=0
    repeat_until_success_or_timeout $TEST_TIMEOUT_IN_SECONDS sh -c "docker logs $1 | grep 'is up and running'" || status=1
    if [[ $status -eq 1 ]]; then
        echo "Last $NUMBER_OF_LOG_LINES lines of container \`$1\`'s log"
        docker logs $1 | tail -n $NUMBER_OF_LOG_LINES
    fi
    return $status
}

SETUP_FILE_MARKER="$BATS_TMPDIR/`basename \"$BATS_TEST_FILENAME\"`.setup_file"

# use in setup() in conjunction with a `@test "first" {}` to trigger setup_file reliably
function run_setup_file_if_necessary() {
    if [ "$BATS_TEST_NAME" == 'test_first' ]; then
        # prevent old markers from marking success or get an error if we cannot remove due to permissions
        rm -f "$SETUP_FILE_MARKER"

        setup_file

        touch "$SETUP_FILE_MARKER"
    else
        if [ ! -f "$SETUP_FILE_MARKER" ]; then
            skip "setup_file failed"
            return 1
        fi
    fi
}

# use in teardown() in conjunction with a `@test "last" {}` to trigger teardown_file reliably
function run_teardown_file_if_necessary() {
    if [ "$BATS_TEST_NAME" == 'test_last' ]; then
        # cleanup setup file marker
        rm -f "$SETUP_FILE_MARKER"
        teardown_file
    fi
}
