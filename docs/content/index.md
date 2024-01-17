---
title: Home
---

# Welcome to the Documentation for `docker-mailserver`!

!!! info "This Documentation is Versioned"

    **Make sure** to select the correct version of this documentation! It should match the version of the image you are using. The default version corresponds to the `:latest` image tag - [the most recent stable release][docs-tagging].

This documentation provides you not only with the basic setup and configuration of DMS but also with advanced configuration, elaborate usage scenarios, detailed examples, hints and more.

[docs-tagging]: ./usage.md#tagging-convention

## About

`docker-mailserver`, or DMS for short, is a production-ready fullstack but simple mail server (SMTP, IMAP, LDAP, Anti-spam, Anti-virus, etc.). It employs only configuration files, no SQL database. The image is focused around the slogan "Keep it simple and versioned".

## Contents

### Getting Started

If you're completely new to mail servers or you want to read up on them, check out our [_Introduction_ page][docs-introduction]. If you're new to DMS as a mail server appliance, make sure to read the [_Usage_ chapter][docs-usage] first. If you want to look at examples for Docker Compose, we have an [_Examples_ page][docs-examples].

There is also a script - [`setup.sh`][github-file-setupsh] - supplied with this project. It supports you in configuring and administrating your server. Information on how to get it and how to use it is available [on a dedicated page][docs-setupsh].

[docs-introduction]: ./introduction.md
[docs-usage]: ./usage.md
[docs-examples]: ./examples/tutorials/basic-installation.md
[github-file-setupsh]: https://github.com/docker-mailserver/docker-mailserver/blob/master/setup.sh
[docs-setupsh]: ./config/setup.sh/

### Configuration

We have a [dedicated configuration page][docs-environment]. It contains most of the configuration and explanation you need to setup _your_ mail server properly. Be aware that advanced tasks may still require reading through all parts of this documentation; it may also involve inspecting your running container for debugging purposes. After all, a mail server is a complex arrangement of various programs.

!!! important

    If you'd like to change, patch or alter files or behavior of DMS, you can use a script. Just place a script called `user-patches.sh` in your `./docker-data/dms/config/` folder volume (which is mounted to `/tmp/docker-mailserver/` inside the container) and it will be run on container startup. See the ['Modifications via Script' page][docs-userpatches] for additional documentation and an example.

You might also want to check out:

1. A list of [all configuration options via ENV][docs-environment]
2. A list of [all optional and automatically created configuration files and directories][docs-optionalconfig]
3. How to [debug your mail server][docs-debugging]

!!! tip

    Definitely check out the [FAQ][docs-faq] for more information and tips! Please do not open an issue before you have checked our documentation for answers, including the [FAQ][docs-faq]!

[docs-environment]: ./config/environment.md
[docs-userpatches]: ./faq.md#how-to-adjust-settings-with-the-user-patchessh-script
[docs-setupsh]: ./config/setup.sh.md
[docs-optionalconfig]: ./config/advanced/optional-config.md
[docs-faq]: ./faq.md
[docs-debugging]: ./config/debugging.md

### Tests

DMS employs a variety of tests. If you want to know more about our test suite, view our [testing docs][docs-tests].

[docs-tests]: ./contributing/tests.md

### Contributing

We are always happy to welcome new contributors. For guidelines and entrypoints please have a look at the [Contributing section][docs-contributing].

[docs-contributing]: ./contributing/issues-and-pull-requests.md
