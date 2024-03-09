---
title: 'Advanced | Kubernetes'
---

## Introduction

This article describes how to deploy DMS to Kubernetes. We highly recommend everyone to use the [Helm chart that we develop in a separate repository][github-web::docker-mailserver-helm].

!!! attention "Requirements"

    1. Basic knowledge about Kubernetes from the reader.
    2. A basic understanding of mail servers.
    3. Ideally, the reader has deployed DMS before in an easier setup (with Docker or Docker Compose).

!!! warning "Limited Support"

    We do **not officially support** Kubernetes, i.e., this content is entirely community-supported. If you find errors, please open an issue and raise  a PR.

## Manually Writing Manifests

When you do not want to or you cannot use Helm, below is a simple starting point for writing your YAML manifests.

=== "`ConfigMap`"

    Provide the basic configuration via environment variables with a `ConfigMap`. Note that this is just an example configuration; tune the `ConfigMap` to your needs.

    ```yaml
    ---
    apiVersion: v1
    kind: ConfigMap

    metadata:
      name: mailserver.environment

    immutable: false

    data:
      TLS_LEVEL: modern
      POSTSCREEN_ACTION: drop
      OVERRIDE_HOSTNAME: mail.example.com
      FAIL2BAN_BLOCKTYPE: drop
      POSTMASTER_ADDRESS: postmaster@example.com
      UPDATE_CHECK_INTERVAL: 10d
      POSTFIX_INET_PROTOCOLS: ipv4
      ENABLE_CLAMAV: '1'
      ENABLE_POSTGREY: '0'
      ENABLE_FAIL2BAN: '1'
      AMAVIS_LOGLEVEL: '-1'
      SPOOF_PROTECTION: '1'
      MOVE_SPAM_TO_JUNK: '1'
      ENABLE_UPDATE_CHECK: '1'
      ENABLE_SPAMASSASSIN: '1'
      SUPERVISOR_LOGLEVEL: warn
      SPAMASSASSIN_SPAM_TO_INBOX: '1'

      # here, we provide an example for the SSL configuration
      SSL_TYPE: manual
      SSL_CERT_PATH: /secrets/ssl/rsa/tls.crt
      SSL_KEY_PATH: /secrets/ssl/rsa/tls.key
    ```

    You can also make use of user-provided configuration files (_e.g. `user-patches.sh`, `postfix-accounts.cf` and more_), to customize DMS to your needs. Here is a minimal example that supplies a `postfix-accounts.cf` file inline with two users:

    ```yaml
    ---
    apiVersion: v1
    kind: ConfigMap

    metadata:
      name: mailserver.files

    data:
      postfix-accounts.cf: |
        test@example.com|{SHA512-CRYPT}$6$someHashValueHere
        other@example.com|{SHA512-CRYPT}$6$someOtherHashValueHere
    ```

    !!! attention "Static Configuration"

        With the inline `postfix-accounts.cf` file configured above, the content is fixed: you cannot change the configuration or persists modifications, i.e. adding or removing accounts is not possible. You need to use a `PersistentVolumeClaim` in case `postfix-accounts.cf` cannot be static.

        For production deployments, use persistent volumes instead to support dynamic config files.

    !!! tip "Modularize your `ConfigMap`"

        [Kustomize][kustomize] can be a useful tool as it supports creating a `ConfigMap` from multiple files.

=== "`PersistentVolumeClaim`"

    To persist data externally from the DMS container, configure a `PersistentVolumeClaim` (PVC). Make sure you have a storage system (like Longhorn, Rook, etc.) and that you choose the correct `storageClassName` (according to your storage system).

    ```yaml
    ---
    apiVersion: v1
    kind: PersistentVolumeClaim

    metadata:
      name: data

    spec:
      storageClassName: local-path
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 25Gi
    ```

