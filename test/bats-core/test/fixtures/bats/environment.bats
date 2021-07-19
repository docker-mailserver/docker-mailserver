@test "setting a variable" {
  variable=1
  [ $variable -eq 1 ]
}

@test "variables do not persist across tests" {
  [ -z "$variable" ]
}
