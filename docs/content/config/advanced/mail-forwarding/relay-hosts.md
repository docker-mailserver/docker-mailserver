---
title: 'Mail Forwarding | Relay Hosts'
---

## Introduction

Rather than having Postfix deliver mail directly, you can configure Postfix to send mail via another mail relay (smarthost). Examples include [Mailgun](https://www.mailgun.com/), [Sendgrid](https://sendgrid.com/) and [AWS SES](https://aws.amazon.com/ses/).

Depending on the domain of the sender, you may want to send via a different relay, or authenticate in a different way.

## Basic Configuration

Basic configuration is done via environment variables:

- `RELAY_HOST`: _default host to relay mail through, `empty` (aka '', or no ENV set) will disable this feature_
- `RELAY_PORT`: _port on default relay, defaults to port 25_
- `RELAY_USER`: _username for the default relay_
- `RELAY_PASSWORD`: _password for the default user_

Setting these environment variables will cause mail for all sender domains to be routed via the specified host, authenticating with the user/password combination.

!!! warning
    For users of the previous `AWS_SES_*` variables: please update your configuration to use these new variables, no other configuration is required.

## Advanced Configuration

### Sender-dependent Authentication

Sender dependent authentication is done in `docker-data/dms/config/postfix-sasl-password.cf`. You can create this file manually, or use:

```sh
setup.sh relay add-auth <domain> <username> [<password>]
```

An example configuration file looks like this:

```txt
@domain1.com           relay_user_1:password_1
@domain2.com           relay_user_2:password_2
```

If there is no other configuration, this will cause Postfix to deliver email through the relay specified in `RELAY_HOST` env variable, authenticating as `relay_user_1` when sent from `domain1.com` and authenticating as `relay_user_2` when sending from `domain2.com`.

!!! note
    To activate the configuration you must either restart the container, or you can also trigger an update by modifying a mail account.

### Sender-dependent Relay Host

Sender dependent relay hosts are configured in `docker-data/dms/config/postfix-relaymap.cf`. You can create this file manually, or use:

```sh
setup.sh relay add-domain <domain> <host> [<port>]
```

An example configuration file looks like this:

```txt
@domain1.com        [relay1.org]:587
@domain2.com        [relay2.org]:2525
```

Combined with the previous configuration in `docker-data/dms/config/postfix-sasl-password.cf`, this will cause Postfix to deliver mail sent from `domain1.com` via `relay1.org:587`, authenticating as `relay_user_1`, and mail sent from `domain2.com` via `relay2.org:2525` authenticating as `relay_user_2`.

!!! note
    You still have to define `RELAY_HOST` to activate the feature

### Excluding Sender Domains

If you want mail sent from some domains to be delivered directly, you can exclude them from being delivered via the default relay by adding them to `docker-data/dms/config/postfix-relaymap.cf` with no destination. You can also do this via:

```sh
setup.sh relay exclude-domain <domain>
```

Extending the configuration file from above:

```txt
@domain1.com        [relay1.org]:587
@domain2.com        [relay2.org]:2525
@domain3.com
```

This will cause email sent from `domain3.com` to be delivered directly.
