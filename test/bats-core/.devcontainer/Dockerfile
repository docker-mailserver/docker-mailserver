ARG bashver=latest

FROM bash:${bashver}

# Install parallel and accept the citation notice (we aren't using this in a
# context where it make sense to cite GNU Parallel).
RUN echo "@edgecomm http://dl-cdn.alpinelinux.org/alpine/edge/community"  >> /etc/apk/repositories && \
    apk update && \
    apk add --no-cache parallel ncurses shellcheck@edgecomm && \
    mkdir -p ~/.parallel && touch ~/.parallel/will-cite

RUN ln -s /opt/bats/bin/bats /usr/sbin/bats
COPY . /opt/bats/

ENTRYPOINT ["bash", "/usr/sbin/bats"]
