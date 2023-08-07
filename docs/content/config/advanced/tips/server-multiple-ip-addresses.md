---
title: 'Advanced | Tips | Server with multiple IP-addresses'
---

## Server with multiple IP-addresses

!!! warning "Only tested with docker configuration running with network-mode: host"

    This configuration has only been tested with network: host where you have direct access to the host interfaces.

If your host system is running multiple IPv4 and IPv6 IP-addresses, you probably have an interest to
bind outgoing SMTP connections to specific IP-addresses to ensure MX records are aligned with
PTR-records in DNS when sending emails to avoid getting blocked by SPF for example.

We can use the tricks of [overriding defaults in postfix configuration](../override-defaults/postfix.md)
by supplying a custom `docker-data/dms/config/postfix-master.cf` and `docker-data/dms/config/postfix-main.cf`.

In `postfix-main.cf` you'll have to set the [smtp_bind_address](https://www.postfix.org/postconf.5.html#smtp_bind_address) and [smtp_bind_address6](https://www.postfix.org/postconf.5.html#smtp_bind_address6)
to the respective IP-address on the server you want to use.

!!! info "IP-addresses shown below are reserved documentation IP-addresses by IANA, [RFC-5737](https://datatracker.ietf.org/doc/rfc5737/) and [RFC-3849](https://datatracker.ietf.org/doc/html/rfc3849)."

Example `postfix-main.cf`:

```
smtp_bind_address = 198.51.100.10
smtp_bind_address6 = 2001:DB8::10
```

One problem with using `smtp_bind_address` is that the default configuration for `smtp-amavis` in
DMS needs to be updated & explicit configured to connect via loopback (localhost) to avoid using
the `smtp_bind_address` as source address when "forwarding" email for filtering via amavis.
This seems to be a better configuration than adding your bind-addresses to `mynetworks` configuration in
Postfix.

Example `postfix-master.cf`:

```
smtp-amavis/unix/smtp_bind_address=127.0.0.1
smtp-amavis/unix/smtp_bind_address6=::1
```


