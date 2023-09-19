---
title: 'Maintenance | Update and Cleanup'
---

[`containrrr/watchtower`][watchtower-dockerhub] is a service that monitors Docker images for updates, automatically applying them to running containers.

!!! example "Automatic image updates + cleanup"

    ```yaml title="compose.yaml"
    services:
      watchtower:
        image: containrrr/watchtower:latest
        # Automatic cleanup (removes older image pulls from wasting disk space):
        environment:
          - WATCHTOWER_CLEANUP=true
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
    ```

!!! tip "Updating only specific containers"

    The default `watchtower` service will check every 24 hours for any new image updates to pull, **not only the images** defined within your `compose.yaml`.

    The images to update can be restricted with a custom command that provides a list of containers names and other config options. Configuration is detailed in the [`watchtower` docs][watchtower-docs].

!!! info "Manual cleanup"

    `watchtower` also supports running on-demand with `docker run` or `compose.yaml` via the `--run-once` option.
    
    You can also directly invoke cleanup of Docker storage with:

    - [`docker image prune --all`][docker-docs-prune-image]
    - [`docker system prune --all`][docker-docs-prune-system] (_also removes unused containers, networks, build cache_).
    - Avoid the `--all` option to only remove ["dangling" content][docker-prune-dangling] (_eg: Orphaned images_).

[watchtower-dockerhub]: https://hub.docker.com/r/containrrr/watchtower
[watchtower-cleanup]: https://containrrr.github.io/watchtower/arguments/#cleanup
[watchtower-docs]: https://containrrr.dev/watchtower/

[docker-docs-prune-image]: https://docs.docker.com/engine/reference/commandline/image_prune/
[docker-docs-prune-system]: https://docs.docker.com/engine/reference/commandline/system_prune/
[docker-prune-dangling]: https://stackoverflow.com/questions/45142528/what-is-a-dangling-image-and-what-is-an-unused-image/60756668#60756668
