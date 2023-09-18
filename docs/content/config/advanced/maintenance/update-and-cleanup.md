---
title: 'Maintenance | Update and Cleanup'
---

## Automatic Update

Docker images are handy but it can become a hassle to keep them updated. Also when a repository is automated you want to get these images when they get out.

One could setup a complex action/hook-based workflow using probes, but there is a nice, easy to use docker image that solves this issue and could prove useful: [`watchtower`](https://hub.docker.com/r/containrrr/watchtower).

A Docker Compose example:

```yaml
services:
  watchtower:
    restart: always
    image: containrrr/watchtower:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

For more details, see the [manual](https://containrrr.github.io/watchtower/)

## Automatic Cleanup

For cleanup you can use the [`--cleanup`](https://containrrr.github.io/watchtower/arguments/#cleanup) option provided by `containrrr/watchtower`.

Or consider using ['docker prune command'](https://docs.docker.com/engine/reference/commandline/system_prune/)
