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

### Submit a Pull-Request

!!! question "Motivation"

    You want to add a feature? Feel free to start creating an issue explaining what you want to do and how you're thinking doing it. Other users may have the same need and collaboration may lead to better results.

The development workflow is the following:

1. Fork the project and clone your fork
   1. Create a new branch to work on
   2. Run `git submodule update --init --recursive`
2. Write the code that is needed :D
3. Add integration tests if necessary
4. [Prepare your environment and run linting and tests][docs-tests]
5. Document your improvements if necessary (e.g. if you introduced new environment variables, describe those in the [ENV documentation][docs-environment])
6. [Commit][commit] and [sign your commit][gpg], push and create a pull-request to merge into `master`. Please **use the pull-request template** to provide a minimum of contextual information and make sure to meet the requirements of the checklist.
   1. Pull requests are automatically tested against the CI and will be reviewed when tests pass
   2. When your changes are validated, your branch is merged
   3. CI builds the new `:edge` image immediately and your changes will be includes in the next version release.

[docs]: https://docker-mailserver.github.io/docker-mailserver/edge
[github-file-readme]: https://github.com/docker-mailserver/docker-mailserver/blob/master/README.md
[docs-environment]: ../config/environment.md
[docs-tests]: ./tests.md
[commit]: https://help.github.com/articles/closing-issues-via-commit-messages/
[gpg]: https://docs.github.com/en/github/authenticating-to-github/generating-a-new-gpg-key
