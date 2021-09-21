---
title: 'Tutorials | Docker Build'
---

## Building your own Docker image

You'll need to retrieve the git submodules prior to building your own Docker image. From within your copy of the git repo and build the Docker image, run:

```sh
git submodule update --init --recursive
docker build .
```

Or, you can clone and retrieve the submodules in one command:
```sh
git clone --recurse-submodules https://github.com/docker-mailserver/docker-mailserver
```

Retrieving the git submodules will fix the error:
```
COPY failed: file not found in build context or excluded by .dockerignore: stat target/docker-configomat/configomat.sh: file does not exist
```
