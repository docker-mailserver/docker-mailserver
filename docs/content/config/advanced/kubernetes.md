---
title: 'Advanced | Kubernetes'
---

## Deployment Example

There is nothing much in deploying mailserver to Kubernetes itself. The things are pretty same as in [`docker-compose.yml`][github-file-compose], but with Kubernetes syntax.

??? example "ConfigMap"

    ```yaml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: mailserver
    ---
    kind: ConfigMap
    apiVersion: v1
    metadata:
      name: mailserver.env.config
      namespace: mailserver
      labels:
        app: mailserver
    data:
      OVERRIDE_HOSTNAME: example.com
      ENABLE_FETCHMAIL: "0"
      FETCHMAIL_POLL: "120"
      ENABLE_SPAMASSASSIN: "0"
      ENABLE_CLAMAV: "0"
      ENABLE_FAIL2BAN: "0"
      ENABLE_POSTGREY: "0"
      ONE_DIR: "1"
      DMS_DEBUG: "0"

    ---
    kind: ConfigMap
    apiVersion: v1
    metadata:
      name: mailserver.config
      namespace: mailserver
      labels:
        app: mailserver
    data:
      postfix-accounts.cf: |
        user1@example.com|{SHA512-CRYPT}$6$2YpW1nYtPBs2yLYS$z.5PGH1OEzsHHNhl3gJrc3D.YMZkvKw/vp.r5WIiwya6z7P/CQ9GDEJDr2G2V0cAfjDFeAQPUoopsuWPXLk3u1

      postfix-virtual.cf: |
        alias1@example.com user1@dexample.com

      #dovecot.cf: |
      #  service stats {
      #    unix_listener stats-reader {
      #      group = docker
      #      mode = 0666
      #    }
      #    unix_listener stats-writer {
      #      group = docker
      #      mode = 0666
      #    }
      #  }

      SigningTable: |
        *@example.com mail._domainkey.example.com

      KeyTable: |
        mail._domainkey.example.com example.com:mail:/etc/opendkim/keys/example.com-mail.key

      TrustedHosts: |
        127.0.0.1
        localhost

      #user-patches.sh: |
      #  #!/bin/bash

      #fetchmail.cf: |
    ```

??? example "Secret"

    ```yaml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: mailserver
    ---
    kind: Secret
    apiVersion: v1
    metadata:
      name: mailserver.opendkim.keys
      namespace: mailserver
      labels:
        app: mailserver
    type: Opaque
    data:
      example.com-mail.key: 'base64-encoded-DKIM-key'
    ```

??? example "Service"

    ```yaml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: mailserver
    ---
    kind: Service
    apiVersion: v1
    metadata:
      name: mailserver
      namespace: mailserver
      labels:
        app: mailserver
    spec:
      selector:
        app: mailserver
      ports:
        - name: smtp
          port: 25
          targetPort: smtp
        - name: smtp-secure
          port: 465
          targetPort: smtp-secure
        - name: smtp-auth
          port: 587
          targetPort: smtp-auth
        - name: imap
          port: 143
          targetPort: imap
        - name: imap-secure
          port: 993
          targetPort: imap-secure
    ```

