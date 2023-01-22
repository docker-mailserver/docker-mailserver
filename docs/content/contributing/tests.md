---
title: 'Tests'
---

!!! quote "_Program testing can be used to show the presence of bugs, but never to show their absence!_"

    – Edsger Wybe Dijkstra

## Introduction

DMS employs a variety of unit- and integration-tests. All tests and associated configuration is stored in the `test/` directory. If you want to integrate a new feature into DMS or change existing functionality, you will probably need to work with our test suite.

!!! question "Can I use macOS?"

    We do not support running linting, tests, etc on macOS at this time. Please use a linux VM.

### About

We use [BATS] (_Bash Automated Testing System_) and additional support libraries. [BATS] is very similar to Bash, and one will easily and quickly get an understanding of how tests in a single file are run. A [template test file][template-test] provides a minimal working example for newcomers to look at.

### Structure

The `test/` directory contains multiple directories, among them the `bats/` directory, which is the [BATS] submodule, as well as the `helper/` directory. This one is especially interesting because it contains helper functionality used in almost every test. The tests themselves live in `test/tests/`.

!!! info "WIP: Test Suite Refactoring"

    We are currently in the process of parallelizing all of our tests. Tests will be moved into `test/tests/parallel/` and new tests should be placed there as well.

### How Do Tests Run?

Before running tests yourself, you need to understand the following first: we need to differentiate between

1. running test locally on **system** system
2. running tests in our CI (_GitHub Actions_), e.g. when [testing a pull request][testing-prs]

#### How Local Tests Work

Local tests are executed on your machine. In the ["Prerequisites" section](#prerequisites) below you'll find everything you need to run tests yourself. Tests under `test/tests/parallel/` are run in parallel. To be more precise, tests within a single file are run **sequentially**, but multiple files are run in **parallel**. Parallel tests are partionioned into sets (currently 3). You can run all sets simultaneously, although we do not recommend this because of the high resource demand this incours on your system, which in turn could lead to test failures. The tests under `test/tests/serial/` are all run in serial.

#### How Tests Work With GitHub Actions

With GitHub Actions, is is very similar to how [tests run locally](#how-local-tests-work), but all parallel sets and the serial tests are run **in parallell** but separately to not interfere with each other (on different runners). This increases the degree of parallelization which in turn speeds up CI.

## Running Tests

### Prerequisites

To run the test suite, you will need to

1. [Install Docker][get-docker]
2. Install `jq` and (GNU) `parallel` (under Ubuntu, use `sudo apt-get -y install jq parallel`)
3. Execute `git submodule update --init --recursive` if you haven't already initialized the git submodules

### Executing Test(s)

We use `make` to run commands. You will first need to build the container image via `make build`. You can then

1. Run all tests: `make clean tests`
2. Run a single test: `make clean generate-accounts test/<TEST NAME WITHOUT .bats SUFFIX>`
3. Run multiple unrelated tests: `make clean generate-accounts test/<TEST NAME WITHOUT .bats SUFFIX>,<TEST NAME WITHOUT .bats SUFFIX>` (just add a `,` and then immediately write the new test name)
4. Run a whole set or all serial tests: `make clean generate-accounts tests/parallel/setX` where `X` is the number of the set or `make clean generate-accounts tests/serial`

??? example "Run One or Multiple Specific Test(s)"

    Multiple test files can be run sequentially with a `,` delimiter between file names: `make test/tls_letsencrypt,tls_manual`

    To run only the tests in `template.bats`, use `make clean test/template` (or with relative path: `make clean test/parallel/set2/template`).

??? tip "Setting the Degree of Parallelization for Tests"

    If your machine is capable, you can increase the amount of tests that are run simultaneously by prepending the `make clean all` command with `BATS_PARALLEL_JOBS=X` (i.e. `BATS_PARALLEL_JOBS=X make clean all`). This wil speed up the test procedure. You can also run all tests in serial by setting `BATS_PARALLEL_JOBS=1` this way.

    The default value of `BATS_PARALLEL_JOBS` is 2. Increasing it to `3` requires 6 threads and 6GB of main memory; increasing it to `4` requires 8 threads and at least 8GB of main memory.

!!! warning "Test Output when Running in Parallel"

    [When running tests in parallel][docs-bats-parallel] (_with `make clean generate-accounts tests/parallel/setX`_), BATS will delay outputting the results until completing all test cases within a file.

    This also delays test failures as a result. When troubleshooting parallel set tests, you may prefer to run them serially as advised below.

    When writing tests, ensure that parallel set tests still pass when run in parallel. You need to account for other tests running in parallel that may interfere with your own tests logic.

[//]: # (Links)

[BATS]: https://github.com/bats-core/bats-core
[template-test]: https://github.com/docker-mailserver/docker-mailserver/blob/master/test/tests/parallel/set2/template.bats
[testing-prs]: https://github.com/docker-mailserver/docker-mailserver/blob/master/.github/workflows/test_merge_requests.yml
[get-docker]: https://docs.docker.com/get-docker/
[docs-bats-parallel]: https://bats-core.readthedocs.io/en/v1.8.2/usage.html#parallel-execution
