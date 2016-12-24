# Contributing

`docker-mailserver` is OpenSource. That means that you can contribute on enhancements, bug fixing or improving the documentation in the Wiki.

## Open an issue

When opening an issue, please provide details use case to let the community reproduce your problem.
Please start the mail server with env `DMS_DEBUG=1` and paste the ouput into the issue.

## Pull Requests

#### Project architecture

    ├── config                    # User: personal configurations
    ├── target                    # Developer: default server configuration, used when building the image
    └── test                      # Developer: integration tests to check that everything keeps working

#### Development Workflow

The development workflow is the following:

- Fork project and clone your fork
- Create a branch using `git checkout -b branch_name` (you can use `issue-xxx` if fixing an existing issue)
- Code :-)
- Add integration tests in `test/tests.bats`
- Use `make` to build image locally and run tests
- Document your improvements
- [Commit](https://help.github.com/articles/closing-issues-via-commit-messages/), push and make a pull-request
- Pull-request is automatically tested on Travis
- When tests are green, your branch is merged into `master`
- `master` is automatically tested on Travis
- Docker builds a new `latest` image