??? example "Deployment"

    ```yaml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: mailserver
    ---
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: mailserver
      namespace: mailserver
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: mailserver
      template:
        metadata:
          labels:
            app: mailserver
            role: mail
            tier: backend
        spec:
          #nodeSelector:
          #  kubernetes.io/hostname: local.k8s
          #initContainers:
          #- name: init-myservice
          #  image: busybox
          #  command: ["/bin/sh", "-c", "cp /tmp/user-patches.sh /tmp/files"]
          #  volumeMounts:
          #    - name: config
          #      subPath: user-patches.sh
          #      mountPath: /tmp/user-patches.sh
          #      readOnly: true
          #    - name: tmp-files
          #      mountPath: /tmp/files
          containers:
          - name: docker-mailserver
            image: mailserver/docker-mailserver:latest
            imagePullPolicy: Always
            volumeMounts:
              - name: config
                subPath: postfix-accounts.cf
                mountPath: /tmp/docker-mailserver/postfix-accounts.cf
                readOnly: true
              #- name: config
              #  subPath: postfix-main.cf
              #  mountPath: /tmp/docker-mailserver/postfix-main.cf
              #  readOnly: true
              - name: config
                subPath: postfix-virtual.cf
                mountPath: /tmp/docker-mailserver/postfix-virtual.cf
                readOnly: true
              - name: config
                subPath: fetchmail.cf
                mountPath: /tmp/docker-mailserver/fetchmail.cf
                readOnly: true
              - name: config
                subPath: dovecot.cf
                mountPath: /tmp/docker-mailserver/dovecot.cf
                readOnly: true
              #- name: config
              #  subPath: user1.example.com.dovecot.sieve
              #  mountPath: /tmp/docker-mailserver/user1@example.com.dovecot.sieve
              #  readOnly: true
              #- name: tmp-files
              #  subPath: user-patches.sh
              #  mountPath: /tmp/docker-mailserver/user-patches.sh
              - name: config
                subPath: SigningTable
                mountPath: /tmp/docker-mailserver/opendkim/SigningTable
                readOnly: true
              - name: config
                subPath: KeyTable
                mountPath: /tmp/docker-mailserver/opendkim/KeyTable
                readOnly: true
              - name: config
                subPath: TrustedHosts
                mountPath: /tmp/docker-mailserver/opendkim/TrustedHosts
                readOnly: true
              - name: opendkim-keys
                mountPath: /tmp/docker-mailserver/opendkim/keys
                readOnly: true
              - name: data
                mountPath: /var/mail
                subPath: data
              - name: data
                mountPath: /var/mail-state
                subPath: state
              - name: data
                mountPath: /var/log/mail
                subPath: log
            ports:
              - name: smtp
                containerPort: 25
                protocol: TCP
              - name: smtp-secure
                containerPort: 465
                protocol: TCP
              - name: smtp-auth
                containerPort: 587
              - name: imap
                containerPort: 143
                protocol: TCP
              - name: imap-secure
                containerPort: 993
                protocol: TCP
            envFrom:
              - configMapRef:
                  name: mailserver.env.config
          volumes:
            - name: config
              configMap:
                name: mailserver.config
            - name: opendkim-keys
              secret:
                secretName: mailserver.opendkim.keys
            - name: data
              persistentVolumeClaim:
                claimName: mail-storage
            - name: tmp-files
              emptyDir: {}
    ```

!!! warning
    Any sensitive data (keys, etc) should be deployed via [Secrets][k8s-config-secret]. Other configuration just fits well into [ConfigMaps][k8s-config-pod].

!!! note
    Make sure that [Pod][k8s-workload-pod] is [assigned][k8s-assign-pod-node] to specific [Node][k8s-nodes] in case you're using volume for data directly with `hostPath`. Otherwise Pod can be rescheduled on a different Node and previous data won't be found. Except the case when you're using some shared filesystem on your Nodes.

## Exposing to the Outside World

The hard part with Kubernetes is to expose deployed mailserver to outside world. Kubernetes provides multiple ways for doing that. Each has its downsides and complexity.

The major problem with exposing mailserver to outside world in Kubernetes is to [preserve real client IP][k8s-service-source-ip]. Real client IP is required by mailserver for performing IP-based SPF checks and spam checks.

Preserving real client IP is relatively [non-trivial in Kubernetes][k8s-service-source-ip] and most exposing ways do not provide it. So, it's up to you to decide which exposing way suits better your needs in a price of complexity.

If you do not require SPF checks for incoming mails you may disable them in [Postfix configuration][docs-postfix] by dropping following line (which removes `check_policy_service unix:private/policyd-spf` option):

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
        smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination, reject_unauth_pipelining, reject_invalid_helo_hostname, reject_non_fqdn_helo_hostname, reject_unknown_recipient_domain, reject_rbl_client zen.spamhaus.org, reject_rbl_client bl.spamcop.net
    # ...

    ---

    kind: Deployment
    apiVersion: extensions/v1beta1
    metadata:
      name: mailserver
    # ...
        volumeMounts:
          - name: config
            subPath: postfix-main.cf
            mountPath: /tmp/docker-mailserver/postfix-main.cf
            readOnly: true
    ```

### External IPs Service

The simplest way is to expose mailserver as a [Service][k8s-network-service] with [external IPs][k8s-network-external-ip].

!!! example

    ```yaml
    kind: Service
    apiVersion: v1
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

**Downsides**

- __Real client IP is not preserved__, so SPF check of incoming mail will fail.

- Requirement to specify exposed IPs explicitly.

### Proxy port to Service

The [Proxy Pod][k8s-proxy-service] helps to avoid necessity of specifying external IPs explicitly. This comes in price of complexity: you must deploy Proxy Pod on each [Node][k8s-nodes] you want to expose mailserver on.

