---
title: 'Contributing | Issues and Pull Requests'
---

This project is Open Source. That means that you can contribute on enhancements, bug fixing or improving the documentation.

## Opening an Issue

!!! attention

    **Before opening an issue**, read the [`README`][github-file-readme] carefully, study the [documentation][docs], the Postfix/Dovecot documentation and your search engine you trust. The issue tracker is not meant to be used for unrelated questions! 

When opening an issue, please provide details use case to let the community reproduce your problem. Please start `docker-mailserver` with the environment variable `LOG_LEVEL` set to `debug` or `trace` and paste the output into the issue.

!!! attention

    **Use the issue templates** to provide the necessary information. Issues which do not use these templates are not worked on and closed. 

By raising issues, I agree to these terms and I understand, that the rules set for the issue tracker will help both maintainers as well as everyone to find a solution.

Maintainers take the time to improve on this project and help by solving issues together. It is therefore expected from others to make an effort and **comply with the rules**.

## Pull Requests

!!! question "Motivation"

    You want to add a feature? Feel free to start creating an issue explaining what you want to do and how you're thinking doing it. Other users may have the same need and collaboration may lead to better results.

### Submit a Pull-Request

The development workflow is the following:

1. Fork the project and clone your fork with `git clone --recurse-submodules ...` or run `git submodule update --init --recursive` after you cloned your fork
2. Write the code that is needed :D
3. Add integration tests if necessary
4. [Prepare your environment and run linting and tests][docs-general-tests]
5. Document your improvements if necessary (e.g. if you introduced new environment variables, describe those in the [ENV documentation][docs-environment]) and add your changes the changelog under the "Unreleased" section
6. [Commit][commit] (and [sign your commit][gpg]), push and create a pull-request to merge into `master`. Please **use the pull-request template** to provide a minimum of contextual information and make sure to meet the requirements of the checklist.

Pull requests are automatically tested against the CI and will be reviewed when tests pass. When your changes are validated, your branch is merged. CI builds the new `:edge` image immediately and your changes will be includes in the next version release.

[docs]: https://docker-mailserver.github.io/docker-mailserver/edge
[github-file-readme]: https://github.com/docker-mailserver/docker-mailserver/blob/master/README.md
[docs-environment]: ../config/environment.md
[docs-general-tests]: ./general.md#tests
[commit]: https://help.github.com/articles/closing-issues-via-commit-messages/
[gpg]: https://docs.github.com/en/github/authenticating-to-github/generating-a-new-gpg-key
