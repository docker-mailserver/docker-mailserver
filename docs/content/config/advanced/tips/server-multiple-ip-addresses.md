---
title: 'Advanced | Tips | Server with multiple IP-addresses'
---

## Server with multiple IP-addresses

!!! warning "Advice not extensively tested"

    This configuration has only been used with `network: host`, where you have direct access to the host interfaces.

If your host system is running multiple IPv4 and IPv6 IP-addresses, you probably have an interest to
bind outgoing SMTP connections to specific IP-addresses to ensure MX records are aligned with
PTR-records in DNS when sending emails to avoid getting blocked by SPF for example.

This can be configured by [overriding the default Postfix configurations](../override-defaults/postfix.md) DMS provides. Create `postfix-master.cf` and `postfix-main.cf` files for your config volume (`docker-data/dms/config`).

In `postfix-main.cf` you'll have to set the [`smtp_bind_address`](https://www.postfix.org/postconf.5.html#smtp_bind_address) and [`smtp_bind_address6`](https://www.postfix.org/postconf.5.html#smtp_bind_address6)
to the respective IP-address on the server you want to use.

!!! example

    ```title="postfix-main.cf"
    smtp_bind_address = 198.51.100.10
    smtp_bind_address6 = 2001:DB8::10
    ```

    **NOTE:** IP-addresses shown above are placeholders, using reserved documentation IP-addresses by IANA, [RFC-5737](https://datatracker.ietf.org/doc/rfc5737/) and [RFC-3849](https://datatracker.ietf.org/doc/html/rfc3849).

One problem with using `smtp_bind_address` is that the default configuration for `smtp-amavis` in
DMS needs to be updated to explicitly connect via loopback (localhost), which avoids using
the `smtp_bind_address` as source address when "forwarding" email for filtering via Amavis.

!!! example

    ```title="postfix-master.cf"
    smtp-amavis/unix/smtp_bind_address=127.0.0.1
    smtp-amavis/unix/smtp_bind_address6=::1
    ```

This seems to be a better approach than adding your bind-addresses to `mynetworks` parameter in
Postfix `postfix-main.cf`.