**Downsides**

- __Real client IP is not preserved__, so SPF check of incoming mail will fail.

### Bind to concrete Node and use host network

The simplest way to preserve real client IP is to use `hostPort` and `hostNetwork: true` in the mailserver [Pod][k8s-workload-pod]. This comes in price of availability: you can talk to mailserver from outside world only via IPs of [Node][k8s-nodes] where mailserver is deployed.

!!! example

    ```yaml
    kind: Deployment
    apiVersion: extensions/v1beta1
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
    # ...
    ```

**Downsides**

- Not possible to access mailserver via other cluster Nodes, only via the one mailserver deployed at.
- Every Port within the Container is exposed on the Host side, regardless of what the `ports` section in the Configuration defines. 

### Proxy Port to Service via PROXY Protocol

This way is ideologically the same as [using Proxy Pod](#proxy-port-to-service), but instead of a separate proxy pod, you configure your ingress to proxy TCP traffic to the mailserver pod using the PROXY protocol, which preserves the real client IP.

#### Configure your Ingress

With an [NGINX ingress controller][k8s-nginx], set `externalTrafficPolicy: Local` for its service, and add the following to the TCP services config map (as described [here][k8s-nginx-expose]):

```yaml
25:  "mailserver/mailserver:25::PROXY"
465: "mailserver/mailserver:465::PROXY"
587: "mailserver/mailserver:587::PROXY"
993: "mailserver/mailserver:993::PROXY"
```

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

**Downsides**

- Not possible to access mailserver via inner cluster Kubernetes DNS, as PROXY protocol is required for incoming connections.

## Let's Encrypt Certificates

[Kube-Lego][kube-lego] may be used for a role of Let's Encrypt client. It works with Kubernetes [Ingress Resources][k8s-network-ingress] and automatically issues/manages certificates/keys for exposed services via Ingresses.

!!! example

    ```yaml
    kind: Ingress
    apiVersion: extensions/v1beta1
    metadata:
      name: mailserver
      labels:
        app: mailserver
      annotations:
        kubernetes.io/tls-acme: 'true'
    spec:
      rules:
        - host: example.com
          http:
            paths:
              - path: /
                backend:
                  serviceName: default-backend
                  servicePort: 80
      tls:
        - secretName: mailserver.tls
          hosts:
            - example.com
    ```

Now, you can use Let's Encrypt cert and key from `mailserver.tls` [Secret][k8s-config-secret] in your [Pod][k8s-workload-pod] spec:

!!! example

    ```yaml
    # ...
    env:
      - name: SSL_TYPE
        value: 'manual'
      - name: SSL_CERT_PATH
        value: '/etc/ssl/mailserver/tls.crt'
      - name: SSL_KEY_PATH
        value: '/etc/ssl/mailserver/tls.key'
    # ...
    volumeMounts:
      - name: tls
        mountPath: /etc/ssl/mailserver
        readOnly: true
    # ...
    volumes:
      - name: tls
        secret:
          secretName: mailserver.tls
    ```

[docs-dovecot]: ./override-defaults/dovecot.md
[docs-postfix]: ./override-defaults/postfix.md
[github-file-compose]: https://github.com/docker-mailserver/docker-mailserver/blob/master/docker-compose.yml
[dockerhub-haproxy]: https://hub.docker.com/_/haproxy
[kube-lego]: https://github.com/jetstack/kube-lego
[k8s-assign-pod-node]: https://kubernetes.io/docs/concepts/configuration/assign-pod-node
[k8s-config-pod]: https://kubernetes.io/docs/tasks/configure-pod-container/configmap
[k8s-config-secret]: https://kubernetes.io/docs/concepts/configuration/secret
[k8s-nginx]: https://kubernetes.github.io/ingress-nginx
[k8s-nginx-expose]: https://kubernetes.github.io/ingress-nginx/user-guide/exposing-tcp-udp-services
[k8s-network-ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress
[k8s-network-service]: https://kubernetes.io/docs/concepts/services-networking/service
[k8s-network-external-ip]: https://kubernetes.io/docs/concepts/services-networking/service/#external-ips
[k8s-nodes]: https://kubernetes.io/docs/concepts/architecture/nodes
[k8s-proxy-service]: https://github.com/kubernetes/contrib/tree/master/for-demos/proxy-to-service
[k8s-service-source-ip]: https://kubernetes.io/docs/tutorials/services/source-ip
[k8s-workload-pod]: https://kubernetes.io/docs/concepts/workloads/pods/pod
