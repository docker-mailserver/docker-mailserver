---
title: About setup.sh
hide:
  - toc
---

!!! note

    `setup.sh` is not required since v10.2.0. We encourage you to use `docker exec -ti <CONTAINER NAME> setup` instead.

!!! warning

    This script assumes Docker or Podman is used. You will not be able to use `setup.sh` with other container orchestration tools.

[`setup.sh`][github-file-setupsh] is a script that aids in running commands inside your DMS container, including initial configuration. It has become a wrapper around `docker exec -ti <CONTAINER NAME> setup` where it basically tries to automatically determine `<CONTAINER NAME>`.

It is intended to be run from the host machine, _not_ from inside your running container. The latest version of the script is included in the `docker-mailserver` repository. You may retrieve it at any time by running this command in your console:

```sh
wget https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/setup.sh
chmod a+x ./setup.sh
```

By running `./setup.sh help`, usage information is printed.

[github-file-setupsh]: https://github.com/docker-mailserver/docker-mailserver/blob/master/setup.sh
