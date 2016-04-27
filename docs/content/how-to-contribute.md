`docker-mailserver` is OpenSource. That means that you can contribute on enhancements, bug fixing or improving the documentation in the Wiki.

#### Project architecture

    ├── config                    # User: personal configurations
    ├── target                    # Developer: default server configurations
    └── test                      # Developer: integration tests

#### Development Workflow

When `v2` will be released, the development workflow will be:

- Fork and clone your fork
- Create a branch using `git checkout -b branch_name`
- Code :-)
- Add integration tests in `test/tests.bats`
- Use `make` to build image locally and run tests
- Document your improvements
- Commit, push and make a pull-request on `develop` branch
- When tests are green, your branch is merged to `develop`
- Docker builds a new `develop` image
- `:develop` image is tested on real servers by contributors
- When feedback is positive, `develop` is merged on `master`

