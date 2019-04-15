## What do we want to test?

[![Build Status](https://travis-ci.org/funkypenguin/docker-mailserver.svg?branch=add-helm-chart)](https://travis-ci.org/funkypenguin/docker-mailserver)

### Upstream container

```
[ ] If we set image tag to latest release rather than 'latest', does it still work?
```

### Demo mode

```
[x] When setting demo mode, does chart get deployed with expected demo data? (I.e., it's ready for use)
[x] When disabling demo mode, does chart correctly input the expected config variables?
```

### HA Proxy mode

```
[x] When setting haproxy mode to "enabled", do the appropriate settings make their way into configmaps? Is the reverse true?
[ ] If in external-auto mode, do the correct SEND_PROXY environment variables get set? Is the reverse true? (hard to test results of subchart?)
[ ] If in ingress mode, do the correct SEND_PROXY settings get set? (hard to test results of subchart?)
[X] If both haproxy.enabled and haproxy.mode=external auto are not set, then don't create phonehome deployment
```

### Disable SPF

```
[ ] User is able to disable SPF checks (if they don't want to use haproxy)
```


## What must be tested manually, end-to-end?

```
[ ] Deploying in demo mode with external-auth haproxy
[ ] Deploying in demo mode with external-manual haproxy
[ ] Deploying in demo mode with ingress haproxy
[ ] Deploying in non-demo mode with external-auth haproxy
[ ] Deploying in non-demo mode with external-manual haproxy
[ ] Deploying in non-demo mode with ingress haproxy
```
