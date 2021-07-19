set -u

# This file is used to test line number offsets. Any changes to lines will affect tests

@test "access unbound variable" {
    unset unset_variable
    # Add a line for checking line number
    foo=$unset_variable
}

@test "access second unbound variable" {
    unset second_unset_variable
    foo=$second_unset_variable
}
