# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog][kac] and this project adheres to
[Semantic Versioning][semver].

[kac]: https://keepachangelog.com/en/1.0.0/
[semver]: https://semver.org/

## [Unreleased]

## [1.3.0] - 2021-03-08

### Added

* custom test-file extension via `BATS_FILE_EXTENSION` when searching for test
  files in a directory (#376)
* TAP13 formatter, including millisecond timing (#337)
* automatic release to NPM via Github Actions (#406)

#### Documentation

* added documentation about overusing `run` (#343)
* improved documentation of `load` (#332)

### Changed

* recursive suite mode will follow symlinks now (#370)
* split options for (file-) `--report-formatter` and (stdout) `--formatter` (#345)
  * **WARNING**: This changes the meaning of `--formatter junit`.
    stdout will now show unified xml instead of TAP. From now on, please use
    `--report-formatter junit` to obtain the `.xml` report file!
* removed `--parallel-preserve-environment` flag, as this is the default
  behavior (#324)
* moved CI from Travis/Appveyor to Github Actions (#405)
* preprocessed files are no longer removed if `--no-tempdir-cleanup` is
  specified (#395)

#### Documentation

* moved documentation to [readthedocs](https://bats-core.readthedocs.io/en/latest/)

### Fixed

#### Correctness

* fix internal failures due to unbound variables when test files use `set -u` (#392)
* fix internal failures due to changes to `$PATH` in test files (#387)
* fix test duration always being 0 on busybox installs (#363)
* fix hangs on CTRL+C (#354)
* make `BATS_TEST_NUMBER` count per file again (#326)
* include `lib/` in npm package (#352)

#### Performance

* don't fork bomb in parallel mode (#339)
* preprocess each file only once (#335)
* avoid running duplicate files n^2 times (#338)

#### Documentation

* fix documentation for `--formatter junit` (#334)
* fix documentation for `setup_file` variables (#333)
* fix link to examples page (#331)
* fix link to "File Descriptor 3" section (#301)

## [1.2.1] - 2020-07-06

### Added

* JUnit output and extensible formatter rewrite (#246)
* `load` function now reads from absolute and relative paths, and $PATH (#282)
* Beginner-friendly examples in /docs/examples (#243)
* @peshay's `bats-file` fork contributed to `bats-core/bats-file` (#276)

### Changed

* Duplicate test names now error (previous behaviour was to issue a warning) (#286)
* Changed default formatter in Docker to pretty by adding `ncurses` to
  Dockerfile, override with `--tap` (#239)
* Replace "readlink -f" dependency with Bash solution (#217)

## [1.2.0] - 2020-04-25

Support parallel suite execution and filtering by test name.

### Added

* docs/CHANGELOG.md and docs/releasing.md (#122)
* The `-f, --filter` flag to run only the tests matching a regular expression  (#126)
* Optimize stack trace capture (#138)
* `--jobs n` flag to support parallel execution of tests with GNU parallel (#172)

### Changed

* AppVeyor builds are now semver-compliant (#123)
* Add Bash 5 as test target (#181)
* Always use upper case signal names to avoid locale dependent err… (#215)
* Fix for tests reading from stdin (#227)
* Fix wrong line numbers of errors in bash < 4.4 (#229)
* Remove preprocessed source after test run (#232)

## [1.1.0] - 2018-07-08

This is the first release with new features relative to the original Bats 0.4.0.

### Added

* The `-r, --recursive` flag to scan directory arguments recursively for
  `*.bats` files (#109)
* The `contrib/rpm/bats.spec` file to build RPMs (#111)

### Changed

* Travis exercises latest versions of Bash from 3.2 through 4.4 (#116, #117)
* Error output highlights invalid command line options (#45, #46, #118)
* Replaced `echo` with `printf` (#120)

### Fixed

* Fixed `BATS_ERROR_STATUS` getting lost when `bats_error_trap` fired multiple
  times under Bash 4.2.x (#110)
* Updated `bin/bats` symlink resolution, handling the case on CentOS where
  `/bin` is a symlink to `/usr/bin` (#113, #115)

## [1.0.2] - 2018-06-18

* Fixed sstephenson/bats#240, whereby `skip` messages containing parentheses
  were truncated (#48)
* Doc improvements:
  * Docker usage (#94)
  * Better README badges (#101)
  * Better installation instructions (#102, #104)
* Packaging/installation improvements:
  * package.json update (#100)
  * Moved `libexec/` files to `libexec/bats-core/`, improved `install.sh` (#105)

## [1.0.1] - 2018-06-09

* Fixed a `BATS_CWD` bug introduced in #91 whereby it was set to the parent of
  `PWD`, when it should've been set to `PWD` itself (#98). This caused file
  names in stack traces to contain the basename of `PWD` as a prefix, when the
  names should've been purely relative to `PWD`.
* Ensure the last line of test output prints when it doesn't end with a newline
  (#99). This was a quasi-bug introduced by replacing `sed` with `while` in #88.

## [1.0.0] - 2018-06-08

`1.0.0` generally preserves compatibility with `0.4.0`, but with some Bash
compatibility improvements and a massive performance boost. In other words:

* all existing tests should remain compatible
* tests that might've failed or exhibited unexpected behavior on earlier
  versions of Bash should now also pass or behave as expected

Changes:

* Added support for Docker.
* Added support for test scripts that have the [unofficial strict
  mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/) enabled.
* Improved stability on Windows and macOS platforms.
* Massive performance improvements, especially on Windows (#8)
* Workarounds for inconsistent behavior between Bash versions (#82)
* Workaround for preserving stack info after calling an exported function under
  Bash < 4.4 (#87)
* Fixed TAP compliance for skipped tests
* Added support for tabs in test names.
* `bin/bats` and `install.sh` now work reliably on Windows (#91)

## [0.4.0] - 2014-08-13

* Improved the display of failing test cases. Bats now shows the source code of
  failing test lines, along with full stack traces including function names,
  filenames, and line numbers.
* Improved the display of the pretty-printed test summary line to include the
  number of skipped tests, if any.
* Improved the speed of the preprocessor, dramatically shortening test and suite
  startup times.
* Added support for absolute pathnames to the `load` helper.
* Added support for single-line `@test` definitions.
* Added bats(1) and bats(7) manual pages.
* Modified the `bats` command to default to TAP output when the `$CI` variable
  is set, to better support environments such as Travis CI.

## [0.3.1] - 2013-10-28

* Fixed an incompatibility with the pretty formatter in certain environments
  such as tmux.
* Fixed a bug where the pretty formatter would crash if the first line of a test
  file's output was invalid TAP.

## [0.3.0] - 2013-10-21

* Improved formatting for tests run from a terminal. Failing tests are now
  colored in red, and the total number of failing tests is displayed at the end
  of the test run. When Bats is not connected to a terminal (e.g. in CI runs),
  or when invoked with the `--tap` flag, output is displayed in standard TAP
  format.
* Added the ability to skip tests using the `skip` command.
* Added a message to failing test case output indicating the file and line
  number of the statement that caused the test to fail.
* Added "ad-hoc" test suite support. You can now invoke `bats` with multiple
  filename or directory arguments to run all the specified tests in aggregate.
* Added support for test files with Windows line endings.
* Fixed regular expression warnings from certain versions of Bash.
* Fixed a bug running tests containing lines that begin with `-e`.

## [0.2.0] - 2012-11-16

* Added test suite support. The `bats` command accepts a directory name
  containing multiple test files to be run in aggregate.
* Added the ability to count the number of test cases in a file or suite by
  passing the `-c` flag to `bats`.
* Preprocessed sources are cached between test case runs in the same file for
  better performance.

## [0.1.0] - 2011-12-30

* Initial public release.

[Unreleased]: https://github.com/bats-core/bats-core/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/bats-core/bats-core/compare/v1.0.2...v1.1.0
[1.0.2]: https://github.com/bats-core/bats-core/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/bats-core/bats-core/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/bats-core/bats-core/compare/v0.4.0...v1.0.0
[0.4.0]: https://github.com/bats-core/bats-core/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/bats-core/bats-core/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/bats-core/bats-core/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bats-core/bats-core/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bats-core/bats-core/commits/v0.1.0
