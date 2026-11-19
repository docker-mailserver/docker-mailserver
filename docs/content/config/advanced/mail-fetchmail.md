---
title: 'Advanced | Email Gathering with Fetchmail'
---

To enable the [fetchmail][fetchmail-website] service to retrieve e-mails, set the environment variable `ENABLE_FETCHMAIL` to `1`. Your `compose.yaml` file should look like following snippet:

```yaml
environment:
  - ENABLE_FETCHMAIL=1
  - FETCHMAIL_POLL=300
```

Generate a file called `fetchmail.cf` and place it in the `docker-data/dms/config/` folder. Your DMS folder should look like this example:

```txt
├── docker-data/dms/config
│   ├── dovecot.cf
│   ├── fetchmail.cf
│   ├── postfix-accounts.cf
│   └── postfix-virtual.cf
└── compose.yaml
```

## Configuration

Configuration options for `fetchmail.cf` are covered at the [official fetchmail docs][fetchmail-docs-config] (_see the section "The run control file" and the table with "keyword" column for all settings_).

!!! example "Basic `fetchmail.cf` configuration"

    Retrieve mail from `remote-user@somewhere.com` and deliver it to `dms-user@example.com`:

    ```fetchmailrc
    poll 'mail.somewhere.com'
    proto imap
    user 'remote-user'
    pass 'secret'
    is 'dms-user@example.com'
    ```

    - `poll` sets the remote mail server to connect to retrieve mail from.
    - `proto` lets you connect via IMAP or POP3.
    - `user` and `pass` provide the login credentials for the remote mail service account to access.
    - `is` configures where the fetched mail will be sent to (_eg: your local DMS account in `docker-data/dms/config/postfix-accounts.cf`_).

    ---

    ??? warning "`proto imap` will still delete remote mail once fetched"

        This is due to a separate default setting `no keep`. Adding the setting `keep` to your config on a new line will prevent deleting the remote copy.

??? example "Multiple users or remote servers"

    The official docs [config examples][fetchmail-config-examples] show a common convention to indent settings on subsequent lines for visually grouping per server.

    === "Minimal syntax"

        ```fetchmailrc
        poll 'mail.somewhere.com' proto imap
          user 'john.doe' pass 'secret' is 'johnny@example.com'
          user 'jane.doe' pass 'secret' is 'jane@example.com'

        poll 'mail.somewhere-else.com' proto pop3
          user 'john.doe@somewhere-else.com' pass 'secret' is 'johnny@example.com'
        ```

    === "With optional syntax"

        - `#` for adding comments.
        - The config file may include "noise" keywords to improve readability.

        ```fetchmailrc
        # Retrieve mail for users `john.doe` and `jane.doe` via IMAP at this remote mail server:
        poll 'mail.somewhere.com' with proto imap wants:
          user 'john.doe' with pass 'secret', is 'johnny@example.com' here
          user 'jane.doe' with pass 'secret', is 'jane@example.com' here

        # Also retrieve mail from this mail server (but via POP3).
        # NOTE: This could also be all on a single line, or with each key + value as a separate line.
        # Notice how the remote username includes a full email address,
        # Some mail servers like DMS use the full email address as the username:
        poll 'mail.somewhere-else.com' with proto pop3 wants:
          user 'john.doe@somewhere-else.com' with pass 'secret', is 'johnny@example.com' here
        ```

!!! tip "`FETCHMAIL_POLL` ENV: Override default polling interval"

    By default the fetchmail service will check every 5 minutes for new mail at the configured mail accounts.

    ```yaml
    environment:
      # The fetchmail polling interval in seconds:
      FETCHMAIL_POLL: 60
    ```

## Debugging

To debug your `fetchmail.cf` configuration run this `setup debug` command:

```sh
docker exec -it dms-container-name setup debug fetchmail
```

