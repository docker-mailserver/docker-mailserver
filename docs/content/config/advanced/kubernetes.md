---
title: 'Advanced | Kubernetes'
---

## Introduction

This article describes how to deploy DMS to Kubernetes. We highly recommend everyone to use the [Helm chart that we develop in a separate repository][github-web::docker-mailserver-helm].

!!! attention "Requirements"

    1. We assume basic knowledge about Kubernetes from the reader.
    2. Moreover, we assume the reader to have a basic understanding of mail servers.
    3. Ideally, the reader has deployed DMS before in an easier setup (with Docker or Docker Compose).

!!! warning "Limited Support"

    We do **not officially support** Kubernetes, i.e., this content is entirely community-supported. If you find errors, please open an issue and raise  a PR.

## Manually Writing Manifests

When you do not want to or you cannot use Helm, we provide a simple starting point for writing YAML manifests now.

=== "`ConfigMap`"

    We can provide the basic configuration in the form of environment variables with a `ConfigMap`. Note that this is just an example configuration; tune the `ConfigMap` to your needs.

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

    We can also make use of user-provided configuration files, e.g. `user-patches.sh`, `postfix-accounts.cf` and more, to adjust DMS to our likings. We encourage you to have a look at [Kustomize][kustomize] for creating `ConfigMap`s from multiple files, but for now, we will provide a simple, hand-written example. This example is absolutely minimal and only goes to show what can be done.

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

        With the configuration shown above, you can **not** dynamically add accounts as the configuration file mounted into the mail server can not be written to.

        Use persistent volumes for production deployments.

=== "`PersistentVolumeClaim`"

    Thereafter, we need persistence for our data. Make sure you have a storage provisioner and that you choose the correct `storageClassName`.

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

    The `Service`'s configuration determines whether the original IP from the sender will be kept. [More about this further down below](#exposing-your-mail-server-to-the-outside-world). The configuration you're seeing does keep the original IP, but you will not be able to scale this way. We have chosen to go this route in this case because we think most Kubernetes users will only want to have one instance.

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

=== "`Deployment`"

    Last but not least, the `Deployment` becomes the most complex component. It instructs Kubernetes how to run the DMS container and how to apply your `ConfigMaps`, persisted storage, etc. Additionally, we can set options to enforce runtime security here.

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
          There are too many files written to make The
          root FS read-only

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
                # Required to support SGID via `postdrop` executable
                # in `/var/mail-state` for Postfix (maildrop + public dirs):
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

              # You want to tune this to your needs. If you disable ClamAV,
              #   you can use less RAM and CPU. This becomes important in
              #   case you're low on resources and Kubernetes refuses to
              #   schedule new pods.
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

    The [TLS docs page][docs-tls] provides guidance when it comes to certificates and transport layer security. Always provide sensitive information vai `Secrets`.

## Exposing your Mail Server to the Outside World

The more difficult part with Kubernetes is to expose a deployed DMS instance to the outside world. Kubernetes provides multiple ways for doing that; each has its upsides and downsides. The major problem with exposing DMS to the outside world in Kubernetes is to [preserve the real client IP][Kubernetes-service-source-ip]. The real client IP is required by DMS for performing IP-based DNS and spam checks.

=== "Load-Balancer + Public IP"

    This approach only works when you have a **dedicated** IP address that you can give to the responsible `Service`, e.g., with a load balancer like [MetalLB][metallb-web]. Such an IP has to be public and therefore routable. The IP is required to be dedicated to allow your mail server to have matching `A` and `PTR` records (that other mail server can checken when you send them e-mails).

    The upside is that the manifests files and the configuration do not become more complex; the downside is that you require a dedicated IPv4 address and you are stuck to the node that has this IP address bound.

