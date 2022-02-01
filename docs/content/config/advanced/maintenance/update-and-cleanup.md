---
title: 'Maintenance | Update and Cleanup'
---

## Automatic Update

Docker images are handy but it can become a hassle to keep them updated. Also when a repository is automated you want to get these images when they get out.

One could setup a complex action/hook-based workflow using probes, but there is a nice, easy to use docker image that solves this issue and could prove useful: [`watchtower`](https://hub.docker.com/r/containrrr/watchtower).

A docker-compose example:

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

When you are pulling new images in automatically, it would be nice to have them cleaned up as well. There is also a docker image for this: [`spotify/docker-gc`](https://hub.docker.com/r/spotify/docker-gc/).

A docker-compose example:

```yaml
services:
  docker-gc:
    restart: always
    image: spotify/docker-gc:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

For more details, see the [manual](https://github.com/spotify/docker-gc/blob/master/README.md)

Or you can just use the [`--cleanup`](https://containrrr.github.io/watchtower/arguments/#cleanup) option provided by `containrrr/watchtower`.
