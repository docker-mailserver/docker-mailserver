# Docker Usage Guide

- [Docker Usage Guide](#docker-usage-guide)
  * [Basic Usage](#basic-usage)
  * [Docker Gotchas](#docker-gotchas)
  * [Extending from the base image](#extending-from-the-base-image)
  
## Basic Usage

To build and run `bats`' own tests:
```bash
$ git clone https://github.com/bats-core/bats-core.git
Cloning into 'bats-core'...
remote: Counting objects: 1222, done.
remote: Compressing objects: 100% (53/53), done.
remote: Total 1222 (delta 34), reused 55 (delta 21), pack-reused 1146
Receiving objects: 100% (1222/1222), 327.28 KiB | 1.70 MiB/s, done.
Resolving deltas: 100% (661/661), done.

$ cd bats-core/
$ docker build --tag bats:latest .
...
$ docker run -it bats:latest --formatter tap /opt/bats/test
```

To mount your tests into the container, first build the image as above. Then, for example with `bats`:
```bash
$ docker run -it -v "$PWD:/opt/bats" bats:latest /opt/bats/test
```
This runs the `test/` directory from the bats-core repository inside the bats Docker container.

For test suites that are intended to run in isolation from the project (i.e. the tests do not depend on project files outside of the test directory), you can mount the test directory by itself and execute the tests like so:

```bash
$ docker run -it -v "$PWD/test:/test" bats:latest /test
```

## Docker Gotchas

Relying on functionality provided by your environment (ssh keys or agent, installed binaries, fixtures outside the mounted test directory) will fail when running inside Docker. 

`--interactive`/`-i` attaches an interactive terminal and is useful to kill hanging processes (otherwise has to be done via docker stop command). `--tty`/`-t` simulates a tty (often not used, but most similar to test runs from a Bash prompt). Interactivity is important to a user, but not a build, and TTYs are probably more important to a headless build. Everything's least-surprising to a new Docker use if both are used.

## Extending from the base image

Docker operates on a principle of isolation, and bundles all dependencies required into the Docker image. These can be mounted in at runtime (for test files, configuration, etc). For binary dependencies it may be better to extend the base Docker image with further tools and files.

```dockerfile
FROM bats

RUN \ 
  apk \
  --no-cache \
  --update \
  add \
  openssh 

```
