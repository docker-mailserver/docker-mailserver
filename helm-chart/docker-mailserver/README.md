# Docker-mailserver

[Docker-mailserver ](https://github.com/tomav/docker-mailserver)is fullstack but simple mailserver (smtp, imap, antispam, antivirus, ssl...) using Docker. See the author's motivations for creating it, [here](https://tvi.al/simple-mail-server-with-docker/).

While the stack is intended to be run with Docker or Docker Compose, it's been adapted to [Docker Swarm](https://geek-cookbook.funkypenguin.co.nz/recipes/mail/), and to [Kubernetes](https://github.com/tomav/docker-mailserver/wiki/Using-in-Kubernetes).

## Introduction

This helm chart deploys docker-mailserver into a Kubernetes cluster, in a manner which retains compatibility with the upstream, docker-specific version. 

## Contents

- [Docker-mailserver](#docker-mailserver)
  - [Introduction](#introduction)
  - [Contents](#contents)
  - [Features](#features)
  - [Prerequisites](#prerequisites)
  - [Architecture](#architecture)
  - [Installation](#installation)
    - [Install helm and cert-manager](#install-helm-and-cert-manager)
  - [Installation](#installation-1)
  - [Operation](#operation)
    - [Create / Update / Delete users](#create--update--delete-users)
    - [Setup OpenDKIM](#setup-opendkim)
    - [Setup RainLoop](#setup-rainloop)
    - [Configuration](#configuration)
      - [Minimal configuration](#minimal-configuration)
      - [Chart Configuration](#chart-configuration)
      - [docker-mailserver Configuration](#docker-mailserver-configuration)
      - [Rainloop Configuration](#rainloop-configuration)
      - [HA Proxy-Ingress Configuration](#ha-proxy-ingress-configuration)
  - [Development](#development)
    - [Testing](#testing)

(Created by [gh-md-toc](https://github.com/ekalinin/github-markdown-toc.go))

## Features 

The chart includes the following features:

* All configuration is done in values.yaml, or using the native "setup.sh" script (to create mailboxes or DKIM keys)
* Avoids the [common problem of masking of source IP](https://kubernetes.io/docs/tutorials/services/source-ip/) by supporting haproxy's PROXY protocol (enabled by default)
* Supports integration with external HAProxy, HAProxy Ingress Controller, or [poor-mans-k8s-lb](https://www.funkypenguin.co.nz/project/a-simple-free-load-balancer-for-your-kubernetes-cluster/)
* Employs [cert-manager](https://github.com/jetstack/cert-manager) to automatically provide/renew SSL certificates
* Bundles in [RainLoop](https://www.rainloop.net) for webmail access (enabled by default)
* Starts in "demo" mode, allowing the user to test core functionality before configuring for specific domains

## Prerequisites

- Kubernetes 1.5+ (*CI validates against 1.12.0*)
- To use HAProxy ingress, you'll need to deploying the chart to a cluster with a cloud provider capable of provisioning an
external load balancer (e.g. AWS, DO or GKE). (There is an [update planned](https://github.com/funkypenguin/docker-mailserver/issues/5) to support HA ingress on bare-metal deployments)
- You control DNS for the domain(s) you intend to route through Traefik
- __Suggested:__ PV provisioner support in the underlying infrastructure
- Cert-manager requires manual deployment into your cluster (details below)

## Architecture

There are several ways you might deploy docker-mailserver. The most common would be:

1. Within a cloud provider, utilizing a load balancer service from the cloud provider (i.e. GKE). This is an expensive option, since typically you'd pay for each individual port (25, 465, 993, etc) which gets load-balanced

2. Either within a cloud provider, or in a private Kubernetes cluster, behind a non-integrated load-balancer such as haproxy. An example deployment might be something like [Funky Penguin's Poor Man's K8s Load Balancer](https://www.funkypenguin.co.nz/project/a-simple-free-load-balancer-for-your-kubernetes-cluster/), or even a manually configured haproxy instance/pair.

## Installation

### Install helm and cert-manager

1. You need helm, obviously.

2. You need to install cert-manager, and setup issuers (https://docs.cert-manager.io/en/latest/index.html). It's easy to install using helm (which you have anyway, right?). Cert-manager is what will request and renew SSL certificates required for docker-mailserver to work. The chart will assume that you've configured and tested certmanager.

Here are the TL;DR steps for installing cert-manager:

```
# Install the CustomResourceDefinition resources separately
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.7/deploy/manifests/00-crds.yaml

# Create the namespace for cert-manager
kubectl create namespace cert-manager

# Label the cert-manager namespace to disable resource validation
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install \
  --name cert-manager \
  --namespace cert-manager \
  --version v0.7.0 \
  jetstack/cert-manager
```


## Installation

```bash
$ helm install --name docker-mailserver docker-mailserver
```
(Note: An [issues exists](https://github.com/funkypenguin/docker-mailserver/issues/4) for the support of deploying to a custom namespace)

## Operation

### Create / Update / Delete users

### Setup OpenDKIM

```
[funkypenguin:~/Documents/Personal/Projects/docker-mailserver/helm-chart] add-helm-chart 1 ± ../setup.sh config dkim
"docker inspect" requires at least 1 argument.
See 'docker inspect --help'.

Usage:  docker inspect [OPTIONS] NAME|ID [NAME|ID...]

Return low-level information on Docker objects
Creating DKIM private key /tmp/docker-mailserver/opendkim/keys/bob.com/mail.private
Creating DKIM KeyTable
Creating DKIM SigningTable
Creating DKIM private key /tmp/docker-mailserver/opendkim/keys/example.com/mail.private
Creating DKIM TrustedHosts
[funkypenguin:~/Documents/Personal/Projects/docker-mailserver/helm-chart] add-helm-chart* ±
```

### Setup RainLoop

If employing HAProxy with RainLoop, use port 10993 for your IMAPS server, as illustrated below:

![Rainloop with HAProxy screenshot](rainloop_with_haproxy.png)

### Configuration

All configuration values are documented in values.yaml. Check that for references, default values etc. To modify a
configuration value for a chart, you can either supply your own values.yaml overriding the default one in the repo:

```bash
$ helm upgrade --install path/to/docker-mailserver docker-mailserver --values path/to/custom/values/file.yaml
```

Or, you can override an individual configuration setting with `helm upgrade --set`, specifying each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example:

```bash
$ helm upgrade --install path/to/docker-mailserver docker-mailserver --set pod.dockermailserver.image="your/image:1.0.0"
```
#### Minimal configuration

Most of the values recorded belowe are set to sensible default, butyou'll definately want to pay attention to at least the following:

| Parameter                                | Description                                                                                                           | Default                |
|------------------------------------------|-----------------------------------------------------------------------------------------------------------------------|------------------------|
| `pod.dockermailserver.override_hostname` | The hostname to be presented on SMTP banners                                                                          | `mail.batcave.org`     |
| `rainloop.ingress.hosts`                 | The hostname(s) to be used via your ingress to access RainLoop                                                        | `rainloop.example.com` |
| `demo_mode.enabled`                      | Start the container with a demo "user@example.com" user (password is "password")                                      | `true`                 |
| `domains`                                | List of domains to be served                                                                                          | `[]`                   |
| `ssl.issuer.name`                        | The name of the cert-manager issuer expected to issue certs                                                           | `letsencrypt-staging`  |
| `ssl.issuer.kind`                        | Whether the issuer is namespaced (`Issuer`) on cluster-wide (`ClusterIssuer`)                                         | `ClusterIssuer`        |
| `ssl.dnsname`                            | DNS domain used for DNS01 validation                                                                                  | `example.com`          |
| `ssl.dns01provider`                      | The cert-manager DNS01 provider (*more details [coming](https://github.com/funkypenguin/docker-mailserver/issues/6)*) | `cloudflare`           |




#### Chart Configuration

The following table lists the configurable parameters of the docker-mailserver chart and their default values.

| Parameter                                         | Description                                                                                                                                                                          | Default                                              |
|---------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------|
| `image.name`                                      | The name of the container image to use                                                                                                                                               | `tvial/docker-mailserver`                            |
| `image.tag`                                       | The image tag to use (You may prefer "latest" over "v6.1.0", for example)                                                                                                            | `release-v6.1.0`                                     |
| `demo_mode.enabled`                               | Start the container with a demo "user@example.com" user (password is "password")                                                                                                     | `true`                                               |
| `haproxy.enabled`                                 | Support HAProxy PROXY protocol on SMTP, IMAP(S), and POP3(S) connections. Provides real source IP instead of load balancer IP                                                        | `true`                                               |
| `poor_mans_k8s_lb.enabled`                        | Whether to deploy containers to call webhook for [poor-mans-k8s-lb](https://www.funkypenguin.co.nz/project/a-simple-free-load-balancer-for-your-kubernetes-cluster/)                 | `false`                                              |
| `haproxy.webhook_url`                             | The webhook to use if [poor-mans-k8s-lb](https://www.funkypenguin.co.nz/project/a-simple-free-load-balancer-for-your-kubernetes-cluster/) is enabled via `poor_mans_k8s_lb.enabled`  | None                                                 |
| `haproxy.webhook_secret`                          | The secret to use if [poor-mans-k8s-lb](https://www.funkypenguin.co.nz/project/a-simple-free-load-balancer-for-your-kubernetes-cluster/) is enabled via `poor_mans_k8s_lb.enabled`   | None                                                 |
| `haproxy.trusted_networks`                        | The IPs (*in space-separated CIDR format*) from which to trust inbound HAProxy-enabled connections                                                                                   | `"10.0.0.0/8 192.168.0.0/16 172.16.0.0/16"`          |
| `spf_tests_disabled`                              | Disable all SPF-related spam checks (*if source IP of inbound connections is a problem, and you're not using haproxy*)                                                               | `false`                                              |
| `domains`                                         | List of domains to be served                                                                                                                                                         | `[]`                                                 |
| `liveness_tests.enabled`                          | Whether to execute liveness tests by running (arbitrary) commands in the docker-mailserver container. Useful to detect component failure (*i.e., clamd dies due to memory pressure*) | `true`                                               |
| `liveness_tests.enabled`                          | Array of commands to execute in sequence, to determine container health. A non-zero exit of any command is considered a failure                                                      | `[ "clamscan /tmp/docker-mailserver/TrustedHosts" ]` |
| `pod.dockermailserver.hostNetwork`                | Whether the pod should be connected to the "host" network (a primitive solution to ingress NAT problem)                                                                              | `false`                                              |
| `pod.dockermailserver.hostPID`                    | Not really sure. TBD.                                                                                                                                                                | `None`                                               |
| `pod.dockermailserver.hostPID`                    | Not really sure. TBD.                                                                                                                                                                | `None`                                               |
| `pod.dockermailserver.securityContext.privileged` | Whether to run this pod in "privileged" mode.                                                                                                                                        | `false`                                              |
| `service.type`                                    | What scope the service should be exposed in  (*LoadBalancer/NodePort/ClusterIP*)                                                                                                     | `NodePort`                                           |
| `service.loadBalancer.publicIp`                   | The public IP to assign to the service (*if LoadBalancer*) scope selected above                                                                                                      | `None`                                               |
| `service.loadBalancer.allowedIps`                 | The IPs allowed to access the sevice, in CIDR format (*if LoadBalancer*) scope selected above                                                                                        | `[ "0.0.0.0/0" ]`                                    |
| `service.nodeport.smtp`                           | The port exposed on the node the container is running on, which will be forwarded to docker-mailserver's SMTP port (25)                                                              | `30025`                                              |
| `service.nodeport.pop3`                           | The port exposed on the node the container is running on, which will be forwarded to docker-mailserver's POP3 port (110)                                                             | `30110`                                              |
| `service.nodeport.imap`                           | The port exposed on the node the container is running on, which will be forwarded to docker-mailserver's IMAP port (143)                                                             | `30143`                                              |
| `service.nodeport.smtps`                          | The port exposed on the node the container is running on, which will be forwarded to docker-mailserver's SMTPS port (465)                                                            | `30465`                                              |
| `service.nodeport.submission`                     | The port exposed on the node the container is running on, which will be forwarded to docker-mailserver's submission (*SMTP-over-TLS*) port (587)                                     | `30587`                                              |
| `service.nodeport.imaps`                          | The port exposed on the node the container is running on, which will be forwarded to docker-mailserver's IMAPS port (993)                                                            | `30993`                                              |
| `service.nodeport.pop3s`                          | The port exposed on the node the container is running on, which will be forwarded to docker-mailserver's IMAPS port (993)                                                            | `30995`                                              |
| `deployment.replicas`                             | How many instances of the container to deploy (*only 1 supported currently*)                                                                                                         | `1`                                                  |
| `resource.requests.cpu`                           | Initial share of CPU requested per-pod                                                                                                                                               | `1`                                                  |
| `resource.requests.memory`                        | Initial share of RAM requested per-pod (*Initial testing showed clamd would fail due to memory pressure with less than 1.5GB RAM*)                                                   | `1536Mi`                                             |
| `resource.limits.cpu`                             | Maximum share of CPU available per-pod                                                                                                                                               | `2`                                                  |
| `resource.limits.memory`                          | Maximum share of RAM available per-pod                                                                                                                                               | `2048Mi`                                             |
| `persistence.size`                                | How much space to provision for persistent storage                                                                                                                                   | `10Gi`                                               |
| `persistence.annotations`                         | Annotations to add to the persistent storage (*for example, to support [k8s-snapshots](https://github.com/miracle2k/k8s-snapshots)*)                                                 | `{}`                                                 |
| `ssl.issuer.name`                                 | The name of the cert-manager issuer expected to issue certs                                                                                                                          | `letsencrypt-staging`                                |
| `ssl.issuer.kind`                                 | Whether the issuer is namespaced (`Issuer`) on cluster-wide (`ClusterIssuer`)                                                                                                        | `ClusterIssuer`                                      |
| `ssl.dnsname`                                     | DNS domain used for DNS01 validation                                                                                                                                                 | `example.com`                                        |
| `ssl.dns01provider`                               | The cert-manager DNS01 provider (*more details [coming](https://github.com/funkypenguin/docker-mailserver/issues/6)*)                                                                | `cloudflare`                                         |


#### docker-mailserver Configuration

There are **many** environment variables which allow you to customize the behaviour of docker-mailserver. The function of each variable is described at https://github.com/tomav/docker-mailserver#environment-variables

Every variable can be set using `values.yaml`, but note that docker-mailserver expects any true/false values to be set as binary numbers (1/0), rather than boolean (true/false). BadThings(tm) will happen if you try to pass an environment variable as "true" when [`start-mailserver.sh`](https://github.com/tomav/docker-mailserver/blob/master/target/start-mailserver.sh) is expecting a 1 or a 0!

#### Rainloop Configuration

Values you'll definately want to pay attention to:

| Parameter                              | Description                                                                                                                  | Default                                           |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| `rainloop.ingress.hosts` | The hostname(s) to be used via your ingress to access RainLoop | `rainloop.example.com` |



#### HA Proxy-Ingress Configuration

| Parameter                                       | Description                                                                                                                                       | Default                                   |
|-------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------|
| `haproxy-ingress.deploy_chart`                  | Whether to deploy the HAProxy Ingress Controller (recomended)                                                                                     | `true`                                    |
| `haproxy-ingress.controller.kind`               | Whether your controller is a `DaemonSet` or a `Deployment`                                                                                        | `Deployment`                              |
| `haproxy-ingress.enableStaticPorts`             | Whether to enable ports 80 and 443 in addition to the TCP ports we're using below                                                                 | `false`                                   |
| `haproxy-ingress.tcp.25`                        | How to forward inbound TCP connections on port 25. Use syntax `<namespace>/<service name>:<target port>[<optional proxy protocol>]`               | `default/docker-mailserver:25::PROXY-V1`  |
| `haproxy-ingress.tcp.110`                       | How to forward inbound TCP connections on port 110. Use syntax described above.                                                                   | `default/docker-mailserver:25::PROXY-V1`  |
| `haproxy-ingress.tcp.143`                       | How to forward inbound TCP connections on port 143. Use syntax described above.                                                                   | `default/docker-mailserver:143::PROXY-V1` |
| `haproxy-ingress.tcp.465`                       | How to forward inbound TCP connections on port 465. Use syntax described above. PROXY protocol unsupported.                                       | `default/docker-mailserver:465`           |
| `haproxy-ingress.tcp.587`                       | How to forward inbound TCP connections on port 587. Use syntax described above. PROXY protocol unsupported.                                       | `default/docker-mailserver:587`           |
| `haproxy-ingress.tcp.993`                       | How to forward inbound TCP connections on port 993. Use syntax described above.                                                                   | `default/docker-mailserver:993::PROXY-V1` |
| `haproxy-ingress.tcp.995`                       | How to forward inbound TCP connections on port 995. Use syntax described above.                                                                   | `default/docker-mailserver:995::PROXY-V1` |
| `haproxy-ingress.service.externalTrafficPolicy` | Used to preserve source IP per [this doc](https://kubernetes.io/docs/tutorials/services/source-ip/#source-ip-for-services-with-type-loadbalancer) | `Local`                                   |











## Development

### Testing

[Unit tests](https://github.com/lrills/helm-unittest) are created for every chart template. Tests are applied to confirm expected behaviour and interaction between various configurations
(ie haproxy mode and demo mode)

In addition to tests above, a "snapshot" test is created for each manifest file. This permits a final test per-manifest, which confirms that the generated manifest
matches exactly the previous snapshot. If a template change is made, or legit value in values.yaml changes (i.e., the app version) this snapshot test will fail.

If you're comfortable with the changes to the saved snapshot, then regenerate the snapshots, by running the following from the root of the repo

```
helm plugin install https://github.com/lrills/helm-unittest
helm unittest helm-chart/docker-mailserver 
```

