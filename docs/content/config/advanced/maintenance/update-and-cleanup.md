---
title: 'Maintenance | Update and Cleanup'
---

[`ghcr.io/nickfedor/watchtower`][watchtower::registry] is a service that monitors Docker images for updates on the same tag used, automatically updating and restarting running containers. This is useful for images like DMS that support semver tags.

!!! example "Automatic image updates + cleanup"

    Run a `watchtower` container with access to `docker.sock`, enabling the service to manage Docker:

    ```yaml title="compose.yaml"
    services:
      watchtower:
        image: ghcr.io/nickfedor/watchtower:latest
        # Automatic cleanup:
        environment:
          - WATCHTOWER_CLEANUP=true
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock
    ```

    The `watchtower` container can use the [`WATCHTOWER_CLEANUP=true` ENV (CLI option: `--cleanup`)][watchtower-docs::cleanup] to enable automatic cleanup (removal) of the previous image used for container it updates. Removal occurs after the container is restarted with the new image pulled.

    !!! info "`containrrr/watchtower` is unmaintained"

        The [original project (`containrrr/watchtower`)][watchtower::original] has not received maintenance over recent years and was [archived in Dec 2025][watchtower::archived].

        A [community fork (`nicholas-fedor/watchtower`)][watchtower::community-fork] has since established itself as a maintained successor.

!!! tip "The image tag used for a container is monitored for updates (eg: `:latest`, `:edge`, `:16`)"

    The automatic update support is **only for updates to that specific image tag**.

    ---

    The tag for an image is never modified by `watchtower`, instead `watchtower` monitors the image digest associated to that image tag (_which will change to a new image digest if a new image release reassigns the tag_), when the digest for the tag changes this triggers a pull of the new image.

    - Your container will not update to a new major release version (_unless using `:latest`_).
    - Omit the minor or patch portion of a semver tag to receive updates for the omitted portion (_eg: `:16` will represent the latest minor + patch release, whereas `:16.0` would only receive patch updates instead of minor releases like `16.1`_).

!!! tip "Updating only specific containers"

    By default the `watchtower` service will check every 24 hours for new image updates to pull, based on currently running containers (_**not restricted** to only those running within your `compose.yaml`_).

    Images eligible for updates can configured with a [custom `command`][docker-docs::compose-command] that provides a list of container names, alternatively via [container labels to monitor only specific containers][watchtower-docs::monitor-labels] (_or instead exclude specific containers from monitoring_).

!!! info "Manual cleanup"

    `watchtower` supports running on-demand with `docker run` or `compose.yaml` via the [`WATCHTOWER_RUN_ONCE=true` ENV (CLI option: `--run-once`)][watchtower-docs::run-once]. You can either use this for manual or scheduled update + cleanup, instead of running as a background service.

    ---

    Without `watchtower` handling image cleanup, you can alternatively invoke cleanup of Docker storage directly with:

    - [`docker image prune --all`][docker-docs::prune-image]
    - [`docker system prune --all`][docker-docs::prune-system] (_also removes unused containers, networks, build cache_).

    If you omit the `--all` option, this will instead only remove ["dangling" content][docker::prune-dangling] (_eg: Orphaned images_).

[watchtower::registry]: https://github.com/nicholas-fedor/watchtower/pkgs/container/watchtower
[watchtower::original]: https://github.com/containrrr/watchtower
[watchtower::archived]: https://github.com/containrrr/watchtower/discussions/2135
[watchtower::community-fork]: https://github.com/nicholas-fedor/watchtower
[watchtower-docs::cleanup]: https://watchtower.nickfedor.com/v1.13.1/configuration/arguments/#cleanup_old_images
[watchtower-docs::run-once]: https://watchtower.nickfedor.com/v1.13.1/configuration/arguments/#run_once
[watchtower-docs::monitor-labels]: https://watchtower.nickfedor.com/v1.13.1/configuration/container-selection

[docker-docs::compose-command]: https://docs.docker.com/compose/compose-file/05-services/#command
[docker-docs::prune-image]: https://docs.docker.com/engine/reference/commandline/image_prune/
[docker-docs::prune-system]: https://docs.docker.com/engine/reference/commandline/system_prune/
[docker::prune-dangling]: https://stackoverflow.com/questions/45142528/what-is-a-dangling-image-and-what-is-an-unused-image/60756668#60756668
