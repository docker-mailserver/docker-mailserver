---
title: 'Tutorials | Crowdsec'
---

!!! quote "What is Crowdsec?"
    
    Crowdsec is an open source software that detects and blocks attackers using log analysis.
    It has access to a global community-wide IP reputation database.

    [Source](https://www.crowdsec.net)

## Installation

Crowdsec supports multiple [installation methods][crowdsec-installation-docs], however this page will use the docker installation.


### Docker mailserver

In your `compose.yaml` for the DMS service, add a bind mount volume for `/var/log/mail`. This is to share the DMS logs to a separate crowdsec container.

!!! example 
    ```yaml
    services:
      mailserver:
          - /docker-data/dms/mail-logs/:/var/log/mail/
    ```

### Crowdsec

The crowdsec container should also bind mount the same host path for the DMS logs that was added in the DMS example above.

```yaml
services:
  image: crowdsecurity/crowdsec
  restart: unless-stopped
  ports:
    - "8080:8080"
    - "6060:6060"
  volumes:
    - /docker-data/dms/mail-logs/:/var/log/dms:ro
    - ./acquis.d:/etc/crowdsec/acquis.d
    - crowdsec-db:/var/lib/crowdsec/data/
  environment:
    # These collection contains parsers and scenarios for postfix and dovecot
    COLLECTIONS: crowdsecurity/postfix crowdsecurity/dovecot
    TZ: Europe/Paris
volumes:
  crowdsec-db:
```

## Configuration

Configure crowdsec to read and parse DMS logs file.

!!! example

    Create the file `dms.yml` in `./acquis.d/`
    
    ```yaml
    ---
    source: file
    filenames:
      - /var/log/dms/mail.log
    labels:
      type: syslog
    ```

!!! warning Bouncers

    Crowdsec on its own is just a detection software, the remediation is done by components called bouncers.
    This page does not explain how to install or configure a bouncer. It can be found in [crowdsec documentation][crowdsec-bouncer-docs].

[crowdsec-installation-docs]: https://doc.crowdsec.net/docs/getting_started/install_crowdsec
[crowdsec-bouncer-docs]: https://doc.crowdsec.net/docs/bouncers/intro
