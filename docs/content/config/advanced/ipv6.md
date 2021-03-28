---
title: 'Advanced | IPv6'
---

## Background

If your container host supports IPv6, then `docker-mailserver` will automatically accept IPv6 connections by way of the docker host's IPv6. However, incoming mail will fail SPF checks because they will appear to come from the IPv4 gateway that docker is using to proxy the IPv6 connection (`172.20.0.1` is the gateway).

This can be solved by supporting IPv6 connections all the way to the `docker-mailserver` container.

## Setup steps

```diff
+++ b/serv/docker-compose.yml
@@ -1,4 +1,4 @@
-version: '2'
+version: '2.1'

@@ -32,6 +32,16 @@ services:

+  ipv6nat:
+    image: robbertkl/ipv6nat
+    restart: always
+    network_mode: "host"
+    cap_add:
+      - NET_ADMIN
+      - SYS_MODULE
+    volumes:
+      - /var/run/docker.sock:/var/run/docker.sock:ro
+      - /lib/modules:/lib/modules:ro

@@ -306,4 +316,13 @@ networks:

+  default:
+    driver: bridge
+    enable_ipv6: true
+    ipam:
+      driver: default
+      config:
+        - subnet: fd00:0123:4567::/48
+          gateway: fd00:0123:4567::1
```

## Further Discussion

See [#1438][github-issue-1438]

[github-issue-1438]: https://github.com/docker-mailserver/docker-mailserver/issues/1438
