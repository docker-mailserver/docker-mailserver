`docker-mailserver` is OpenSource. That means that you can contribute on enhancements, bug fixing or improving the documentation in the Wiki.

#### Project architecture

    ├── config                    # User: personal configurations
    ├── target                    # Developer: default server configurations
    └── test                      # Developer: integration tests

#### Development Workflow

The development workflow is the following:

- Fork project and clone your fork
- Create a branch using `git checkout -b branch_name`
- Code :-)
- Add integration tests in `test/tests.bats`
- Use `make` to build image locally and run tests
- Document your improvements
- [Commit](https://help.github.com/articles/closing-issues-via-commit-messages/), push and make a pull-request
- Branch is automatically tested on Travis
- When tests are green, your branch is merged to `master`
- Master is automatically tested on Travis
- Docker builds a new `latest` image

