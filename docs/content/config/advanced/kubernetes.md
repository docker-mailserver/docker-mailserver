---
title: 'Advanced | Kubernetes'
---

## Introduction

This article describes how to deploy DMS to Kubernetes. Please note that there is also a [Helm chart] available.

!!! attention "Requirements"

    We assume basic knowledge about Kubernetes from the reader. Moreover, we assume the reader to have a basic understanding of mail servers. Ideally, the reader has deployed DMS before in an easier setup with Docker (Compose).

!!! warning "About Support for Kubernetes"

    Please note that Kubernetes **is not** officially supported and we do not build images specifically designed for it. When opening an issue, please remember that only Docker & Docker Compose are officially supported.

    This content is entirely community-supported. If you find errors, please open an issue and provide a PR.

## Manifests

### Configuration

We want to provide the basic configuration in the form of environment variables with a `ConfigMap`. Note that this is just an example configuration; tune the `ConfigMap` to your needs.

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
  ONE_DIR: '1'
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

### Persistence

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

### Service

A `Service` is required for getting the traffic to the pod itself. The service is somewhat crucial. Its configuration determines whether the original IP from the sender will be kept. [More about this further down below](#exposing-your-mail-server-to-the-outside-world).

The configuration you're seeing does keep the original IP, but you will not be able to scale this way. We have chosen to go this route in this case because we think most Kubernetes users will only want to have one instance.

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
    # Transfer
    - name: transfer
      port: 25
      targetPort: transfer
      protocol: TCP
    # ESMTP with implicit TLS
    - name: esmtp-implicit
      port: 465
      targetPort: esmtp-implicit
      protocol: TCP
    # ESMTP with explicit TLS (STARTTLS)
    - name: esmtp-explicit
      port: 587
      targetPort: esmtp-explicit
      protocol: TCP
    # IMAPS with implicit TLS
    - name: imap-implicit
      port: 993
      targetPort: imap-implicit
      protocol: TCP

```

### Deployments

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
            allowPrivilegeEscalation: false
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
            - name: transfer
              containerPort: 25
              protocol: TCP
            - name: esmtp-implicit
              containerPort: 465
              protocol: TCP
            - name: esmtp-explicit
              containerPort: 587
            - name: imap-implicit
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

### Certificates - An Example

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

### Sensitive Data

!!! attention "Sensitive Data"

    For storing OpenDKIM keys, TLS certificates or any sort of sensitive data, you should be using `Secret`s. You can mount secrets like `ConfigMap`s and use them the same way.

The [TLS docs page][docs-tls] provides guidance when it comes to certificates and transport layer security. Always provide sensitive information vai `Secrets`.

## Exposing your Mail Server to the Outside World

The more difficult part with Kubernetes is to expose a deployed DMS to the outside world. Kubernetes provides multiple ways for doing that; each has downsides and complexity. The major problem with exposing DMS to outside world in Kubernetes is to [preserve the real client IP][Kubernetes-service-source-ip]. The real client IP is required by DMS for performing IP-based SPF checks and spam checks. If you do not require SPF checks for incoming mails, you may disable them in your [Postfix configuration][docs-postfix] by dropping the line that states: `check_policy_service unix:private/policyd-spf`.

The easiest approach was covered above, using `#!yaml externalTrafficPolicy: Local`, which disables the service proxy, but makes the service local as well (which does not scale). This approach only works when you are given the correct (that is, a public and routable) IP address by a load balancer (like MetalLB). In this sense, the approach above is similar to the next example below. We want to provide you with a few alternatives too. **But** we also want to communicate the idea of another simple method: you could use a load-balancer without an external IP and DNAT the network traffic to the mail server. After all, this does not interfere with SPF checks because it keeps the origin IP address. If no dedicated external IP address is available, you could try the latter approach, if one is available, use the former.

### External IPs Service

The simplest way is to expose DMS as a [Service][Kubernetes-network-service] with [external IPs][Kubernetes-network-external-ip]. This is very similar to the approach taken above. Here, an external IP is given to the service directly by you. With the approach above, you tell your load-balancer to do this.

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

This approach

- does not preserve the real client IP, so SPF check of incoming mail will fail.
- requires you to specify the exposed IPs explicitly.

### Proxy port to Service

The [proxy pod][Kubernetes-proxy-service] helps to avoid the necessity of specifying external IPs explicitly. This comes at the cost of complexity; you must deploy a proxy pod on each [Node][Kubernetes-nodes] you want to expose DMS on.

This approach

- does not preserve the real client IP, so SPF check of incoming mail will fail.

### Bind to concrete Node and use host network

One way to preserve the real client IP is to use `hostPort` and `hostNetwork: true`. This comes at the cost of availability; you can reach DMS from the outside world only via IPs of [Node][Kubernetes-nodes] where DMS is deployed.

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

With this approach,

- it is not possible to access DMS via other cluster Nodes, only via the Node DMS was deployed at.
- every Port within the Container is exposed on the Host side.

### Proxy Port to Service via PROXY Protocol

This way is ideologically the same as [using a proxy pod](#proxy-port-to-service), but instead of a separate proxy pod, you configure your ingress to proxy TCP traffic to the DMS pod using the PROXY protocol, which preserves the real client IP.

#### Configure your Ingress

With an [NGINX ingress controller][Kubernetes-nginx], set `externalTrafficPolicy: Local` for its service, and add the following to the TCP services config map (as described [here][Kubernetes-nginx-expose]):

```yaml
25:  "mailserver/mailserver:25::PROXY"
465: "mailserver/mailserver:465::PROXY"
587: "mailserver/mailserver:587::PROXY"
993: "mailserver/mailserver:993::PROXY"
```

!!! help "HAProxy"
    With [HAProxy][dockerhub-haproxy], the configuration should look similar to the above. If you know what it actually looks like, add an example here. :smiley:

#### Configure the Mailserver

Then, configure both [Postfix][docs-postfix] and [Dovecot][docs-dovecot] to expect the PROXY protocol:

??? example "HAProxy Example"

    ```yaml
    kind: ConfigMap
    apiVersion: v1
    metadata:
      name: mailserver.config
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
        # Assuming your ingress controller is bound to 10.0.0.0/8
        haproxy_trusted_networks = 10.0.0.0/8, 127.0.0.0/8
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

With this approach,

- it is not possible to access DMS via cluster-DNS, as the PROXY protocol is required for incoming connections.

[Helm chart]: https://github.com/docker-mailserver/docker-mailserver-helm
[kustomize]: https://kustomize.io/
[cert-manager]: https://cert-manager.io/docs/
[docs-tls]: ../security/ssl.md
[docs-dovecot]: ./override-defaults/dovecot.md
[docs-postfix]: ./override-defaults/postfix.md
[dockerhub-haproxy]: https://hub.docker.com/_/haproxy
[Kubernetes-nginx]: https://kubernetes.github.io/ingress-nginx
[Kubernetes-nginx-expose]: https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services
[Kubernetes-network-service]: https://kubernetes.io/docs/concepts/services-networking/service
[Kubernetes-network-external-ip]: https://kubernetes.io/docs/concepts/services-networking/service/#external-ips
[Kubernetes-nodes]: https://kubernetes.io/docs/concepts/architecture/nodes
[Kubernetes-proxy-service]: https://github.com/kubernetes/contrib/tree/master/for-demos/proxy-to-service
[Kubernetes-service-source-ip]: https://kubernetes.io/docs/tutorials/services/source-ip
