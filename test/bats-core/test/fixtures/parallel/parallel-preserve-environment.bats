setup_file() {
    export OTHER_ENV_VARIABLE='my-value'
}

@test "check env variables are set" {
    [[ "$TEST_ENV_VARIABLE" == "test-value" ]]
    [[ "$OTHER_ENV_VARIABLE" == "my-value" ]]
}