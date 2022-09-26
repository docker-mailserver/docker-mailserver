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

### Docker Version

We make use of build-features that require a recent version of Docker. Depending on your distribution, please have a look at [the official installation documentation for Docker](https://docs.docker.com/engine/install/) to get the latest version. Otherwise, you may encounter issues, for example with the `--link` flag for a `#!dockerfile COPY` command.
