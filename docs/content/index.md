---
title: Home
---

# Welcome to the Extended Documentation for `docker-mailserver`!

Please first have a look at the [`README.md`][github-file-readme] to setup and configure this server.

This documentation provides you with advanced configuration, detailed examples, and hints.

## Getting Started

1. The script [`setup.sh`][github-file-setupsh] is supplied with this project. It supports you in **configuring and administrating** your server. Information on how to get it and how to use it is available [on a dedicated page][docs-setupsh].
2. Be aware that advanced tasks may still require tweaking environment variables, reading through documentation and sometimes inspecting your running container for debugging purposes. After all, a mail-server is a complex arrangement of various programs.
3. A list of all configuration options is documented on [the ENV page][docs-environment]. The [`README.md`][github-file-readme] is a good starting point to understand what this image is capable of.
4. A list of all optional and automatically created configuration files and directories is available [on the dedicated page][docs-optionalconfig].

!!! tip
    See the [FAQ][docs-faq] for some more tips!

!!! important
    If you'd like to change, patch or alter files or behavior of `docker-mailserver`, you can use a script. Just place a script called `user-patches.sh` in your `./docker-data/dms/config/` folder volume and it will be run on container startup. See the ['Modifications via Script' page][docs-userpatches]for additional documentation and an example.

## Contributing

We are always happy to welcome new contributors. For guidelines and entrypoints please have a look at the [Contributing section][docs-contributing].

[docs-contributing]: ./contributing/issues-and-pull-requests.md
[docs-faq]: ./faq.md
[docs-optionalconfig]: ./config/advanced/optional-config.md
[docs-setupsh]: ./config/setup.sh.md
[docs-userpatches]: ./config/advanced/override-defaults/user-patches.md
[docs-environment]: ./config/environment.md
[github-file-readme]: https://github.com/docker-mailserver/docker-mailserver/blob/master/README.md
[github-file-setupsh]: https://github.com/docker-mailserver/docker-mailserver/blob/master/setup.sh
