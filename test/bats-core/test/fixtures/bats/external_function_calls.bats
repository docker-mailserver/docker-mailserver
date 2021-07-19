load test_helper

# Test various combinations that may fail line number detection in stack trace
# Tests are designed so the first statement succeeds and 2nd fails
# All tests fail on the same line so checking can be automated

@test "Call true function && false" {
    help_me
    help_me && false
}

@test "Call true function && return 1" {
    help_me
    help_me && return 1
}

@test "Call true function and invert" {
    help_me
    ! help_me
}

@test "Call false function || false" {
    ! failing_helper
    failing_helper || false
}

@test "Call false function && return 1" {
    ! failing_helper
    failing_helper || return 1
}

@test "Call false function" {
    ! failing_helper
    failing_helper
}

@test "Call return_0 function && false" {
    return_0
    return_0 && false
}

@test "Call return_0 function && return 1" {
    return_0
    return_0 && return 1
}

@test "Call return_0 function and invert" {
    return_0
    ! return_0
}

@test "Call return_1 function || false" {
    ! return_1
    return_1 || false
}

@test "Call return_1 function && return 1" {
    ! return_1
    return_1 || return 1
}

@test "Call return_1 function" {
    ! return_1
    return_1
}