=== "`Service`"

    A [`Service`][Kubernetes-network-service] is required for getting the traffic to the pod itself. It configures a load balancer with the ports you'll need.

    The configuration for a `Service` affects if the original IP from a connecting client is preserved (_this is important_). [More about this further down below](#exposing-your-mail-server-to-the-outside-world).

    ```yaml
    ---
    apiVersion: v1
    kind: Service

    metadata:
      name: mailserver
      labels:
        app: mailserver

    spec:
      type: LoadBalancer

      selector:
        app: mailserver

      ports:
        # smtp
        - name: smtp
          port: 25
          targetPort: smtp
          protocol: TCP
        # submissions (ESMTP with implicit TLS)
        - name: submission
          port: 465
          targetPort: submissions
          protocol: TCP
        # submission (ESMTP with explicit TLS)
        - name: submission
          port: 587
          targetPort: submission
          protocol: TCP
        # imaps (implicit TLS)
        - name: imaps
          port: 993
          targetPort: imaps
          protocol: TCP
    ```

=== "Certificates"

    In this example, we use [`cert-manager`][cert-manager] to supply RSA certificates. You can also supply RSA certificates as fallback certificates, which DMS supports out of the box with `SSL_ALT_CERT_PATH` and `SSL_ALT_KEY_PATH`, and provide ECDSA as the proper certificates.

    ```yaml
    ---
    apiVersion: cert-manager.io/v1
    kind: Certificate

    metadata:
      name: mail-tls-certificate-rsa

    spec:
      secretName: mail-tls-certificate-rsa
      isCA: false
      privateKey:
        algorithm: RSA
        encoding: PKCS1
        size: 2048
      dnsNames: [mail.example.com]
      issuerRef:
        name: mail-issuer
        kind: Issuer
    ```

    !!! attention

        You will need to have [`cert-manager`][cert-manager] configured. Especially the issue will need to be configured. Since we do not know how you want or need your certificates to be supplied, we do not provide more configuration here. The documentation for [`cert-manager`][cert-manager] is excellent.

=== "Sensitive Data"

    !!! attention "Sensitive Data"

        For storing OpenDKIM keys, TLS certificates or any sort of sensitive data, you should be using `Secret`s. You can mount secrets like `ConfigMap`s and use them the same way.

    The [TLS docs page][docs-tls] provides guidance when it comes to certificates and transport layer security. Always provide sensitive information via `Secrets`.

=== "`Deployment`"

    The `Deployment` config is the most complex component.

    - It instructs Kubernetes how to run the DMS container and how to apply your `ConfigMap`s, persisted storage, etc.
    - Additional options can be set to enforce runtime security.

    ```yaml
    ---
    apiVersion: apps/v1
    kind: Deployment

    metadata:
      name: mailserver

      annotations:
        ignore-check.kube-linter.io/run-as-non-root: >-
          'mailserver' needs to run as root
        ignore-check.kube-linter.io/privileged-ports: >-
          'mailserver' needs privileged ports
        ignore-check.kube-linter.io/no-read-only-root-fs: >-
          There are too many files written to make the root FS read-only

    spec:
      replicas: 1
      selector:
        matchLabels:
          app: mailserver

      template:
        metadata:
          labels:
            app: mailserver

          annotations:
            container.apparmor.security.beta.kubernetes.io/mailserver: runtime/default

        spec:
          hostname: mail
          containers:
            - name: mailserver
              image: ghcr.io/docker-mailserver/docker-mailserver:latest
              imagePullPolicy: IfNotPresent

              securityContext:
                # `allowPrivilegeEscalation: true` is required to support SGID via the
                # `postdrop` executable in `/var/mail-state` for Postfix (maildrop + public dirs):
                # https://github.com/docker-mailserver/docker-mailserver/pull/3625
                allowPrivilegeEscalation: true
                readOnlyRootFilesystem: false
                runAsUser: 0
                runAsGroup: 0
                runAsNonRoot: false
                privileged: false
                capabilities:
                  add:
                    # file permission capabilities
                    - CHOWN
                    - FOWNER
                    - MKNOD
                    - SETGID
                    - SETUID
                    - DAC_OVERRIDE
                    # network capabilities
                    - NET_ADMIN  # needed for F2B
                    - NET_RAW    # needed for F2B
                    - NET_BIND_SERVICE
                    # miscellaneous  capabilities
                    - SYS_CHROOT
                    - KILL
                  drop: [ALL]
                seccompProfile:
                  type: RuntimeDefault

              # Tune this to your needs.
              # If you disable ClamAV, you can use less RAM and CPU.
              # This becomes important in case you're low on resources
              # and Kubernetes refuses to schedule new pods.
              resources:
                limits:
                  memory: 4Gi
                  cpu: 1500m
                requests:
                  memory: 2Gi
                  cpu: 600m

              volumeMounts:
                - name: files
                  subPath: postfix-accounts.cf
                  mountPath: /tmp/docker-mailserver/postfix-accounts.cf
                  readOnly: true

                # PVCs
                - name: data
                  mountPath: /var/mail
                  subPath: data
                  readOnly: false
                - name: data
                  mountPath: /var/mail-state
                  subPath: state
                  readOnly: false
                - name: data
                  mountPath: /var/log/mail
                  subPath: log
                  readOnly: false

                # certificates
                - name: certificates-rsa
                  mountPath: /secrets/ssl/rsa/
                  readOnly: true

                # other
                - name: tmp-files
                  mountPath: /tmp
                  readOnly: false

              ports:
                - name: smtp
                  containerPort: 25
                  protocol: TCP
                - name: submissions
                  containerPort: 465
                  protocol: TCP
                - name: submission
                  containerPort: 587
                - name: imaps
                  containerPort: 993
                  protocol: TCP

              envFrom:
                - configMapRef:
                    name: mailserver.environment

          restartPolicy: Always

          volumes:
            # configuration files
            - name: files
              configMap:
                name: mailserver.files

            # PVCs
            - name: data
              persistentVolumeClaim:
                claimName: data

            # certificates
            - name: certificates-rsa
              secret:
                secretName: mail-tls-certificate-rsa
                items:
                  - key: tls.key
                    path: tls.key
                  - key: tls.crt
                    path: tls.crt

            # other
            - name: tmp-files
              emptyDir: {}
    ```

## Exposing your Mail Server to the Outside World

The more difficult part with Kubernetes is to expose a deployed DMS instance to the outside world. Kubernetes provides multiple ways for doing that; each has its upsides and downsides.

The major problem with exposing DMS to the outside world in Kubernetes is to [preserve the real client IP][Kubernetes-service-source-ip]. The real client IP is required by DMS for performing IP-based DNS and spam checks.

=== "Load-Balancer + Public IP"

    **General**

    !!! info

        This approach only works when:

        1. You can dedicate a **publicly routable IP** address to the DMS configured `Service` (_e.g. with a load balancer like [MetalLB][metallb-web]_).
        2. The publicly routable IP is required to be dedicated to allow your mail server to have matching `A` and `PTR` records (_which other mail servers will use to verify trust when they receive mail sent from your DMS instance_).

    In this setup, you configure a load balancer to give the DMS configured `Service` a dedicated, publicly routable IP address.

    **Example**

    The setup differs depending on the load balancer you use; we provide an example for [MetalLb][metallb-web]:

    ```yaml
    ---
    apiVersion: v1
    kind: Service

    metadata:
      name: mailserver
      labels:
        app: mailserver
      annotations:
        metallb.universe.tf/address-pool: mailserver

    # ...

    ---
    apiVersion: metallb.io/v1beta1
    kind: IPAddressPool

    metadata:
      name: mail
      namespace: metallb-system

    spec:
      addresses: [ <YOUR PUBLIC, DEDICATED IP IN CIDR NOTATION> ]
      autoAssign: true

    ---
    apiVersion: metallb.io/v1beta1
    kind: L2Advertisement

    metadata:
      name: mail
      namespace: metallb-system

    spec:
      ipAddressPools: [ mailserver ]
    ```

    **Advantages / Disadvantages**

    - :+1: simple
    - :-1: requires a dedicated, publicly routable IP address
    - :-1: limited to the node with the dedicated IP address
    - :point_right: requires the setup of a load balancer

=== "External-IP Service"

    **General**

    !!! info

        This approach only works when:

        1. You can dedicate a **publicly routable IP** address to the DMS configured `Service`.
        2. The publicly routable IP is required to be dedicated to allow your mail server to have matching `A` and `PTR` records (_which other mail servers will use to verify trust when they receive mail sent from your DMS instance_).

    In this setup, you set up the DMS configured `Service` manually with an "[external IP][Kubernetes-network-external-ip]", providing the dedicated, publicly routable IP address yourself.

    This approach is very similar to the approach that uses a load balancer and a public IP address.

    **Example**

    ```yaml
    ---
    apiVersion: v1
    kind: Service

    metadata:
      name: mailserver
      labels:
        app: mailserver

    spec:
      selector:
        app: mailserver
      ports:
        - name: smtp
          port: 25
          targetPort: smtp
        # ...

      externalIPs:
        - 10.20.30.40
    ```

    **Advantages / Disadvantages**

    - :+1: simple
    - :-1: requires a dedicated, publicly routable IP address
    - :-1: limited to the node with the dedicated IP address
    - :point_right: requires manually setting the IP

=== "Host network"

    **General**

    One way to also preserve the real client IP is to use `hostPort` and `hostNetwork: true`. This approach is similar to host network in Docker.

    **Example**

    ```yaml
    ---
    apiVersion: apps/v1
    kind: Deployment

    metadata:
      name: mailserver

    # ...
        spec:
          hostNetwork: true

        # ...
          containers:
            # ...
              ports:
                - name: smtp
                  containerPort: 25
                  hostPort: 25
                - name: submissions
                  containerPort: 465
                  hostPort: 587
                - name: 465
                  containerPort: 587
                  hostPort: 587
                - name: imaps
                  containerPort: 993
                  hostPort: 993
            #  ...
    ```

    **Advantages / Disadvantages**

    - :+1: simple
    - :-1: requires the node to have a dedicated, publicly routable IP address
    - :-1: limited to the node with the dedicated IP address
    - :-1: it is not possible to access DMS via other cluster nodes, only via the node that DMS was deployed on
    - :-1: every Port within the container is exposed on the host side

=== "Using the PROXY Protocol"

    **General**

    PROXY protocol is a network protocol for preserving a client’s IP address when the client’s TCP connection passes through a proxy. You can use a compatible proxy that supports PROXY protocol (NGINX, HAProxy, Traefik), a proxy that may already be the ingress in your cluster, to also accept and forward connections for DMS.

    ```mermaid
    flowchart LR
        A(External Mail Server) -->|Incoming connection| B
        subgraph cluster
        B("Ingress Acting as a Proxy") -->|PROXY protocol connection| C(DMS)
        end
    ```

    !!! tip "For more information on the PROXY protocol, refer to [our dedicated docs page][docs-mailserver-behind-proxy] on the feature."

    **Advantages / Disadvantages**

    - :+1: preserves the origin IP address of clients (_which is crucial for DNS related checks_);
    - :+1: aligns with a best practice for Kubernetes by using a dedicated ingress to route external traffic to the k8s cluster (_which additionally benefits from the flexibility of routing rules_); and
    - :+1: avoids the restraint of a single [node][Kubernetes-nodes] (_as a workaround to preserve the original client IP_).
    - :-1: added complexity
        - on the manifest side: changing the DMS configured `Service`
        - on DMS' side: changing the Postfix and Dovecot configuration
    - :-1: if you want to have cluster-internal traffic remain cluster-internal, you will need to "duplicate" the ports for Postfix and Dovecot to have ports that are PROXY-protocol enabled and ports that remain "normal"

    **Examples**

    A complete configuration, with duplicated ports, can be found down below in the "Traefik" section.

    === "Traefik"

        On Traefik's side, the configuration is very simple.

        - Create an entrypoint for each port that you want to expose (_probably 25, 465, 587 and 993_). Each entrypoint has a `IngressRouteTCP` configure a route to the appropriate internal port that supports PROXY protocol connections.
        - The below snippet demonstrates an example for two entrypoints, `submissions` (port 465) and `imaps` (port 993).

        ```yaml
        ---
        apiVersion: v1
        kind: Service

        metadata:
          name: mailserver

        # ...

        spec:
          # This an optimization to get rid of additional routing steps.
          type: ClusterIP # previously "LoadBalancer"

        # ...

        ---
        apiVersion: traefik.io/v1alpha1
        kind: IngressRouteTCP

        metadata:
          name: smtp

        spec:
          entryPoints: [ submissions ]
          routes:
            - match: HostSNI(`*`)
              services:
                - name: mailserver
                  namespace: mail
                  port: subs-proxy # note the 15 character limit here
                  proxyProtocol:
                    version: 2

        ---
        apiVersion: traefik.io/v1alpha1
        kind: IngressRouteTCP

        metadata:
          name: imaps

        spec:
          entryPoints: [ imaps ]
          routes:
            - match: HostSNI(`*`)
              services:
                - name: mailserver
                  namespace: mail
                  port: imaps-proxy
                  proxyProtocol:
                    version: 2
        ```

        !!! info

            The `IngressRouteTCP` example configs above reference ports with a `*-proxy` suffix.

            - These port variants will be defined in the `Deployment` configuration, and are scoped to the `mailserver` service (via `spec.routes.services.name`).
            - The suffix is used to distinguish that these ports are only compatible with connections using the PROXY protocol, which is what your ingress controller should be managing for you by adding the correct PROXY protocol headers to TCP connections it routes to DMS.

        !!! warning "Connections to DMS within the internal cluster will be rejected"

            The services for these ports can only enable PROXY protocol support by mandating the protocol on all connections for these ports.

            This can be problematic when you also need to support internal cluster traffic directly to DMS (_instead of routing indirectly through the ingress controller_).

        === "Only accept connections with PROXY protocol"

            Here is an example configuration for [Postfix][docs-postfix], [Dovecot][docs-dovecot], and the adjustments to the `Deployment` config. The port names are adjusted here only for the additional context as described previously.

            ```yaml
            kind: ConfigMap
            apiVersion: v1
            metadata:
              name: mailserver-extra-config
              labels:
                app: mailserver
            data:
              postfix-main.cf: |
                postscreen_upstream_proxy_protocol = haproxy
              postfix-master.cf: |
                smtp/inet/postscreen_upstream_proxy_protocol=haproxy
                submission/inet/smtpd_upstream_proxy_protocol=haproxy
                submissions/inet/smtpd_upstream_proxy_protocol=haproxy
              dovecot.cf: |
                haproxy_trusted_networks = <YOUR POD CIDR>
                service imap-login {
                  inet_listener imap {
                    haproxy = yes
                  }
                  inet_listener imaps {
                    haproxy = yes
                  }
                }
            # ...

            ---
            kind: Deployment
            apiVersion: extensions/v1beta1
            metadata:
              name: mailserver
            spec:
              template:
                spec:
                  containers:
                    - name: docker-mailserver
                      # ...
                      ports:
                        - name: smtp-proxy
                          containerPort: 25
                          protocol: TCP
                        - name: subs-proxy
                          containerPort: 465
                          protocol: TCP
                        - name: sub-proxy
                          containerPort: 587
                          protocol: TCP
                        - name: imaps-proxy
                          containerPort: 993
                          protocol: TCP
                      # ...
                      volumeMounts:
                        - name: config
                          subPath: postfix-main.cf
                          mountPath: /tmp/docker-mailserver/postfix-main.cf
                          readOnly: true
                        - name: config
                          subPath: postfix-master.cf
                          mountPath: /tmp/docker-mailserver/postfix-master.cf
                          readOnly: true
                        - name: config
                          subPath: dovecot.cf
                          mountPath: /tmp/docker-mailserver/dovecot.cf
                          readOnly: true
            ```

        === "Separate PROXY protocol ports for ingress"

            Supporting internal cluster connections to DMS without using PROXY protocol requires both Postfix and Dovecot to be configured with alternative ports for each service port (_which only differ by enforcing PROXY protocol connections_).

            - The ingress controller will route public connections to the internal alternative ports for DMS (`*-proxy` variants).
            - Internal cluster connections will instead use the original ports configured for the DMS container directly (_which are private to the cluster network_).

            In this example we'll create a copy of the original service ports with PROXY protocol enabled, and increment the port number assigned by `10000. You could run each of these commands within an active DMS instance, but it would be more convenient to persist the modification via our `user-patches.sh` feature:

            ```bash
            #!/bin/bash

            # Duplicate the config for the submission(s) service ports (587 / 465) with adjustments for the PROXY ports (10587 / 10465) and `syslog_name` setting:
            postconf -Mf submission/inet | sed -e s/^submission/10587/ -e 's/submission/submission-proxyprotocol/' >> /etc/postfix/master.cf
            postconf -Mf submissions/inet | sed -e s/^submissions/10465/ -e 's/submissions/submissions-proxyprotocol/' >> /etc/postfix/master.cf
            # Enable PROXY Protocol support for these new service variants:
            postconf -P 10587/inet/smtpd_upstream_proxy_protocol=haproxy
            postconf -P 10465/inet/smtpd_upstream_proxy_protocol=haproxy

            # Create a variant for port 25 too (NOTE: Port 10025 is already assigned in DMS to Amavis):
            postconf -Mf smtp/inet | sed -e s/^smtp/12525/ >> /etc/postfix/master.cf
            # Enable PROXY Protocol support (different setting as port 25 is handled via postscreen), optionally configure a `syslog_name` to distinguish in logs:
            postconf -P 12525/inet/postscreen_upstream_proxy_protocol=haproxy 12525/inet/syslog_name=smtp-proxyprotocol
            ```

            For Dovecot, you can configure [`dovecot.cf`][docs-dovecot] to look like this:

            ```cf
            haproxy_trusted_networks = <YOUR POD CIDR>

            service imap-login {
              inet_listener imaps-proxied {
                haproxy = yes
                port = 10993
                ssl = yes
              }
            }
            ```

            Last but not least, the `ports` section in the `Deployment` needs to be extended:

            ```yaml
            - name: smtp-proxy
              containerPort: 10025
              protocol: TCP
            - name: subs-proxy
              containerPort: 10465
              protocol: TCP
            - name: sub-proxy
              containerPort: 10587
              protocol: TCP
            - name: imaps-proxy
              containerPort: 10993
              protocol: TCP
            ```

    === "NGINX"

        With an [NGINX ingress controller][Kubernetes-nginx], add the following to the TCP services config map (as described [here][Kubernetes-nginx-expose]):

        ```yaml
        25:  "mailserver/mailserver:25::PROXY"
        465: "mailserver/mailserver:465::PROXY"
        587: "mailserver/mailserver:587::PROXY"
        993: "mailserver/mailserver:993::PROXY"
        ```

[github-web::docker-mailserver-helm]: https://github.com/docker-mailserver/docker-mailserver-helm
[metallb-web]: https://metallb.universe.tf/

[kustomize]: https://kustomize.io/
[cert-manager]: https://cert-manager.io/docs/
[docs-tls]: ../security/ssl.md
[docs-dovecot]: ./override-defaults/dovecot.md
[docs-postfix]: ./override-defaults/postfix.md
[docs-mailserver-behind-proxy]: ../../examples/tutorials/mailserver-behind-proxy.md
[dockerhub-haproxy]: https://hub.docker.com/_/haproxy
[Kubernetes-nginx]: https://kubernetes.github.io/ingress-nginx
[Kubernetes-nginx-expose]: https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services
[Kubernetes-network-service]: https://kubernetes.io/docs/concepts/services-networking/service
[Kubernetes-network-external-ip]: https://kubernetes.io/docs/concepts/services-networking/service/#external-ips
[Kubernetes-nodes]: https://kubernetes.io/docs/concepts/architecture/nodes
[Kubernetes-proxy-service]: https://github.com/kubernetes/contrib/tree/master/for-demos/proxy-to-service
[Kubernetes-service-source-ip]: https://kubernetes.io/docs/tutorials/services/source-ip
