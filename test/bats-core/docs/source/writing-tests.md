# Writing tests

Each Bats test file is evaluated _n+1_ times, where _n_ is the number of
test cases in the file. The first run counts the number of test cases,
then iterates over the test cases and executes each one in its own
process.

For more details about how Bats evaluates test files, see [Bats Evaluation
Process][bats-eval] on the wiki.

For sample test files, see [examples](https://github.com/bats-core/bats-core/tree/master/docs/examples).

[bats-eval]: https://github.com/bats-core/bats-core/wiki/Bats-Evaluation-Process

## `run`: Test other commands

Many Bats tests need to run a command and then make assertions about its exit
status and output. Bats includes a `run` helper that invokes its arguments as a
command, saves the exit status and output into special global variables, and
then returns with a `0` status code so you can continue to make assertions in
your test case.

For example, let's say you're testing that the `foo` command, when passed a
nonexistent filename, exits with a `1` status code and prints an error message.

```bash
@test "invoking foo with a nonexistent file prints an error" {
  run foo nonexistent_filename
  [ "$status" -eq 1 ]
  [ "$output" = "foo: no such file 'nonexistent_filename'" ]
}
```

The `$status` variable contains the status code of the command, and the
`$output` variable contains the combined contents of the command's standard
output and standard error streams.

A third special variable, the `$lines` array, is available for easily accessing
individual lines of output. For example, if you want to test that invoking `foo`
without any arguments prints usage information on the first line:

```bash
@test "invoking foo without arguments prints usage" {
  run foo
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "usage: foo <filename>" ]
}
```

__Note:__ The `run` helper executes its argument(s) in a subshell, so if
writing tests against environmental side-effects like a variable's value
being changed, these changes will not persist after `run` completes.

### When not to use `run`

In some cases, using `run` is redundant and results in a longer and less readable code.
Here are a few examples.

#### 1. In case you only need to check the command succeeded, it is better to not use run, since

```bash
run command args ...
echo "$output"
[ "$status" -eq 0 ]
```

is equivalent to

```bash
command args ...
```

since bats sets `set -e` for all tests.

#### 2. In case you want to hide the command output (which `run` does), use output redirection instead

This

```bash
run command ...
[ "$status" -eq 0 ]
```

is equivalent to

```bash
command ... >/dev/null
```

Note that the output is only shown if the test case fails.

#### 3. In case you need to assign command output to a variable (and maybe check the command exit status), it is better to not use run, since

```bash
run command args ...
[ "$status" -eq 0 ]
var="$output"
```

is equivalent to

```bash
var=$(command args ...)
```

#### Comment syntax

External tools (like `shellcheck`, `shfmt`, and various IDE's) may not support
the standard `.bats` syntax.  Because of this, we provide a valid `bash`
alterntative:

```bash
function invoking_foo_without_arguments_prints_usage { #@test
  run foo
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "usage: foo <filename>" ]
}
```

When using this syntax, the function name will be the title in the result output
and the value checked when using `--filter`.

### `load`: Share common code

You may want to share common code across multiple test files. Bats includes a
convenient `load` command for sourcing a Bash source file relative to the
location of the current test file. For example, if you have a Bats test in
`test/foo.bats`, the command

```bash
load test_helper.bash
```

will source the script `test/test_helper.bash` in your test file (limitations
apply, see below). This can be useful for sharing functions to set up your
environment or load fixtures. `load` delegates to Bash's `source` command after
resolving relative paths.

As pointed out by @iatrou in <https://www.tldp.org/LDP/abs/html/declareref.html>,
using the `declare` builtin restricts scope of a variable. Thus, since actual
`source`-ing is performed in context of the `load` function, `declare`d symbols
will _not_ be made available to callers of `load`.

> For backwards compatibility `load` first searches for a file ending in
> `.bash` (e.g. `load test_helper` searches for `test_helper.bash` before
> it looks for `test_helper`). This behaviour is deprecated and subject to
> change, please use exact filenames instead.

### `skip`: Easily skip tests

Tests can be skipped by using the `skip` command at the point in a test you wish
to skip.

```bash
@test "A test I don't want to execute for now" {
  skip
  run foo
  [ "$status" -eq 0 ]
}
```

Optionally, you may include a reason for skipping:

```bash
@test "A test I don't want to execute for now" {
  skip "This command will return zero soon, but not now"
  run foo
  [ "$status" -eq 0 ]
}
```

Or you can skip conditionally:

```bash
@test "A test which should run" {
  if [ foo != bar ]; then
    skip "foo isn't bar"
  fi

  run foo
  [ "$status" -eq 0 ]
}
```

__Note:__ `setup` and `teardown` hooks still run for skipped tests.

### `setup` and `teardown`: Pre- and post-test hooks

You can define special `setup` and `teardown` functions, which run before and
after each test case, respectively. Use these to load fixtures, set up your
environment, and clean up when you're done.

You can also define `setup_file` and `teardown_file`, which will run once before the first test's `setup` and after the last test's `teardown` for the containing file. Variables that are exported in `setup_file` will be visible to all following functions (`setup`, the test itself, `teardown`, `teardown_file`).

<!-- markdownlint-disable  MD033 -->
<details>
  <summary>Example of setup/setup_file/teardown/teardown_file call order</summary>
For example the following call order would result from two files (file 1 with tests 1 and 2, and file 2 with test3) beeing tested:

```text
setup_file # from file 1, on entering file 1
  setup
    test1
  teardown
  setup
    test2
  teardown
teardown_file # from file 1, on leaving file 1
setup_file # from file 2,  on enter file 2
  setup
    test3
  teardown
teardown_file # from file 2,  on leaving file 2
```

</details>
<!-- markdownlint-enable MD033 -->

### Code outside of test cases

You can include code in your test file outside of `@test` functions.  For
example, this may be useful if you want to check for dependencies and fail
immediately if they're not present. However, any output that you print in code
outside of `@test`, `setup` or `teardown` functions must be redirected to
`stderr` (`>&2`). Otherwise, the output may cause Bats to fail by polluting the
TAP stream on `stdout`.

### File descriptor 3 (read this if Bats hangs)

Bats makes a separation between output from the code under test and output that
forms the TAP stream (which is produced by Bats internals). This is done in
order to produce TAP-compliant output. In the [Printing to the
terminal](#printing-to-the-terminal) section, there are details on how to use
file descriptor 3 to print custom text properly.

A side effect of using file descriptor 3 is that, under some circumstances, it
can cause Bats to block and execution to seem dead without reason. This can
happen if a child process is spawned in the background from a test. In this
case, the child process will inherit file descriptor 3. Bats, as the parent
process, will wait for the file descriptor to be closed by the child process
before continuing execution. If the child process takes a lot of time to
complete (eg if the child process is a `sleep 100` command or a background
service that will run indefinitely), Bats will be similarly blocked for the same
amount of time.

**To prevent this from happening, close FD 3 explicitly when running any command
that may launch long-running child processes**, e.g. `command_name 3>&-` .

### Printing to the terminal

Bats produces output compliant with [version 12 of the TAP protocol][TAP]. The
produced TAP stream is by default piped to a pretty formatter for human
consumption, but if Bats is called with the `-t` flag, then the TAP stream is
directly printed to the console.

This has implications if you try to print custom text to the terminal. As
mentioned in [File descriptor 3](#file-descriptor-3-read-this-if-bats-hangs),
bats provides a special file descriptor, `&3`, that you should use to print
your custom text. Here are some detailed guidelines to refer to:

- Printing **from within a test function**:
  - To have text printed from within a test function you need to redirect the
    output to file descriptor 3, eg `echo 'text' >&3`. This output will become
    part of the TAP stream. You are encouraged to prepend text printed this way
    with a hash (eg `echo '# text' >&3`) in order to produce 100% TAP compliant
    output. Otherwise, depending on the 3rd-party tools you use to analyze the
    TAP stream, you can encounter unexpected behavior or errors.

  - The pretty formatter that Bats uses by default to process the TAP stream
    will filter out and not print text output to file descriptor 3.

  - Text that is output directly to stdout or stderr (file descriptor 1 or 2),
    ie `echo 'text'` is considered part of the test function output and is
    printed only on test failures for diagnostic purposes, regardless of the
    formatter used (TAP or pretty).

- Printing **from within the `setup` or `teardown` functions**: The same hold
  true as for printing with test functions.

- Printing **outside test or `setup`/`teardown` functions**:
  - Regardless of where text is redirected to (stdout, stderr or file descriptor
    3) text is immediately visible in the terminal.

  - Text printed in such a way, will disable pretty formatting. Also, it will
    make output non-compliant with the TAP spec. The reason for this is that
    each test file is evaluated n+1 times (as mentioned
    [earlier](#writing-tests)). The first run will cause such output to be
    produced before the [_plan line_][tap-plan] is printed, contrary to the spec
    that requires the _plan line_ to be either the first or the last line of the
    output.

  - Due to internal pipes/redirects, output to stderr is always printed first.

[tap-plan]: https://testanything.org/tap-specification.html#the-plan

### Special variables

There are several global variables you can use to introspect on Bats tests:

- `$BATS_TEST_FILENAME` is the fully expanded path to the Bats test file.
- `$BATS_TEST_DIRNAME` is the directory in which the Bats test file is located.
- `$BATS_TEST_NAMES` is an array of function names for each test case.
- `$BATS_TEST_NAME` is the name of the function containing the current test case.
- `$BATS_TEST_DESCRIPTION` is the description of the current test case.
- `$BATS_TEST_NUMBER` is the (1-based) index of the current test case in the test file.
- `$BATS_SUITE_TEST_NUMBER` is the (1-based) index of the current test case in the test suite (over all files).
- `$BATS_TMPDIR` is the location to a directory that may be used to store temporary files.
- `$BATS_FILE_EXTENSION` (default: `bats`) specifies the extension of test files that should be found when running a suite (via `bats [-r] suite_folder/`)

### Libraries and Add-ons

Bats supports loading external assertion libraries and helpers. Those under `bats-core` are officially supported libraries (integration tests welcome!):

- <https://github.com/bats-core/bats-assert> - common assertions for Bats
- <https://github.com/bats-core/bats-support> - supporting library for Bats test helpers
- <https://github.com/bats-core/bats-file> - common filesystem assertions for Bats
- <https://github.com/bats-core/bats-detik> - e2e tests of applications in K8s environments

and some external libraries, supported on a "best-effort" basis:

- <https://github.com/ztombol/bats-docs> (still relevant? Requires review)
- <https://github.com/grayhemp/bats-mock> (as per #147)
- <https://github.com/jasonkarns/bats-mock> (how is this different from grayhemp/bats-mock?)