=== "External-IP Service"

    Another simple way is to expose DMS as a `Service` with [external IPs][Kubernetes-network-external-ip]. This approach is very similar to the former approach. Here, an external IP is given to the service directly by you. With the approach above, you tell your load-balancer to do this.

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
        - 80.11.12.10
    ```

    This approach has the same upsides and downside as the former approach.

=== "Host network"

    One way to also preserve the real client IP is to use `hostPort` and `hostNetwork: true`. With this approach, you bind DMS to a specific node, but also benefit from reduced complexity. Moreover, it is not possible to access DMS via other cluster nodes, only via the node that DMS was deployed on. Additionally, every Port within the container is exposed on the host side.

    ```yaml
    ---
    apiVersion: extensions/v1beta1
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
                - name: smtp-auth
                  containerPort: 587
                  hostPort: 587
                - name: imap-secure
                  containerPort: 993
                  hostPort: 993
            #  ...
    ```

=== "Using the PROXY Protocol"

    **General**

    This approach might be the best approach out of all the approaches presented here, mainly because

    1. you keep the origin IP addresses, which is crucial for DNS-based checks,
    2. you align with Kubernete's idea of using a dedicated ingress for traffic that flows from outside the cluster to the inside of the cluster, therefore also benefitting from rules applied on the way, and
    3. you are not bound a specific node.

    The PROXY protocol "wraps" incoming flows and marks them as "wrapped". This allows DMS to "unwrap" the packages and work with the original IP addresses.

    Additional documentation, independent of Kubernetes, can be found [here][docs-mailserver-behind-proxy].

    **Drawbacks**

    Using the PROXY protocol comes at the cost of added complexity, both on the manifest side as well as on the configuration side of DMS itself. Additionally, if you want to have cluster-internal traffic remain cluster-internal, you will need to "duplicate" the ports for Postfix and Dovecot to have ports that are PROXY-protocol enabled and ports that remain "normal". Such a configuration, with duplicated ports, can be found down below in the "Traefik" section.

    === "NGINX"

        With an [NGINX ingress controller][Kubernetes-nginx], add the following to the TCP services config map (as described [here][Kubernetes-nginx-expose]):

        ```yaml
        25:  "mailserver/mailserver:25::PROXY"
        465: "mailserver/mailserver:465::PROXY"
        587: "mailserver/mailserver:587::PROXY"
        993: "mailserver/mailserver:993::PROXY"
        ```

    === "HAProxy"

        !!! help "HAProxy"
            With [HAProxy][dockerhub-haproxy], the configuration should look similar to the above. If you know what it actually looks like, add an example here. :smiley:

    === "Traefik"

        On Traefik's side, the configuration is very simple. You need to create entrypoints for all ports that you want to expose (probably 25, 465, 587 and 993). Then, you can refer to them in `IngressRouteTCP`s. We use the `submissions` entrypoint for port 465 and the `imaps` entrypoint for port 993 here as an example.

        ```yaml
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

        The `*-proxy` ports that we refer to in the `IngressRouteTCP`s are configured on the `mailserver` service, and these ports refer to the `Deployment`'s ports again. One has two options for configuring the `mailserver` service now:

        1. In case you do not need cluster-internal e-mails to reach DMS on default ports, you can simply change existing port configurations to use the PROXY protocol.
        2. In case you do need (or want) cluster-internal e-mails to reach DMS on default ports, you need to duplicate port configurations in order to open PROXY-protocol-aware ports and non-PROXY-protocol-aware ports.

        === "Cluster-Internal E-Mails Not Required"

            Here is an exmaple configuration for [Postfix][docs-postfix], [Dovecot][docs-dovecot], and the `Deployment`:

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
                haproxy_trusted_networks = <YOUR POD CIDR>, 127.0.0.0/8
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

        === "Cluster-Internal E-Mails Required"

            We can keep the default configuration, but we need to duplicate it and change port numbers. In this example, we add 10000 to the port numbers to get the PROXY-protocol-enabled ports. If you have an already running instance, you can run the following inside the DMS container to get the duplicated ports:

            ```bash
            # Duplicate the config for the submission(s) service ports (587/465)
            # with adjustments for the proxy ports (10587/10465) and syslog_name setting:
            postconf -Mf submissions/inet | sed -e s/^submissions/10465/ -e 's/submissions/submissions-proxyprotocol/'
            postconf -Mf submission/inet | sed -e s/^submission/10587/ -e 's/submission/submission-proxyprotocol/'

            # Create a variant for port 25 too (NOTE: Port 10025 is already assigned
            # in DMS to Amavis IF you are using Amavis):
            postconf -Mf smtp/inet | sed 's/^smtp/12525/'
            ```

            For ports 10465 and 10587, you also need `smtpd_upstream_proxy_protocol=haproxy` in Postfix's `master.cf`. Port 25 requires a slightly different setup because of Postscreen; add `postscreen_upstream_proxy_protocol=haproxy` and `syslog_name=smtp-proxyprotocol`.

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

[github-web::docker-mailserver-helm]: https://github.com/docker-mailserver/docker-mailserver-helm
[metallb-web]: https://metallb.universe.tf/

[kustomize]: https://kustomize.io/
[cert-manager]: https://cert-manager.io/docs/
[docs-tls]: ../security/ssl.md
[docs-dovecot]: ./override-defaults/dovecot.md
[docs-postfix]: ./override-defaults/postfix.md
[docs-mailserver-behind-proxy]: ../../../examples/tutorials/mailserver-behind-proxy
[dockerhub-haproxy]: https://hub.docker.com/_/haproxy
[Kubernetes-nginx]: https://kubernetes.github.io/ingress-nginx
[Kubernetes-nginx-expose]: https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services
[Kubernetes-network-external-ip]: https://kubernetes.io/docs/concepts/services-networking/service/#external-ips
[Kubernetes-proxy-service]: https://github.com/kubernetes/contrib/tree/master/for-demos/proxy-to-service
[Kubernetes-service-source-ip]: https://kubernetes.io/docs/tutorials/services/source-ip
