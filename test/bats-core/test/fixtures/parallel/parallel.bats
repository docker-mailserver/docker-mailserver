setup() {
  load 'helper'
  echo "start $BATS_TEST_NAME $BATS_TEST_FILENAME" >> "$FILE_MARKER"
}

teardown() {
  echo "stop $BATS_TEST_NAME $BATS_TEST_FILENAME" >> "$FILE_MARKER"
}

@test "slow test 1" {
  single-use-barrier "parallel" $PARALLELITY
}

@test "slow test 2" {
  single-use-barrier "parallel" $PARALLELITY
}

@test "slow test 3" {
  single-use-barrier "parallel" $PARALLELITY
}