---
title: 'Advanced | Kubernetes'
---

## Introduction

This article describes how to deploy DMS to Kubernetes. We highly recommend everyone to use our community [DMS Helm chart][github-web::docker-mailserver-helm].

!!! note "Requirements"

    1. Basic knowledge about Kubernetes from the reader.
    2. A basic understanding of mail servers.
    3. Ideally, the reader has already deployed DMS before with a simpler setup (_`docker run` or Docker Compose_).

!!! warning "Limited Support"

    DMS **does not officially support Kubernetes**. This content is entirely community-supported. If you find errors, please open an issue and raise  a PR.

## Manually Writing Manifests

If using our Helm chart is not viable for you, here is some guidance to start with your own manifests.

<!-- This empty quote block is purely for a visual border -->
!!! quote ""

    === "`ConfigMap`"

        Provide the basic configuration via environment variables with a `ConfigMap`.

        !!! example

            Below is only an example configuration, adjust the `ConfigMap` to your own needs.

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

        You can also make use of user-provided configuration files (_e.g. `user-patches.sh`, `postfix-accounts.cf`, etc_), to customize DMS to your needs.

        ??? example "Providing config files"

            Here is a minimal example that supplies a `postfix-accounts.cf` file inline with two users:

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

            !!! warning "Static Configuration"

                The inline `postfix-accounts.cf` config example above provides file content that is static. It is mounted as read-only at runtime, thus cannot support modifications.

                For production deployments, use persistent volumes instead (via `PersistentVolumeClaim`). That will enable files like `postfix-account.cf` to add and remove accounts, while also persisting those changes externally from the container.

        !!! tip "Modularize your `ConfigMap`"

            [Kustomize][kustomize] can be a useful tool as it supports creating a `ConfigMap` from multiple files.

    === "`PersistentVolumeClaim`"

        To persist data externally from the DMS container, configure a `PersistentVolumeClaim` (PVC).

        Make sure you have a storage system (like Longhorn, Rook, etc.) and that you choose the correct `storageClassName` (according to your storage system).

        !!! example

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

        A [`Service`][k8s-docs::config::service] is required for getting the traffic to the pod itself. It configures a load balancer with the ports you'll need.

        The configuration for a `Service` affects if the original IP from a connecting client is preserved (_this is important_). [More about this further down below](#exposing-your-mail-server-to-the-outside-world).

        !!! example

            ```yaml
            ---
            apiVersion: v1
            kind: Service

            metadata:
              name: mailserver
              labels:
                app: mailserver

            spec:
              # `Local` is most likely required, otherwise every incoming request would be identified by the external IP,
              # which will get banned by Fail2Ban when monitored services are not configured for PROXY protocol
              externalTrafficPolicy: Local
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
                - name: submissions
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

    === "`Certificate`"

        !!! example "Using [`cert-manager`][cert-manager] to supply TLS certificates"

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

            The [TLS docs page][docs-tls] provides guidance when it comes to certificates and transport layer security.

        !!! tip "ECDSA + RSA (fallback)"

            You could supply RSA certificates as fallback certificates instead, with ECDSA as the primary. DMS supports dual certificates via the ENV `SSL_ALT_CERT_PATH` and `SSL_ALT_KEY_PATH`.

        !!! warning "Always provide sensitive information via a `Secret`"

            For storing OpenDKIM keys, TLS certificates, or any sort of sensitive data - you should be using `Secret`s.

            A `Secret` is similar to `ConfigMap`, it can be used and mounted as a volume as demonstrated in the [`Deployment` manifest][docs::k8s::config-deployment] tab.

    === "`Deployment`"

        The [`Deployment`][k8s-docs::config::deployment] config is the most complex component.

        - It instructs Kubernetes how to run the DMS container and how to apply your `ConfigMap`s, persisted storage, etc.
        - Additional options can be set to enforce runtime security.

        ???+ example

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
                        # `allowPrivilegeEscalation: true` is required to support SGID via the `postdrop`
                        # executable in `/var/mail-state` for Postfix (maildrop + public dirs):
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
            ```

## Exposing your Mail Server to the Outside World

The more difficult part with Kubernetes is to expose a deployed DMS instance to the outside world.

The major problem with exposing DMS to the outside world in Kubernetes is to [preserve the real client IP][k8s-docs::service-source-ip]. The real client IP is required by DMS for performing IP-based DNS and spam checks.

Kubernetes provides multiple ways to address this; each has its upsides and downsides.

<!-- This empty quote block is purely for a visual border -->
!!! quote ""

    === "Configure IP Manually"

        ???+ abstract "Advantages / Disadvantages"

            - [x] Simple
            - [ ] Requires the node to have a dedicated, publicly routable IP address
            - [ ] Limited to a single node (_associated to the dedicated IP address_)
            - [ ] Your deployment requires an explicit IP in your configuration (_or an entire Load Balancer_).

        !!! info "Requirements"

            1. You can dedicate a **publicly routable IP** address for the DMS configured `Service`.
            2. A dedicated IP is required to allow your mail server to have matching `A` and `PTR` records (_which other mail servers will use to verify trust when they receive mail sent from your DMS instance_).

        !!! example

            Assign the DMS `Service` an external IP directly, or delegate an LB to assign the IP on your behalf.

            === "External-IP Service"

                The DMS `Service` is configured with an "[external IP][k8s-docs::network-external-ip]" manually. Append your externally reachable IP address to `spec.externalIPs`.

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

            === "Load-Balancer"

                The config differs depending on your choice of load balancer. This example uses [MetalLB][metallb-web].

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
                  addresses: [ <YOUR PUBLIC DEDICATED IP IN CIDR NOTATION> ]
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

    === "Host network"

        ???+ abstract "Advantages / Disadvantages"

            - [x] Simple
            - [ ] Requires the node to have a dedicated, publicly routable IP address
            - [ ] Limited to a single node (_associated to the dedicated IP address_)
            - [ ] It is not possible to access DMS via other cluster nodes, only via the node that DMS was deployed on
            - [ ] Every port within the container is exposed on the host side

        !!! example

            Using `hostPort` and `hostNetwork: true` is a similar approach to [`network_mode: host` with Docker Compose][docker-docs::compose::network_mode].

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
                          hostPort: 465
                        - name: submission
                          containerPort: 587
                          hostPort: 587
                        - name: imaps
                          containerPort: 993
                          hostPort: 993
            ```

    === "Using the PROXY Protocol"

        ???+ abstract "Advantages / Disadvantages"

            - [x] Preserves the origin IP address of clients (_which is crucial for DNS related checks_)
            - [x] Aligns with a best practice for Kubernetes by using a dedicated ingress, routing external traffic to the k8s cluster (_with the benefits of flexible routing rules_)
            - [x] Avoids the restraint of a single [node][k8s-docs::nodes] (_as a workaround to preserve the original client IP_)
            - [ ] Introduces complexity by requiring:
                - A reverse-proxy / ingress controller (_potentially extra setup_)
                - Kubernetes manifest changes for the DMS configured `Service`
                - DMS configuration changes for Postfix and Dovecot
            - [ ] To keep support for direct connections to DMS services internally within cluster, service ports must be "duplicated" to offer an alternative port for connections using PROXY protocol
            - [ ] Custom Fail2Ban required: Because the traffic to DMS is now coming from the proxy, banning the origin IP address will have no effect; you'll need to implement a [custom solution for your setup][github-web::docker-mailserver::proxy-protocol-fail2ban].

        ??? question "What is the PROXY protocol?"

            PROXY protocol is a network protocol for preserving a client’s IP address when the client’s TCP connection passes through a proxy.

            It is a common feature supported among reverse-proxy services (_NGINX, HAProxy, Traefik_), which you may already have handling ingress traffic for your cluster.

            ```mermaid
            flowchart LR
                A(External Mail Server) -->|Incoming connection| B
                subgraph cluster
                B("Ingress Acting as a Proxy") -->|PROXY protocol connection| C(DMS)
                end
            ```

            For more information on the PROXY protocol, refer to [our dedicated docs page][docs-mailserver-behind-proxy] on the topic.

        ???+ example "Configure the Ingress Controller"

            === "Traefik"

                On Traefik's side, the configuration is very simple.

                - Create an entrypoint for each port that you want to expose (_probably 25, 465, 587 and 993_).
                - Each entrypoint should configure an [`IngressRouteTCP`][traefik-docs::k8s::ingress-route-tcp] that routes to the equivalent internal DMS `Service` port which supports PROXY protocol connections.

                The below snippet demonstrates an example for two entrypoints, `submissions` (port 465) and `imaps` (port 993).

                ```yaml
                ---
                apiVersion: v1
                kind: Service

                metadata:
                  name: mailserver

                spec:
                  # This an optimization to get rid of additional routing steps.
                  # Previously "type: LoadBalancer"
                  type: ClusterIP

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

                !!! info "`*-proxy` port name suffix"

                    The `IngressRouteTCP` example configs above reference ports with a `*-proxy` suffix.

                    - These port variants will be defined in the [`Deployment` manifest][docs::k8s::config-deployment], and are scoped to the `mailserver` service (via `spec.routes.services.name`).
                    - The suffix is used to distinguish that these ports are only compatible with connections using the PROXY protocol, which is what your ingress controller should be managing for you by adding the correct PROXY protocol headers to TCP connections it routes to DMS.

            === "NGINX"

                With an [NGINX ingress controller][k8s-docs::nginx], add the following to the TCP services config map (_as described [here][k8s-docs::nginx-expose]_):

                ```yaml
                25:  "mailserver/mailserver:25::PROXY"
                465: "mailserver/mailserver:465::PROXY"
                587: "mailserver/mailserver:587::PROXY"
                993: "mailserver/mailserver:993::PROXY"
                ```

        ???+ example "Adjust DMS config for Dovecot + Postfix"

            ??? warning "Only ingress should connect to DMS with PROXY protocol"

                While Dovecot will restrict connections via PROXY protocol to only clients trusted configured via `haproxy_trusted_networks`, Postfix does not have an equivalent setting. Public clients should always route through ingress to establish a PROXY protocol connection.

                You are responsible for properly managing traffic inside your cluster and to **ensure that only trustworthy entities** can connect to the designated PROXY protocol ports.

                With Kubernetes, this is usually the task of the CNI (_container network interface_).

            !!! tip "Advised approach"

                The _"Separate PROXY protocol ports"_ tab below introduces a little more complexity, but provides better compatibility for internal connections to DMS.

            === "Only accept connections with PROXY protocol"

                !!! warning "Connections to DMS within the internal cluster will be rejected"

                    The services for these ports can only enable PROXY protocol support by mandating the protocol on all connections for these ports.

                    This can be problematic when you also need to support internal cluster traffic directly to DMS (_instead of routing indirectly through the ingress controller_).

                Here is an example configuration for [Postfix][docs-postfix], [Dovecot][docs-dovecot], and the required adjustments for the [`Deployment` manifest][docs::k8s::config-deployment]. The port names are adjusted here only to convey the additional context described earlier.

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
                apiVersion: apps/v1
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
                            - name: imap-proxy
                              containerPort: 143
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

                !!! info

                    Supporting internal cluster connections to DMS without using PROXY protocol requires both Postfix and Dovecot to be configured with alternative ports for each service port (_which only differ by enforcing PROXY protocol connections_).

                    - The ingress controller will route public connections to the internal alternative ports for DMS (`*-proxy` variants).
                    - Internal cluster connections will instead use the original ports configured for the DMS container directly (_which are private to the cluster network_).

                In this example we'll create a copy of the original service ports with PROXY protocol enabled, and increment the port number assigned by `10000`.

                Create a `user-patches.sh` file to apply these config changes during container startup:

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
                  inet_listener imap-proxied {
                    haproxy = yes
                    port = 10143
                  }

                  inet_listener imaps-proxied {
                    haproxy = yes
                    port = 10993
                    ssl = yes
                  }
                }
                ```

                Update the [`Deployment` manifest][docs::k8s::config-deployment] `ports` section by appending these new ports:

                ```yaml
                - name: smtp-proxy
                  # not 10025 in this example due to a possible clash with Amavis
                  containerPort: 12525
                  protocol: TCP
                - name: imap-proxy
                  containerPort: 10143
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

                !!! note

                    If you use other Dovecot ports (110, 995, 4190), you may want to configure those similar to above. The `dovecot.cf` config for these ports is [documented here][docs-mailserver-behind-proxy] (_in the equivalent section of that page_).

