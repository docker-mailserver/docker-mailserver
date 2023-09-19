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

The service [`containrrr/watchtower`][watchtower] can monitor your images and automatically update them. Enable the [`--cleanup` option][watchtower-cleanup] to remove orphaned images from storage that are no longer used.

[watchtower]: https://containrrr.dev/watchtower/
[watchtower-cleanup]: https://containrrr.github.io/watchtower/arguments/#cleanup

```yaml
services:
  watchtower:
    image: containrrr/watchtower
    environment:
      - WATCHTOWER_CLEANUP=true
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

!!! tip "Only update specific containers"

    The default `watchtower` service will poll every 24 hours for all images to update, not just within your `compose.yaml`.

    View their docs to provide a list of containers names and other settings if you'd like to restrict that behaviour.

!!! tip "Manual cleanup"

    While `watchtower` also supports running once with `docker run` or `compose.yaml` with the `--run-once` option, you can also directly invoke cleanup with [`docker image prune --all`][docker-docs-prune-image] or the more thorough [`docker system prune --all`][docker-docs-prune-system] (_also removes unused containers, networks, build cache_). Avoid the `--all` option if you only want to cleanup "dangling" content.

[docker-docs-prune-image]: https://docs.docker.com/engine/reference/commandline/image_prune/
[docker-docs-prune-system]: https://docs.docker.com/engine/reference/commandline/system_prune/
