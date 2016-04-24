Contribution is like any other GitHub project:

- Fork
- Improve
- Add integration tests in `test/tests.bats`
- Build image and run tests using `make`
- Document your improvements
- Commit, push and make a pull-request

#### Project architecture

    ├── config                    # User: personal configurations
    ├── target                    # Developer: default server configurations
    └── test                      # Developer: integration tests
