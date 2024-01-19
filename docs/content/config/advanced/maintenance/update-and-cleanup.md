---
title: 'Maintenance | Update and Cleanup'
---

[`containrrr/watchtower`][watchtower-dockerhub] is a service that monitors Docker images for updates, automatically applying them to running containers.

!!! example "Automatic image updates + cleanup"

    Run a `watchtower` container with access to `docker.sock`, enabling the service to manage Docker:

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

!!! tip "The image tag used for a container is monitored for updates (eg: `:latest`, `:edge`, `:13`)"

    The automatic update support is **only for updates to that specific image tag**.

    - Your container will not update to a new major version tag (_unless using `:latest`_).
    - Omit the minor or patch portion of the semver tag to receive updates for the omitted portion (_eg: `13` will represent the latest minor + patch release of `v13`_).

!!! tip "Updating only specific containers"

    By default the `watchtower` service will check every 24 hours for new image updates to pull, based on currently running containers (_**not restricted** to only those running within your `compose.yaml`_).

    Images eligible for updates can configured with a [custom `command`][docker-docs-compose-command] that provides a list of container names, or via other supported options (eg: labels). This configuration is detailed in the [`watchtower` docs][watchtower-docs].

!!! info "Manual cleanup"

    `watchtower` also supports running on-demand with `docker run` or `compose.yaml` via the `--run-once` option.
    
    You can alternatively invoke cleanup of Docker storage directly with:

    - [`docker image prune --all`][docker-docs-prune-image]
    - [`docker system prune --all`][docker-docs-prune-system] (_also removes unused containers, networks, build cache_).

    If you omit the `--all` option, this will instead only remove ["dangling" content][docker-prune-dangling] (_eg: Orphaned images_).

[watchtower-dockerhub]: https://hub.docker.com/r/containrrr/watchtower
[watchtower-cleanup]: https://containrrr.github.io/watchtower/arguments/#cleanup
[watchtower-docs]: https://containrrr.dev/watchtower/

[docker-docs-compose-command]: https://docs.docker.com/compose/compose-file/05-services/#command
[docker-docs-prune-image]: https://docs.docker.com/engine/reference/commandline/image_prune/
[docker-docs-prune-system]: https://docs.docker.com/engine/reference/commandline/system_prune/
[docker-prune-dangling]: https://stackoverflow.com/questions/45142528/what-is-a-dangling-image-and-what-is-an-unused-image/60756668#60756668
