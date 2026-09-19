---
title: About setup.sh
hide:
  - toc
---

!!! note

    `setup.sh` is not required. We encourage you to use `docker exec -ti <CONTAINER NAME> setup` instead.

!!! warning

    This script assumes Docker or Podman is used. You will not be able to use `setup.sh` with other container orchestration tools.

[`setup.sh`][github-file-setupsh] is a script that is complimentary to the internal `setup` command in DMS.

It mostly provides the convenience of aliasing `docker exec -ti <CONTAINER NAME> setup`, inferring the container name of a running DMS instance or running a new instance and bind mounting necessary volumes implicitly.

It is intended to be run from the host machine, _not_ from inside your running container. The latest version of the script is included in the DMS repository. You may retrieve it at any time by running this command in your console:

```sh
wget https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/setup.sh
chmod a+x ./setup.sh
```

For more information on using the script run: `./setup.sh help`.

[github-file-setupsh]: https://github.com/docker-mailserver/docker-mailserver/blob/master/setup.sh
