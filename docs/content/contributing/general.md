---
title: 'Contributing | General Information'
---

## Coding Style

When refactoring, writing or altering scripts or other files, adhere to these rules:

1. **Adjust your style of coding to the style that is already present**! Even if you do not like it, this is due to consistency. There was a lot of work involved in making all scripts consistent.
2. **Use `shellcheck` to check your scripts**! Your contributions are checked by GitHub Actions too, so you will need to do this. You can **lint your work with `make lint`** to check against all targets.
3. **Use the provided `.editorconfig`** file.
4. Use `/bin/bash` instead of `/bin/sh` in scripts

## Tests

To run the test suite, you will need to

1. [Install Docker][get-docker]
2. Install `jq` (under Ubuntu, use `sudo apt-get -y install jq`)
3. Execute `git submodule update --init --recursive` if you haven't already initialized the git submodules
4. Execute `make clean all`

!!! info "Can I use MacOS?"

    We do not support running linting, tests, etc on macOS at this time. Please use a linux VM.

??? tip "Setting the Degree of Parallelization for Tests"

    If your machine is capable, you can increase the amount of tests that are run simultaneously by prepending the `make clean all` command with `BATS_PARALLEL_JOBS=X` (i.e. `BATS_PARALLEL_JOBS=X make clean all`). This wil speed up the test procedure. You can also run all tests in serial by setting `BATS_PARALLEL_JOBS=1` this way.

    The default value of `BATS_PARALLEL_JOBS` is 2. Increasing it to `3` requires 6 threads and 6GB of main memory; increasing it to `4` requires 8 threads and at least 8GB of main memory.

!!! warning "Test Output when Running in Parallel"

    [When running tests in parallel][docs-bats-parallel] (_with `make clean generate-accounts tests/parallel/setX`_), BATS will delay outputting the results until completing all test cases within a file.

    This also delays test failures as a result. When troubleshooting parallel set tests, you may prefer to run them serially as advised below.

    When writing tests, ensure that parallel set tests still pass when run in parallel. You need to account for other tests running in parallel that may interfere with your own tests logic.

??? tip "Run a Specific Test"

    Run `make build generate-accounts test/<TEST NAME>`, where `<TEST NAME>` is the file name of the test **excluding** the `.bats` suffix (_use a relative path if needing to be more specific: `test/<RELATIVE PATH>/<TEST NAME>`_).

    Multiple test files can be run sequentially with a `,` delimiter between file names:
    `make test/tls_letsencrypt,tls_manual`

    **Example:** To run only the tests in `template.bats`, use `make test/template` (_or with relative path: `make test/parallel/set2/template`_).

## Documentation

You will need to have Docker installed. Navigate into the `docs/` directory. Then run:

```sh
docker run --rm -it -p 8000:8000 -v "${PWD}:/docs" squidfunk/mkdocs-material
```

This serves the documentation on your local machine on port `8000`. Each change will be hot-reloaded onto the page you view, just edit, save and look at the result.

[get-docker]: https://docs.docker.com/get-docker/
[docs-bats-parallel]: https://bats-core.readthedocs.io/en/v1.8.2/usage.html#parallel-execution