[docs::k8s::config-deployment]: #deployment
[docs-tls]: ../security/ssl.md
[docs-dovecot]: ./override-defaults/dovecot.md
[docs-postfix]: ./override-defaults/postfix.md
[docs-mailserver-behind-proxy]: ../../examples/tutorials/mailserver-behind-proxy.md

[github-web::docker-mailserver-helm]: https://github.com/docker-mailserver/docker-mailserver-helm
[docker-docs::compose::network_mode]: https://docs.docker.com/compose/compose-file/compose-file-v3/#network_mode
[kustomize]: https://kustomize.io/
[cert-manager]: https://cert-manager.io/docs/
[metallb-web]: https://metallb.universe.tf/

[k8s-docs::config::service]: https://kubernetes.io/docs/concepts/services-networking/service
[k8s-docs::config::deployment]: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#creating-a-deployment
[k8s-docs::nodes]: https://kubernetes.io/docs/concepts/architecture/nodes
[k8s-docs::nginx]: https://kubernetes.github.io/ingress-nginx
[k8s-docs::nginx-expose]: https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services
[k8s-docs::service-source-ip]: https://kubernetes.io/docs/tutorials/services/source-ip
[k8s-docs::network-external-ip]: https://kubernetes.io/docs/concepts/services-networking/service/#external-ips

[traefik-docs::k8s::ingress-route-tcp]: https://doc.traefik.io/traefik/routing/providers/kubernetes-crd/#kind-ingressroutetcp
[github-web::docker-mailserver::proxy-protocol-fail2ban]: https://github.com/docker-mailserver/docker-mailserver/issues/1761#issuecomment-2016879319
