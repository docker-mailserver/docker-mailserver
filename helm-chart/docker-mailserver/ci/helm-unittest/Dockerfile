FROM golang:1.10.3-alpine3.7 as ALPINE-BUILDER
RUN apk --no-cache add --quiet alpine-sdk=0.5-r0
WORKDIR /go/src/github.com/lrills/helm-unittest/
COPY . .
RUN install -d /opt && make install HELM_PLUGIN_DIR=/opt

FROM alpine:3.7 as ALPINE
COPY --from=ALPINE-BUILDER /opt /opt
