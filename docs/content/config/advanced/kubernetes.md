---
title: 'Advanced | Kubernetes'
---

## Introduction

Kubernetes (also known by its abbreviation K8s) is a production-grade orchestrating tool for containers. This article describes how to deploy `docker-mailserver` to K8s. K8s differs from Docker especially when it comes to separation of concerns: Whereas with Docker Compose, you can fit everything in one file, with K8s, the information is split. This may seem (too) verbose, but actually provides a clear structure with more features and scalability. We are going to have a look at how to deploy one instance of `docker-mailserver` to your cluster.

We assume basic knowledge about K8s from the reader. If you're not familiar with K8s, we highly recommend starting with something less complex, like Docker Compose.

!!! warning "About Support for K8s"

    Please note that Kubernetes **is not** officially supported and we do not build images specifically designed for it. When opening an issue, please remember that only Docker & Docker Compose are officially supported.

    This content is entirely community-supported. If you find errors, please open an issue and provide a PR.

## Manifests

First of all, we want to provide the basic configuration with environment variables with a `ConfigMap`. Note that this is just an example configuration; tune the `ConfigMap` to your needs.


```yaml
---
apiVersion: v1
kind: ConfigMap

metadata:
  name: mailserver.environment

immutable: true # turn off during development

data:
  TLS_LEVEL: modern
  POSTSCREEN_ACTION: drop
  OVERRIDE_HOSTNAME: mail.example.com
  FAIL2BAN_BLOCKTYPE: drop
  POSTMASTER_ADDRESS: postmaster@example.com
  UPDATE_CHECK_INTERVAL: 10d
  POSTFIX_INET_PROTOCOLS: ipv4
  ONE_DIR: '1'
  DMS_DEBUG: '0'
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
```

We can also make use of user-provided configuration files, e.g. `user-patches.sh`, `postfix-accounts.cf` and more, to adjust `docker-mailserver` to our likings. We encourage you to have a look at [Kustomize] for creating `ConfigMap`s from multiple files, but for now, we will provide a simple, hand-written example. This example is absolutely minimal and only goes to show what can be done.

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

Thereafter, we need persistence for our data. We will write a `PersistentVolumeClaim`.

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
      storage: 1Gi
```

A `Service` is required for getting the traffic to the pod itself. The service is somewhat crucial. Its configuration determines whether the original IP from the sender will be kept. [More about this further down below](#exposing-your-mail-server-to-the-outside-world). The configuration you're seeing does keep the original IP, but you will not be able to scale this way. We have chosen to go this route in this case because we think most K8s users will only want to have on instance anyway, and users that need high availability know how to do it anyways. You will want to have your load-balancer give this service an external, routable IP address.

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

spec:
  type: LoadBalancer
  externalTrafficPolicy: Local

  ipFamilies: [IPv4]            # not strictly required
  ipFamilyPolicy: SingleStack   # not strictly required

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

Last but not least, the `Deployment` becomes the most complex component. The deployment brings maximal security measures without compromising on ease of use.

```yaml
---
apiVersion: apps/v1
kind: Deployment

metadata:
  name: mailserver

  annotations:
    ignore-check.kube-linter.io/run-as-non-root: >-
      The mail server needs to run as root
    ignore-check.kube-linter.io/privileged-ports: >-
      The mail server needs privilegdes ports
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
      hostname: mailserver
      containers:
        - name: mailserver
          image: ghcr.io/docker-mailserver/docker-mailserver:10.0.0
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
                # miscellaneous  capabilities
                - SYS_CHROOT
                - NET_BIND_SERVICE
                - KILL
              drop: [ALL]
            seccompProfile:
              type: RuntimeDefault

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

        # other
        - name: tmp-files
          emptyDir: {}
```

By now, the mailserver starts, but does not really work for long (or at all), because we're lacking certificates. You will need to chose yourself, which approach you'd want to go. The [TLS](../security/ssl.md) section provides you with an overview.

!!! attention "Sensitive Data"

    For storing OpenDKIM keys, TLS certificates or any sort of sensitive data, you should be using `Secret`s. You can mount secrets like `ConfigMaps` and use them the same way.

## Exposing your Mail Server to the Outside World

The more difficult part with K8s is to expose deployed mailserver to outside world. K8s provides multiple ways for doing that; each has its downsides and complexity. The major problem with exposing the mail server to outside world in K8s is to [preserve the real client IP][k8s-service-source-ip]. The real client IP is required by the mail server for performing IP-based SPF checks and spam checks. If you do not require SPF checks for incoming mails, you may disable them in your [Postfix configuration][docs-postfix] by dropping the line stat states `check_policy_service unix:private/policyd-spf`.

The easiest ways was shown above, using `#!yaml externalTrafficPolicy: Local`, which disables the service proxy, but makes the service local as well (so it does not scale). This approach only works when you are given the correct (that is, a public and routable) IP address by a load balancer (like MetalLB). In this sense, the approach above is similar to the first one we will show now: We want to provide you with a few alternatives too.

### External IPs Service

The simplest way is to expose the mail server as a [Service][k8s-network-service] with [external IPs][k8s-network-external-ip].

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

- does not preserve the real client IP, so SPF check of incoming mail will fail
- requires you to specify the exposed IPs explicitly

### Proxy port to Service

The [proxy pod][k8s-proxy-service] helps to avoid the necessity of specifying external IPs explicitly. This comes st the price of complexity: you must deploy a proxy pod on each [Node][k8s-nodes] you want to expose mailserver on.

This approach

- does not preserve the real client IP, so SPF check of incoming mail will fail

### Bind to concrete Node and use host network

One way to preserve the real client IP is to use `hostPort` and `hostNetwork: true`. This comes in price of availability: you can talk to the mail server from outside world only via IPs of [Node][k8s-nodes] where mailserver is deployed.

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

- it is not possible to access mailserver via other cluster Nodes, only via the one mailserver deployed at
- every Port within the Container is exposed on the Host side

### Proxy Port to Service via PROXY Protocol

This way is ideologically the same as [using a proxy pod](#proxy-port-to-service), but instead of a separate proxy pod, you configure your ingress to proxy TCP traffic to the mailserver pod using the PROXY protocol, which preserves the real client IP.

#### Configure your Ingress

With an [NGINX ingress controller][k8s-nginx], set `externalTrafficPolicy: Local` for its service, and add the following to the TCP services config map (as described [here][k8s-nginx-expose]):

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

!!! example

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
        smtps/inet/smtpd_upstream_proxy_protocol=haproxy
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

- is is not possible to access the mail server via cluster-DNS, as the PROXY protocol is required for incoming connections

[Kustomize]: https://kustomize.io/
[docs-dovecot]: ./override-defaults/dovecot.md
[docs-postfix]: ./override-defaults/postfix.md
[dockerhub-haproxy]: https://hub.docker.com/_/haproxy
[k8s-nginx]: https://kubernetes.github.io/ingress-nginx
[k8s-nginx-expose]: https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services
[k8s-network-service]: https://kubernetes.io/docs/concepts/services-networking/service
[k8s-network-external-ip]: https://kubernetes.io/docs/concepts/services-networking/service/#external-ips
[k8s-nodes]: https://kubernetes.io/docs/concepts/architecture/nodes
[k8s-proxy-service]: https://github.com/kubernetes/contrib/tree/master/for-demos/proxy-to-service
[k8s-service-source-ip]: https://kubernetes.io/docs/tutorials/services/source-ip
