load 'test_helper/common'

function setup() {
    CONTAINER=$(docker run -d \
		-v "`pwd`/test/config":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e DMS_DEBUG=0 \
		-h mail.my-domain.com -t ${NAME})
    # using postfix availability as start indicator, this might be insufficient for postgrey
    wait_for_smtp_port_in_container $CONTAINER
}

function teardown() {
    docker rm -f $CONTAINER
}

@test "checking process: postgrey (disabled in default configuration)" {
  run docker exec $CONTAINER /bin/bash -c "ps aux --forest | grep -v grep | grep 'postgrey'"
  assert_failure
}