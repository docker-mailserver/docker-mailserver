---
title: 'Tutorials | Docker Build'
---

## Building your own Docker image

### Submodules

You'll need to retrieve the git submodules prior to building your own Docker image. From within your copy of the git repo run the following to retrieve the submodules and build the Docker image:

```sh
git submodule update --init --recursive
docker build -t mailserver/docker-mailserver .
```

Or, you can clone and retrieve the submodules in one command:

```sh
git clone --recurse-submodules https://github.com/docker-mailserver/docker-mailserver
```

Retrieving the git submodules will fix the error:

```txt
COPY failed: file not found in build context or excluded by .dockerignore: stat target/docker-configomat/configomat.sh: file does not exist
```

### About Docker

#### Version

We make use of build-features that require a recent version of Docker. Depending on your distribution, please have a look at [the official installation documentation for Docker](https://docs.docker.com/engine/install/) to get the latest version. Otherwise, you may encounter issues, for example with the `--link` flag for a [`#!dockerfile COPY`](https://docs.docker.com/engine/reference/builder/#copy) command.

#### Environment

If you are not using `make` to build the image, note that you will need to provide `DOCKER_BUILDKIT=1` to the `docker build` command for the build to succeed.

#### Build Arguments

The `Dockerfile` takes additional, so-called build arguments. These are

1. `VCS_VERSION`: the image version (default = edge)
2. `VCS_REVISION`: the image revision (default = unknown)

When using `make` to build the image, these are filled with proper values. You can build the image without supplying these arguments just fine though.

