#!/usr/bin/env bats

load test_helper
fixtures parallel

setup() {
  type -p parallel &>/dev/null || skip "--jobs requires GNU parallel"
}

check_parallel_tests() { # <expected maximum parallelity>
  local expected_maximum_parallelity="$1"
  local expected_number_of_lines="${2:-$((2 * expected_maximum_parallelity))}"

  max_parallel_tests=0
  started_tests=0
  read_lines=0
  while IFS= read -r line; do
    (( ++read_lines ))
    case "$line" in
      "start "*)
        if (( ++started_tests > max_parallel_tests )); then
          max_parallel_tests="$started_tests"
        fi
      ;;
      "stop "*)
        (( started_tests-- ))
      ;;
    esac
  done <"$FILE_MARKER"

  echo "max_parallel_tests: $max_parallel_tests"
  [[ $max_parallel_tests -eq $expected_maximum_parallelity ]]

  echo "read_lines: $read_lines"
  [[ $read_lines -eq $expected_number_of_lines ]]
}

@test "parallel test execution with --jobs" {
  export FILE_MARKER=$(mktemp)
  
  export PARALLELITY=3
  run bats --jobs $PARALLELITY "$FIXTURE_ROOT/parallel.bats"
  
  [ "$status" -eq 0 ]
  # Make sure the lines are in-order.
  [[ "${lines[0]}" == "1..3" ]]
  for t in {1..3}; do
    [[ "${lines[$t]}" == "ok $t slow test $t" ]]
  done

  check_parallel_tests $PARALLELITY
}

@test "parallel can preserve environment variables" {
  export TEST_ENV_VARIABLE='test-value'
  run bats --jobs 2 "$FIXTURE_ROOT/parallel-preserve-environment.bats"
  echo "$output"
  [[ "$status" -eq 0 ]]
}

@test "parallel suite execution with --jobs" {
  export FILE_MARKER=$(mktemp)
  export PARALLELITY=12

  # file parallelization is needed for maximum parallelity!
  # If we got over the skip (if no GNU parallel) in setup() we can reenable it safely!
  unset BATS_NO_PARALLELIZE_ACROSS_FILES 
  run bash -c "bats --jobs $PARALLELITY \"${FIXTURE_ROOT}/suite/\" 2> >(grep -v '^parallel: Warning: ')"

  echo "$output"
  [ "$status" -eq 0 ]

  # Make sure the lines are in-order.
  [[ "${lines[0]}" == "1..$PARALLELITY" ]]
  i=0
  for s in {1..4}; do
    for t in {1..3}; do
      ((++i))
      [[ "${lines[$i]}" == "ok $i slow test $t" ]]
    done
  done

  check_parallel_tests $PARALLELITY
}

@test "setup_file is not over parallelized" {
  export FILE_MARKER=$(mktemp)
  export PARALLELITY=2

  # file parallelization is needed for this test!
  # If we got over the skip (if no GNU parallel) in setup() we can reenable it safely!
  unset BATS_NO_PARALLELIZE_ACROSS_FILES 
  # run 4 files with parallelity of 2 -> serialize 2
  run bats --jobs $PARALLELITY "$FIXTURE_ROOT/setup_file"

  [[ $status -eq 0 ]] || (echo "$output"; false)

  cat "$FILE_MARKER"

  [[ $(grep -c "start " "$FILE_MARKER") -eq 4 ]] # beware of grepping the filename as well!
  [[ $(grep -c "stop " "$FILE_MARKER") -eq 4 ]]

  check_parallel_tests $PARALLELITY 8
}

@test "running the same file twice runs its tests twice without errors" {
  run bats --jobs 2 "$FIXTURE_ROOT/../bats/passing.bats" "$FIXTURE_ROOT/../bats/passing.bats"
  echo "$output"
  [[ $status -eq 0 ]]
  [[ "${lines[0]}" == "1..2" ]] # got 2x1 tests
  [[ "${lines[1]}" == "ok 1 "* ]]
  [[ "${lines[2]}" == "ok 2 "* ]]
  [[ "${#lines[@]}" -eq 3 ]]
}

@test "parallelity factor is met exactly" {
  parallelity=5 # run the 10 tests in 2 batches with 5 test each
  bats --jobs $parallelity "$FIXTURE_ROOT/parallel_factor.bats" & # run in background to avoid blocking
  # give it some time to start the tests
  sleep 2
  # find how many semaphores are started in parallel; don't count grep itself
  run bash -c "ps -ef | grep bats-exec-test | grep parallel/parallel_factor.bats | grep -v grep"
  echo "$output"
  
  # This might fail spuriously if we got bad luck with the scheduler
  # and hit the transition between the first and second batch of tests.
  [[ "${#lines[@]}" -eq $parallelity  ]]
}

@test "parallel mode correctly forwards failure return code" {
  run bats --jobs 2 "$FIXTURE_ROOT/../bats/failing.bats"
  [[ "$status" -eq 1 ]]
}

@test "--no-parallelize-across-files test file detects parallel execution" {
  # ensure that we really run parallelization across files!
  # (setup should have skipped already, if there was no GNU parallel)
  unset BATS_NO_PARALLELIZE_ACROSS_FILES
  export FILE_MARKER=$(mktemp)
  ! bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_across_files/"
}

@test "--no-parallelize-across-files prevents parallelization across files" {
  export FILE_MARKER=$(mktemp)
  bats --jobs 2 --no-parallelize-across-files "$FIXTURE_ROOT/must_not_parallelize_across_files/"
}

@test "--no-parallelize-across-files does not prevent parallelization within files" {
  ! bats --jobs 2 --no-parallelize-across-files "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "--no-parallelize-within-files test file detects parallel execution" {
  ! bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "--no-parallelize-within-files prevents parallelization within files" {
  bats --jobs 2 --no-parallelize-within-files "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "--no-parallelize-within-files does not prevent parallelization across files" {
  # ensure that we really run parallelization across files!
  # (setup should have skipped already, if there was no GNU parallel)
  unset BATS_NO_PARALLELIZE_ACROSS_FILES
  export FILE_MARKER=$(mktemp)
  ! bats --jobs 2 --no-parallelize-within-files "$FIXTURE_ROOT/must_not_parallelize_across_files/"
}

@test "BATS_NO_PARALLELIZE_WITHIN_FILE works from inside setup_file()" {
  DISABLE_IN_SETUP_FILE_FUNCTION=1 bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "BATS_NO_PARALLELIZE_WITHIN_FILE works from outside all functions" {
  DISABLE_OUTSIDE_ALL_FUNCTIONS=1 bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "BATS_NO_PARALLELIZE_WITHIN_FILE does not work from inside setup()" {
  ! DISABLE_IN_SETUP_FUNCTION=1 bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}

@test "BATS_NO_PARALLELIZE_WITHIN_FILE does not work from inside test function" {
  ! DISABLE_IN_TEST_FUNCTION=1 bats --jobs 2 "$FIXTURE_ROOT/must_not_parallelize_within_file.bats"
}