#!/usr/bin/env bats

setup() {
    echo "# setup stdout"
    echo "# setup FD3" >&3
}

teardown() {
    echo "# teardown stdout" 
    echo "# teardown FD3" >&3
}

@test "say hello to Biblo" {
    echo "# hello stdout"
    echo "# hello Bilbo" >&3
}

@test "fail to say hello to Biblo" {
    echo "# hello stdout"
    echo "# hello Bilbo" >&3
    false
}