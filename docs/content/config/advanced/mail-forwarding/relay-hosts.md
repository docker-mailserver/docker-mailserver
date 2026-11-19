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
- [Subscribe to this tracking issue][dms-gh::pr-3607] for future improvements intended for this feature.

??? example "Local test setup with several DMS instances"

    This `compose.yaml` runs three DMS instances locally to demonstrate the relay feature, without any DNS records or external services:

    - `dms-sender` is your DMS, configured to relay all outbound mail.
    - `dms-relay` simulates the third-party relay service.
    - `dms-destination` simulates the mail server of the recipient.

    The TLS certificates use the `.test` TLD, which avoids accidental external DNS requests. Everything is part of one file (_via the `configs` feature_), copy and paste is all you need.

    ```yaml title="compose.yaml"
    services:
      # This would represent your actual DMS container:
      dms-sender:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        hostname: mail.example.test
        environment:
          # All outbound mail will be relayed through this host
          # (change the port to 587 if you do not want the postfix-main.cf override)
          - DEFAULT_RELAY_HOST=[smtp.relay-service.test]:465
          # Your relay host credentials.
          # (since the relay in the example is DMS, the relay account username is a full email address)
          - RELAY_USER=relay-user@relay-service.test
          - RELAY_PASSWORD=secret
          # The mail client (swaks) needs to connect with TLS:
          - SSL_TYPE=manual
          - SSL_KEY_PATH=/tmp/tls/key.pem
          - SSL_CERT_PATH=/tmp/tls/cert.pem
        # You would usually have `volumes` instead of this `configs`:
        configs:
          - source: dms-main
            target: /tmp/docker-mailserver/postfix-main.cf
          - source: dms-accounts
            target: /tmp/docker-mailserver/postfix-accounts.cf
          # Authenticating on port 587 or 465 enforces TLS requirement:
          - source: tls-cert
            target: /tmp/tls/cert.pem
          - source: tls-key
            target: /tmp/tls/key.pem
          # This is only needed if you want to verify the TLS cert chain with swaks
          # (normally with public CA providers like LetsEncrypt this file is already available to a mail client)
          - source: tls-ca-cert
            target: /tmp/tls/ca-cert.pem

      # Pretend this is your third-party relay service:
      dms-relay:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        hostname: smtp.relay-service.test
        environment:
          # WORKAROUND: Bypass security checks from the mail-client (dms-sender container)
          # (avoids needing expected DNS records to run this example)
          - DMS_TRUSTED_NETWORKS=subnet
          # TLS is required when relaying to dms-relay via ports 587 / 465
          # (dms-relay will then relay the mail to dms-destination over port 25)
          - SSL_TYPE=manual
          - SSL_KEY_PATH=/tmp/tls/key.pem
          - SSL_CERT_PATH=/tmp/tls/cert.pem
        configs:
          - source: dms-accounts-relay
            target: /tmp/docker-mailserver/postfix-accounts.cf
          - source: tls-cert
            target: /tmp/tls/cert.pem
          - source: tls-key
            target: /tmp/tls/key.pem

      # Pretend this is another mail server that your target recipient belongs to (like Gmail):
      dms-destination:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        hostname: mail.destination.test
        # WORKAROUND: dms-relay must be able to resolve DNS for `@destination.test` to the IP of this container:
        # Normally a MX record would direct mail to the MTA (eg: `mail.destination.test`)
        networks:
          default:
            aliases:
              - destination.test
        environment:
          # WORKAROUND: Same workaround as needed for dms-relay
          - DMS_TRUSTED_NETWORKS=subnet
        configs:
          - source: dms-accounts-destination
            target: /tmp/docker-mailserver/postfix-accounts.cf

    # Using the Docker Compose `configs.content` feature instead of volume mounting separate files.
    # NOTE: This feature requires Docker Compose v2.23.1 (Nov 2023) or newer:
    # https://github.com/compose-spec/compose-spec/pull/446
    configs:
      # `postfix-main.cf`, a single line change to make all outbound SMTP connections over implicit TLS instead of the default explicit TLS (StartTLS).
      # NOTE: If you need to only selectively relay mail, you would need to instead adjust this on the relay service in `/etc/postfix/master.cf`,
      # However DMS presently modifies this when using the DMS Relay Host feature support, which may override `postfix-master.cf` or `user-patches.sh` due to `check-for-changes.sh`.
      dms-main:
        content: |
          smtp_tls_wrappermode=yes

      # DMS expects an account to be configured to run, this example provides accounts already created.
      # Login credentials:
      # user: "john.doe@example.test" password: "secret"
      # user: "relay-user@relay-service.test" password: "secret"
      # user: "jane.doe@destination.test" password: "secret"
      dms-accounts:
        # NOTE: `$` needed to be repeated to escape it,
        # which opts out of the `compose.yaml` variable interpolation feature.
        content: |
          john.doe@example.test|{SHA512-CRYPT}$$6$$sbgFRCmQ.KWS5ryb$$EsWrlYosiadgdUOxCBHY0DQ3qFbeudDhNMqHs6jZt.8gmxUwiLVy738knqkHD4zj4amkb296HFqQ3yDq4UXt8.

      dms-accounts-relay:
        content: |
          relay-user@relay-service.test|{SHA512-CRYPT}$$6$$o65y1ZXC4ooOPLwZ$$7TF1nYowEtNJpH6BwJBgdj2pPAxaCvhIKQA6ww5zdHm/AA7aemY9eoHC91DOgYNaKj1HLxSeWNDdvrp6mbtUY.

      dms-accounts-destination:
        content: |
          jane.doe@destination.test|{SHA512-CRYPT}$$6$$o65y1ZXC4ooOPLwZ$$7TF1nYowEtNJpH6BwJBgdj2pPAxaCvhIKQA6ww5zdHm/AA7aemY9eoHC91DOgYNaKj1HLxSeWNDdvrp6mbtUY.

      # TLS files:
      # - Use an ECDSA cert that's been signed by a self-signed CA for TLS cert verification.
      # - This cert is only valid for mail.example.test, mail.destination.test, smtp.relay-service.test

      # `swaks` run in the container will need to reference this CA cert file for successful verification (optional).
      tls-ca-cert:
        content: |
          -----BEGIN CERTIFICATE-----
          MIIBfTCCASKgAwIBAgIRAMAZttlRlkcuSun0yV0z4RwwCgYIKoZIzj0EAwIwHDEa
          MBgGA1UEAxMRU21hbGxzdGVwIFJvb3QgQ0EwHhcNMjEwMTAxMDAwMDAwWhcNMzEw
          MTAxMDAwMDAwWjAcMRowGAYDVQQDExFTbWFsbHN0ZXAgUm9vdCBDQTBZMBMGByqG
          SM49AgEGCCqGSM49AwEHA0IABJX2hCtoK3+bM5I3rmyApXLJ1gOcVhtoSSwM8XXR
          SEl25Kkc0n6mINuMK8UrBkiBUgexf6CYayx3xVr9TmMkg4KjRTBDMA4GA1UdDwEB
          /wQEAwIBBjASBgNVHRMBAf8ECDAGAQH/AgEBMB0GA1UdDgQWBBQD8sBrApbyYyqU
          y+/TlwGynx2V5jAKBggqhkjOPQQDAgNJADBGAiEAi8N2eOETI+6hY3+G+kzNMd3K
          Sd3Ke8b++/nlwr5Fb/sCIQDYAjpKp/MpTDWICeHC2tcB5ptxoTdWkTBuG4rKcktA
          0w==
          -----END CERTIFICATE-----

      tls-key:
        content: |
          -----BEGIN EC PRIVATE KEY-----
          MHcCAQEEIOc6wqZmSDmT336K4O26dMk1RCVc0+cmnsO2eK4P5K5yoAoGCCqGSM49
          AwEHoUQDQgAEFOWNgekKKvUZE89vJ7henUYxODYIvCiHitRc2ylwttjqt1KUY1cp
          q3jof2fhURHfBUH3dHPXLHig5V9Jw5gqeg==
          -----END EC PRIVATE KEY-----

      tls-cert:
        content: |
          -----BEGIN CERTIFICATE-----
          MIIB9DCCAZqgAwIBAgIQE53a/y2c//YXRsz2kLm6gDAKBggqhkjOPQQDAjAcMRow
          GAYDVQQDExFTbWFsbHN0ZXAgUm9vdCBDQTAeFw0yMTAxMDEwMDAwMDBaFw0zMTAx
          MDEwMDAwMDBaMBkxFzAVBgNVBAMTDlNtYWxsc3RlcCBMZWFmMFkwEwYHKoZIzj0C
          AQYIKoZIzj0DAQcDQgAEFOWNgekKKvUZE89vJ7henUYxODYIvCiHitRc2ylwttjq
          t1KUY1cpq3jof2fhURHfBUH3dHPXLHig5V9Jw5gqeqOBwDCBvTAOBgNVHQ8BAf8E
          BAMCB4AwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsGAQUFBwMCMB0GA1UdDgQWBBSz
          w74g+O6dcBbwienD70D8A9ESmDAfBgNVHSMEGDAWgBQD8sBrApbyYyqUy+/TlwGy
          nx2V5jBMBgNVHREERTBDghFtYWlsLmV4YW1wbGUudGVzdIIVbWFpbC5kZXN0aW5h
          dGlvbi50ZXN0ghdzbXRwLnJlbGF5LXNlcnZpY2UudGVzdDAKBggqhkjOPQQDAgNI
          ADBFAiEAoety5oClZtuBMkvlUIWRmWlyg1VIOZ544LSEbplsIhcCIHb6awMwNdXP
          m/xHjFkuwH1+UjDDRW53Ih7KZoLrQ6Cp
          -----END CERTIFICATE-----
    ```

    Start all containers and send a test mail from `dms-sender` to `dms-destination` via `dms-relay`. `swaks` acts as your mail client here:

    ```sh
    docker compose up -d --force-recreate

    docker compose exec dms-sender swaks --ehlo mail.example.test --server mail.example.test \
      --port 587 -tls \
      --auth PLAIN --auth-user john.doe@example.test --auth-password secret \
      --from john.doe@example.test --to jane.doe@destination.test

    # The logs show that the mail was sent, relayed and delivered:
    docker compose logs
    ```

    - Authenticate on port 465 instead with `--port 465 -tlsc` (_the additional `c` is not a typo_).
    - To verify the TLS certificate chain, add `--tls-ca-path /tmp/tls/ca-cert.pem`.

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
[dms-repo::helpers-relay]: https://github.com/docker-mailserver/docker-mailserver/blob/v17.0.0/target/scripts/helpers/relay.sh
[dms-gh::pr-3607]: https://github.com/docker-mailserver/docker-mailserver/issues/3607
