---
title: 'Tutorials | Docker Build'
---

## Building your own Docker image

### Submodules

You'll need to retrieve the git submodules prior to building your own Docker image. From within your copy of the git repo run the following to retrieve the submodules and build the Docker image:

```sh
git submodule update --init --recursive
docker build --tag <YOUR CUSTOM IMAGE NAME> .
```

Or, you can clone and retrieve the submodules in one command:

```sh
git clone --recurse-submodules https://github.com/docker-mailserver/docker-mailserver
```

### About Docker

#### Minimum supported version

We make use of build features that require a recent version of Docker. v23.0 or newer is advised, but earlier releases may work.

- To get the latest version for your distribution, please have a look at [the official installation documentation for Docker](https://docs.docker.com/engine/install/).
- If you are using a version of Docker prior to v23.0, you will need to enable BuildKit via the ENV [`DOCKER_BUILDKIT=1`](https://docs.docker.com/build/buildkit/#getting-started).

#### Build Arguments (Optional)

The `Dockerfile` includes several build [`ARG`][docker-docs::builder-arg] instructions that can be configured:

- `DOVECOT_COMMUNITY_REPO`: Install Dovecot from the community repo instead of from Debian (default = 0) 
- `DMS_RELEASE`: The image version (default = edge)
- `VCS_REVISION`: The git commit hash used for the build (default = unknown)

!!! note

    - `DMS_RELEASE` (_when not `edge`_) will be used to check for updates from our GH releases page at runtime due to the default feature [`ENABLE_UPDATE_CHECK=1`][docs::env-update-check].
    - Both `DMS_RELEASE` and `VCS_REVISION` are also used with `opencontainers` metadata [`LABEL`][docker-docs::builder-label] instructions.

[docs::env-update-check]: https://docker-mailserver.github.io/docker-mailserver/latest/config/environment/#enable_update_check
[docker-docs::builder-arg]: https://docs.docker.com/engine/reference/builder/#using-arg-variables
[docker-docs::builder-label]: https://docs.docker.com/engine/reference/builder/#label
