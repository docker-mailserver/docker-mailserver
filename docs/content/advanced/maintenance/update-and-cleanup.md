# Automatic update

Docker images are handy but it can get a a hassle to keep them updated. Also when a repository is automated you want to get these images when they get out.

There is a nice docker image that solves this issue and can be very helpful. The image is: [v2tec/watchtower](https://hub.docker.com/r/v2tec/watchtower/).

A docker-compose example:
```yaml
services:
  watchtower:
    restart: always
    image: v2tec/watchtower:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

For more details see the [manual](https://github.com/v2tec/watchtower/blob/master/README.md)


***


# Automatic cleanup

When you are pulling new images in automaticly it is nice to have them cleaned as well. There is also a docker images for this (from Spotify). The image is: [spotify/docker-gc](https://hub.docker.com/r/spotify/docker-gc/).

A docker-compose example:
```yaml
services:
  docker-gc:
    restart: always
    image: spotify/docker-gc:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

For more details see the [manual](https://github.com/spotify/docker-gc/blob/master/README.md)
Or you can just use the "--cleanup" option on v2tec/watchtower. :-)