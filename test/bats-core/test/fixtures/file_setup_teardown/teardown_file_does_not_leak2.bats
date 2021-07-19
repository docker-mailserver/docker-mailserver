@test "must not see variable from first run" {
    [[ -z "$POTENTIALLY_LEAKING_VARIABLE" ]]
}