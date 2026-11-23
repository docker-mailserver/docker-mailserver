---
title: 'Account Management | Restrict Senders and Recipients'
---

The `setup email restrict` command makes Postfix reject mail **from** specific senders or **to** specific recipients. It manages two lists of addresses, one for each direction. Mail with an address that matches an entry is refused with a permanent SMTP error (`554 5.7.1 ... Access denied`).

!!! info "Usage"

    ```bash
    docker exec -ti <CONTAINER NAME> setup email restrict <add|del|list> <send|receive> [<ADDRESS>]
    ```

    - `add` appends `<ADDRESS>` to the list with the result `REJECT`.
    - `del` removes the lines that start with `<ADDRESS>`.
    - `list` prints the entries of the list (_the lines that contain `REJECT`_), or `Everyone is allowed to send mails` / `Everyone is allowed to receive mails` when there are none.
    - `<ADDRESS>` is asked for interactively when it is missing from `add` or `del`.

    ---

    - `send` is the list for the **sender** of a mail. It is checked against the envelope sender (`MAIL FROM`, not the `From:` header) with [`check_sender_access`][postfix-docs::check-sender-access] in `dms_smtpd_sender_restrictions`, which applies to mail arriving on ports 25, 587 and 465.
    - `receive` is the list for the **recipient** of a mail. It is checked against the envelope recipient (`RCPT TO`) with [`check_recipient_access`][postfix-docs::check-recipient-access] in `smtpd_recipient_restrictions`.

    Both checks come before the `permit` rules that DMS configures, so they also apply to authenticated users and to clients from trusted networks.

!!! example

    ```bash
    # Run inside the container, or prefix each command with `docker exec -ti <CONTAINER NAME>`.

    # Reject mail that is sent from this address:
    setup email restrict add send spammer@example.com

    # Reject mail that is sent to this address:
    setup email restrict add receive retired@example.com

    # Show the entries of a list:
    setup email restrict list send

    # Remove an entry again:
    setup email restrict del send spammer@example.com
    ```

## Addresses

DMS does not validate `<ADDRESS>`, it is written to the list as given. Postfix reads the lists as [`access(5)`][postfix-docs::access] tables, which support these patterns:

- `user@example.com`: this exact address.
- `example.com`: every address with this domain. Whether this also matches subdomains depends on the Postfix setting [`parent_domain_matches_subdomains`][postfix-docs::parent-domain-matches-subdomains], see the `access(5)` documentation.
- `user@`: this local part with any domain.

Entries match addresses, not accounts. An alias of an account is a different address and needs its own entry.

## Config Files

The lists are stored in the [config volume][docs::optional-config::volumes-config], and the first `add` for a direction creates the file:

- `docker-data/dms/config/postfix-send-access.cf` for `send`
- `docker-data/dms/config/postfix-receive-access.cf` for `receive`

Each line holds an address and the result:

```cf title="docker-data/dms/config/postfix-send-access.cf"
spammer@example.com    REJECT
```

You can edit these files yourself instead of using the command. The command only writes `REJECT`, but Postfix accepts any other `access(5)` result in these files too. As the checks come before the other restrictions that DMS configures, use such results with care.

!!! warning "Do not delete the files"

    Once the check is part of `/etc/postfix/main.cf`, it stays there across container restarts (_DMS skips its setup_), even when the file is gone. Postfix then cannot open the table, and according to its documented behavior it defers the mail on the affected ports with a temporary lookup error (`451 4.3.0`). To lift all restrictions of a list, empty its file instead of deleting it, or recreate the container (_for example with `docker compose up -d --force-recreate`_).

## When Does a Change Take Effect?

- **The first `add` for a list** on a running container adds the check to the front of the Postfix restriction list in `/etc/postfix/main.cf` and reloads Postfix. The restriction is active right away on ports 25, 587 and 465.
- **Later `add` and `del` commands** and **manual edits** of the files only change the file, Postfix is not reloaded. Postfix reads such a file ([`texthash:`][postfix-docs::lookup-table-changes]) once when a process starts, so an `smtpd` process that is already running keeps the old content until it exits. By default, that happens after 100 seconds without a connection or after 100 connections ([`max_idle`][postfix-docs::max-idle], [`max_use`][postfix-docs::max-use]). To apply a change right away, run `docker exec <CONTAINER NAME> postfix reload`.
- **When a new container starts**, DMS adds the checks to the Postfix configuration for each file that exists in the config volume. The change detection service does not monitor these two files.

## Limitations

- Only denying is supported by the command, there is no way to allow an address with it, and `list` only prints the lines that contain `REJECT`.
- `add` refuses an entry when its text is already part of any line of the list, for example `example.com` while `user@example.com` is listed. Edit the file by hand in that case.
- `del` removes every line that starts with the given text (_`user@example.com` also removes `user@example.com.au`_), and it reports no error when no line matches.
- `setup email restrict help` is not supported, it prints the usage line followed by an error.

[docs::optional-config::volumes-config]: ../../advanced/optional-config.md#volumes-config
[postfix-docs::access]: https://www.postfix.org/access.5.html
[postfix-docs::check-recipient-access]: https://www.postfix.org/postconf.5.html#check_recipient_access
[postfix-docs::check-sender-access]: https://www.postfix.org/postconf.5.html#check_sender_access
[postfix-docs::lookup-table-changes]: https://www.postfix.org/DATABASE_README.html#detect
[postfix-docs::max-idle]: https://www.postfix.org/postconf.5.html#max_idle
[postfix-docs::max-use]: https://www.postfix.org/postconf.5.html#max_use
[postfix-docs::parent-domain-matches-subdomains]: https://www.postfix.org/postconf.5.html#parent_domain_matches_subdomains