??? example "Sample output of `setup debug fetchmail`"

    ```log
    fetchmail: 6.3.26 querying outlook.office365.com (protocol POP3) at Mon Aug 29 22:11:09 2016: poll started
    Trying to connect to 132.245.48.18/995...connected.
    fetchmail: Server certificate:
    fetchmail: Issuer Organization: Microsoft Corporation
    fetchmail: Issuer CommonName: Microsoft IT SSL SHA2
    fetchmail: Subject CommonName: outlook.com
    fetchmail: Subject Alternative Name: outlook.com
    fetchmail: Subject Alternative Name: *.outlook.com
    fetchmail: Subject Alternative Name: office365.com
    fetchmail: Subject Alternative Name: *.office365.com
    fetchmail: Subject Alternative Name: *.live.com
    fetchmail: Subject Alternative Name: *.internal.outlook.com
    fetchmail: Subject Alternative Name: *.outlook.office365.com
    fetchmail: Subject Alternative Name: outlook.office.com
    fetchmail: Subject Alternative Name: attachment.outlook.office.net
    fetchmail: Subject Alternative Name: attachment.outlook.officeppe.net
    fetchmail: Subject Alternative Name: *.office.com
    fetchmail: outlook.office365.com key fingerprint: 3A:A4:58:42:56:CD:BD:11:19:5B:CF:1E:85:16:8E:4D
    fetchmail: POP3< +OK The Microsoft Exchange POP3 service is ready. [SABFADEAUABSADAAMQBDAEEAMAAwADAANwAuAGUAdQByAHAAcgBkADAAMQAuAHAAcgBvAGQALgBlAHgAYwBoAGEAbgBnAGUAbABhAGIAcwAuAGMAbwBtAA==]
    fetchmail: POP3> CAPA
    fetchmail: POP3< +OK
    fetchmail: POP3< TOP
    fetchmail: POP3< UIDL
    fetchmail: POP3< SASL PLAIN
    fetchmail: POP3< USER
    fetchmail: POP3< .
    fetchmail: POP3> USER user1@outlook.com
    fetchmail: POP3< +OK
    fetchmail: POP3> PASS *
    fetchmail: POP3< +OK User successfully logged on.
    fetchmail: POP3> STAT
    fetchmail: POP3< +OK 0 0
    fetchmail: No mail for user1@outlook.com at outlook.office365.com
    fetchmail: POP3> QUIT
    fetchmail: POP3< +OK Microsoft Exchange Server 2016 POP3 server signing off.
    fetchmail: 6.3.26 querying outlook.office365.com (protocol POP3) at Mon Aug 29 22:11:11 2016: poll completed
    fetchmail: normal termination, status 1
    ```

??? tip "Troubleshoot with this reference `compose.yaml`"

    This `compose.yaml` runs two instances of DMS locally. `dms-fetch` is configured with `fetchmail.cf`, `dms-remote` simulates the remote mail server to fetch from. No DNS records are needed.

    ```yaml title="compose.yaml"
    services:
      dms-fetch:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        hostname: mail.example.test
        environment:
          ENABLE_FETCHMAIL: 1
          # Shortened for quicker testing:
          FETCHMAIL_POLL: 10
        # Resolve `remote.test` (the domain of the `@remote.test` address) to the `dms-remote` container.
        # This is a Docker internal DNS feature, only needed because no real DNS service is configured:
        links:
          - "dms-remote:remote.test"
        # Only publish ports if you want to verify with your own mail client:
        #ports:
        #  - "465:465"  # ESMTP (implicit TLS)
        #  - "993:993"  # IMAP4 (implicit TLS)
        # You would normally use `volumes`, all config is part of `compose.yaml` for simplicity:
        configs:
          - source: dms-accounts-fetch
            target: /tmp/docker-mailserver/postfix-accounts.cf
          - source: fetchmail
            target: /tmp/docker-mailserver/fetchmail.cf

      dms-remote:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        hostname: mail.remote.test
        environment:
          # Trust any mail client run within this container (`swaks`), to send a test mail easily:
          DMS_TRUSTED_NETWORKS: host
        configs:
          - source: dms-accounts-remote
            target: /tmp/docker-mailserver/postfix-accounts.cf

    # Requires Docker Compose v2.23.1 (Nov 2023) or newer:
    # https://github.com/compose-spec/compose-spec/pull/446
    configs:
      fetchmail:
        content: |
          poll 'mail.remote.test' proto imap
            user 'jane.doe@remote.test'
            pass 'secret'
            is 'john.doe@example.test'
            no sslcertck

      # DMS requires an account to complete setup, configure one for each instance.
      # Both accounts use the password `secret` (SHA512-CRYPT hashed).
      # NOTE: `$` is repeated to escape it, which opts out of `compose.yaml` variable interpolation.
      dms-accounts-fetch:
        content: |
          john.doe@example.test|{SHA512-CRYPT}$$6$$sbgFRCmQ.KWS5ryb$$EsWrlYosiadgdUOxCBHY0DQ3qFbeudDhNMqHs6jZt.8gmxUwiLVy738knqkHD4zj4amkb296HFqQ3yDq4UXt8.

      dms-accounts-remote:
        content: |
          jane.doe@remote.test|{SHA512-CRYPT}$$6$$sbgFRCmQ.KWS5ryb$$EsWrlYosiadgdUOxCBHY0DQ3qFbeudDhNMqHs6jZt.8gmxUwiLVy738knqkHD4zj4amkb296HFqQ3yDq4UXt8.
    ```

    Start both containers and send a test mail to the remote account `jane.doe@remote.test`:

    ```sh
    docker compose up -d

    docker compose exec dms-remote swaks --server localhost \
      --from sender@remote.test --to jane.doe@remote.test
    ```

    Within `FETCHMAIL_POLL` seconds, `dms-fetch` retrieves the mail and delivers it to `john.doe@example.test`:

    ```sh
    docker compose logs dms-fetch | grep 'fetchmail\['
    docker compose exec dms-fetch find /var/mail/example.test/john.doe -type f -path '*/new/*'
    ```

    Polls that happen before `dms-remote` is ready log connection errors, which is expected.

[fetchmail-website]: https://www.fetchmail.info
[fetchmail-docs-config]: https://www.fetchmail.info/fetchmail-man.html#the-run-control-file
[fetchmail-config-examples]: https://www.fetchmail.info/fetchmail-man.html#configuration-examples
