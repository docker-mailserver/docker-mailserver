---
title: 'Mail Forwarding | Relay Hosts'
---

## What is a Relay Host?

An SMTP relay service (_aka relay host / [smarthost][wikipedia::smarthost]_) is an MTA that relays (_forwards_) mail on behalf of third-parties (_it does not manage the mail domains_).

- Instead of DMS handling SMTP delivery directly itself (_via Postfix_), it can be configured to delegate delivery by sending all outbound mail through a relay service.
- Examples of popular mail relay services: [AWS SES][smarthost::aws-ses], [Mailgun][smarthost::mailgun], [Mailjet][smarthost::mailjet], [SendGrid][smarthost::sendgrid]

!!! info "When can a relay service can be helpful?"

    - Your network provider has blocked outbound connections on port 25 (_required for direct delivery_).
    - To improve delivery success via better established reputation (trust) of a relay service.

## Configuration

All mail sent outbound from DMS (_where the sender address is a DMS account or a virtual alias_) will be relayed through the configured relay host.

!!! info "Configuration via ENV"

    Configure the default relayhost with either of these ENV:

    - Preferable (_LDAP compatible_): `DEFAULT_RELAY_HOST` (eg: `[mail.relay-service.com]:25`)
    - `RELAY_HOST` (eg: `mail.relay-service.com`) + `RELAY_PORT` (default: 25)

    Most relay services also require authentication configured:

    - `RELAY_USER` + `RELAY_PASSWORD` provides credentials for authenticating with the default relayhost.

    !!! warning "Providing secrets via ENV"

        While ENV is convenient, the risk of exposing secrets is higher.

        `setup relay add-auth` is a better alternative, which manages the credentials via a config file.

??? tip "Excluding specific sender domains from relay"

    You can opt-out with: `setup relay exclude-domain <domain>`

    Outbound mail from senders of that domain will be sent normally (_instead of through the configured `RELAY_HOST`_).

    !!! warning "When any relay host credentials are configured"

        It will still be expected that mail is sent over a secure connection with credentials provided.

        Thus this opt-out feature is rarely practical.

### Advanced Configuration

When mail is sent, there is support to change the relay service or the credentials configured based on the sender address domain used.

We provide this support via two config files:

- Sender-dependent Relay Host: `docker-data/dms/config/postfix-relaymap.cf`
- Sender-dependent Authentication: `docker-data/dms/config/postfix-sasl-password.cf`

!!! tip "Configure with our `setup relay` commands"

    While you can edit those configs directly, DMS provides these helpful config management commands:

    ```cli-syntax
    # Configure a sender domain to use a specific relay host:
    setup relay add-domain <domain> <host> [<port>]

    # Configure relay host credentials for a sender domain to use:
    setup relay add-auth <domain> <username> [<password>]

    # Optionally avoid relaying from senders of this domain:
    # NOTE: Only supported when configured with the `RELAY_HOST` ENV!
    setup relay exclude-domain <domain>
    ```

!!! example "Config file: `postfix-sasl-password.cf`"

    ```cf-extra title="docker-data/dms/config/postfix-sasl-password.cf"
    @domain1.com        mailgun-user:secret
    @domain2.com        sendgrid-user:secret

    # NOTE: This must have an exact match with the relay host in `postfix-relaymap.cf`,
    # `/etc/postfix/relayhost_map`, or the `DEFAULT_RELAY_HOST` ENV.
    # NOTE: Not supported via our setup CLI, but valid config for Postfix.
    [email-smtp.us-west-2.amazonaws.com]:2587 aws-user:secret
    ```

    When Postfix needs to lookup credentials for mail sent outbound, the above config will:

    - Authenticate as `mailgun-user` for mail sent with a sender belonging to `@domain1.com`
    - Authenticate as `sendgrid-user` for mail sent with a sender belonging to `@domain2.com`
    - Authenticate as `aws-user` for mail sent through a configured AWS SES relay host (any sender domain).

!!! example "Config file: `postfix-relaymap.cf`"

    ```cf-extra title="docker-data/dms/config/postfix-relaymap.cf"
    @domain1.com        [smtp.mailgun.org]:587
    @domain2.com        [smtp.sendgrid.net]:2525

    # Opt-out of relaying:
    @domain3.com
    ```

    When Postfix sends mail outbound from these sender domains, the above config will:

    - Relay mail through `[smtp.mailgun.org]:587` when mail is sent from a sender of `@domain1.com`
    - Relay mail through `[smtp.sendgrid.net]:2525` when mail is sent from a sender of `@domain1.com`
    - Mail with a sender from `@domain3.com` is not sent through a relay (_**Only applicable** when using `RELAY_HOST`_)

### Technical Details

- Both the supported ENV and config files for this feature have additional details covered in our ENV docs [Relay Host section][docs::env-relay].
- For troubleshooting, a [minimal `compose.yaml` config with several DMS instances][dms-gh::relay-example] demonstrates this feature for local testing.
- [Subscribe to this tracking issue][dms-gh::pr-3607] for future improvements intended for this feature.

!!! abstract "Postfix Settings"

    Internally this feature is implemented in DMS by [`relay.sh`][dms-repo::helpers-relay].

    The `relay.sh` script manages configuring these Postfix settings:

    ```cf-extra
    # Send all outbound mail through this relay service:
    relayhost = [smtp.relay-service.com]:587

    # Credentials to use:
    smtp_sasl_password_maps = texthash:/etc/postfix/sasl_passwd
    # Alternative table type examples which do not require a separate file:
    #smtp_sasl_password_maps = static:john.doe@relay-service.com:secret
    #smtp_sasl_password_maps = inline:{ [smtp.relay-service.com]:587=john.doe@relay-service.com:secret }

    ## Authentication support:
    # Required to provide credentials to the relay service:
    smtp_sasl_auth_enable = yes
    # Enforces requiring credentials when sending mail outbound:
    smtp_sasl_security_options = noanonymous
    # Enforces a secure connection (TLS required) to the relay service:
    smtp_tls_security_level = encrypt

    ## Support for advanced requirements:
    # Relay service(s) to use instead of direct delivery for specific sender domains:
    sender_dependent_relayhost_maps = texthash:/etc/postfix/relayhost_map
    # Support credentials to a relay service(s) that vary by relay host used or sender domain:
    smtp_sender_dependent_authentication = yes
    ```


[smarthost::mailgun]: https://www.mailgun.com/
[smarthost::mailjet]: https://www.mailjet.com
[smarthost::sendgrid]: https://sendgrid.com/
[smarthost::aws-ses]: https://aws.amazon.com/ses/
[wikipedia::smarthost]: https://en.wikipedia.org/wiki/Smart_host

[docs::env-relay]: ../../environment.md#relay-host
[dms-repo::helpers-relay]: https://github.com/docker-mailserver/docker-mailserver/blob/v15.0.0/target/scripts/helpers/relay.sh
[dms-gh::pr-3607]: https://github.com/docker-mailserver/docker-mailserver/issues/3607
[dms-gh::relay-example]: https://github.com/docker-mailserver/docker-mailserver/issues/3842#issuecomment-1913380639
