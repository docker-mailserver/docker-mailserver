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

1. [Install Docker]
2. Install `jq` (under Ubuntu, use `sudo apt-get -y install jq`)
3. Execute `git submodule update --init --recursive` if you haven't already initialized the git submodules
4. Execute `make clean all`

!!! info "Can I use MacOS?"

    We do not support running linting, tests, etc on macOS at this time. Please use a linux VM.

??? tip "Setting the Degree of Parallelization for Tests"

    If your machine is capable, you can increase the amount of tests that are run simultaneously by prepending the `make clean all` command with `BATS_PARALLEL_JOBS=X` (i.e. `BATS_PARALLEL_JOBS=X make clean all`). This wil speed up the test procedure. You can also run all tests in serial by setting `BATS_PARALLEL_JOBS=1` this way.

    The default value of `BATS_PARALLEL_JOBS` is 2. Increasing it to `3` requires 6 threads and 6GB of main memory; increasing it to `4` requires 8 threads and at least 8GB of main memory.

!!! warning "Test Output when Running in Parallel"

    When running test in parallel, BATS will run more than one test at any given time. This can result in output not being exactly what you'd expect, i.e. there could be _more_ or _less_ than you'd think. Those writing tests need to take care of this. Always test with `make clean generate-accounts tests/parallel/setX`.

??? tip "Running a Specific Test"

    To run a specific test, use `make build generate-accounts test/<TEST NAME>`, where `<TEST NAME>` is the file name of the test (_for more precision use a relative path: `test/test/<PATH>`_) **excluding** the `.bats` suffix.

    Example: To run only the tests in `template.bats`, use `make test/template` (or `make test/parallel/set2/template`).

[Install Docker]: https://docs.docker.com/get-docker/

## Documentation

You will need to have Docker installed. Navigate into the `docs/` directory. Then run:

```sh
docker run --rm -it -p 8000:8000 -v "${PWD}:/docs" squidfunk/mkdocs-material
```

This serves the documentation on your local machine on port `8000`. Each change will be hot-reloaded onto the page you view, just edit, save and look at the result.
