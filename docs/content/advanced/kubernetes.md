## Deployment example

There is nothing much in deploying mailserver to Kubernetes itself. The things are pretty same as in [`docker-compose.yml`][1], but with Kubernetes syntax.

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
      - name: smtp
        image: tvial/docker-mailserver:release-v6.2.1
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

__Note:__
Any sensitive data (keys, etc) should be deployed via [Secrets][50]. Other configuration just fits well into [ConfigMaps][51].

__Note:__
Make sure that [Pod][52] is [assigned][59] to specific [Node][53] in case you're using volume for data directly with `hostPath`. Otherwise Pod can be rescheduled on a different Node and previous data won't be found. Except the case when you're using some shared filesystem on your Nodes.




## Exposing to outside world

The hard part with Kubernetes is to expose deployed mailserver to outside world. Kubernetes provides multiple ways for doing that. Each has its downsides and complexity.

The major problem with exposing mailserver to outside world in Kubernetes is to [preserve real client IP][57]. Real client IP is required by mailserver for performing IP-based SPF checks and spam checks.

Preserving real client IP is relatively [non-trivial in Kubernetes][57] and most exposing ways do not provide it. So, it's up to you to decide which exposing way suits better your needs in a price of complexity.

If you do not require SPF checks for incoming mails you may disable them in [Postfix configuration][2] by dropping following line (which removes `check_policy_service unix:private/policyd-spf` option):
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
# ...
```


### External IPs Service

The simplest way is to expose mailserver as a [Service][55] with [external IPs][56].

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

##### Downsides

- __Real client IP is not preserved__, so SPF check of incoming mail will fail.

- Requirement to specify exposed IPs explicitly.


### Proxy port to Service

The [Proxy Pod][58] helps to avoid necessity of specifying external IPs explicitly. This comes in price of complexity: you must deploy Proxy Pod on each [Node][53] you want to expose mailserver on.

##### Downsides

- __Real client IP is not preserved__, so SPF check of incoming mail will fail.


### Bind to concrete Node and use host network

The simplest way to preserve real client IP is to use `hostPort` and `hostNetwork: true` in the mailserver [Pod][52]. This comes in price of availability: you can talk to mailserver from outside world only via IPs of [Node][53] where mailserver is deployed.

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

##### Downsides

- Not possible to access mailserver via other cluster Nodes, only via the one mailserver deployed at.


### Proxy port to Service via PROXY protocol

This way is ideologically the same as [using Proxy Pod](#proxy-port-to-service) but instead Proxy Pod you should use [HAProxy image][11] or [Nginx Ingress Controller][12] and proxy TCP traffic to mailserver Pod with PROXY protocol usage which does real client IP preservation.

This requires some additional mailserver configuration: you should enable PROXY protocol on ports that [Postfix][2] and [Dovecot][3] listen on for incoming connections.
```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: mailserver.config
  labels:
    app: mailserver
data:
  postfix-main.cf: |
    smtpd_upstream_proxy_protocol = haproxy
  dovecot.cf: |
    service imap-login {
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
#...
          volumeMounts:
            - name: config
              subPath: postfix-main.cf
              mountPath: /tmp/docker-mailserver/postfix-main.cf
              readOnly: true
            - name: config
              subPath: dovecot.cf
              mountPath: /etc/dovecot/conf.d/zz-custom.cf
              readOnly: true
# ...
```

##### Downsides

- Not possible to access mailserver via inner cluster Kubernetes DNS, as PROXY protocol is required for incoming connections.




## Let's Encrypt certificates

[Kube-Lego][10] may be used for a role of Let's Encrypt client. It works with Kubernetes [Ingress Resources][54] and automatically issues/manages certificates/keys for exposed services via Ingresses.

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

Now, you can use Let's Encrypt cert and key from `mailserver.tls` [Secret][50]
in your [Pod][52] spec.

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
# ...
```





[1]: https://github.com/tomav/docker-mailserver/blob/master/docker-compose.yml.dist
[2]: https://github.com/tomav/docker-mailserver/wiki/Overwrite-Default-Postfix-Configuration
[3]: https://github.com/tomav/docker-mailserver/wiki/Override-Default-Dovecot-Configuration
[10]: https://github.com/jetstack/kube-lego
[11]: https://hub.docker.com/_/haproxy
[12]: https://github.com/kubernetes/ingress/tree/master/controllers/nginx#exposing-tcp-services
[50]: https://kubernetes.io/docs/concepts/configuration/secret
[51]: https://kubernetes.io/docs/tasks/configure-pod-container/configmap
[52]: https://kubernetes.io/docs/concepts/workloads/pods/pod
[53]: https://kubernetes.io/docs/concepts/architecture/nodes
[54]: https://kubernetes.io/docs/concepts/services-networking/ingress
[55]: https://kubernetes.io/docs/concepts/services-networking/service
[56]: https://kubernetes.io/docs/concepts/services-networking/service/#external-ips
[57]: https://kubernetes.io/docs/tutorials/services/source-ip
[58]: https://github.com/kubernetes/contrib/tree/master/for-demos/proxy-to-service
[59]: https://kubernetes.io/docs/concepts/configuration/assign-pod-node
