---
title: 'Best Practices | SPF'
hide:
  - toc # Hide Table of Contents for this page
---

From [Wikipedia](https://en.wikipedia.org/wiki/Sender_Policy_Framework):

!!! quote
    Sender Policy Framework (SPF) is a simple email-validation system designed to detect email spoofing by providing a mechanism to allow receiving mail exchangers to check that incoming mail from a domain comes from a host authorized by that domain's administrators. The list of authorized sending hosts for a domain is published in the Domain Name System (DNS) records for that domain in the form of a specially formatted TXT record. Email spam and phishing often use forged "from" addresses, so publishing and checking SPF records can be considered anti-spam techniques.

!!! note
    For a more technical review: https://github.com/internetstandards/toolbox-wiki/blob/master/SPF-how-to.md

## Add a SPF Record

To add a SPF record in your DNS, insert the following line in your DNS zone:

```txt
; MX record must be declared for SPF to work
example.com. IN  MX 1 mail.example.com.

; SPF record
example.com. IN TXT "v=spf1 mx ~all"
```

This enables the _Softfail_ mode for SPF. You could first add this SPF record with a very low TTL.

_SoftFail_ is a good setting for getting started and testing, as it lets all email through, with spams tagged as such in the mailbox.

After verification, you _might_ want to change your SPF record to `v=spf1 mx -all` so as to enforce the _HardFail_ policy. See http://www.open-spf.org/SPF_Record_Syntax for more details about SPF policies.

In any case, increment the SPF record's TTL to its final value.

## Backup MX, Secondary MX

For whitelisting a IP Address from the SPF test, you can create a config file (see [`policyd-spf.conf`](https://www.linuxcertif.com/man/5/policyd-spf.conf)) and mount that file into `/etc/postfix-policyd-spf-python/policyd-spf.conf`.

**Example:**

Create and edit a `policyd-spf.conf` file at `docker-data/dms/config/postfix-policyd-spf.conf`:

```conf
debugLevel = 1
#0(only errors)-4(complete data received)

skip_addresses = 127.0.0.0/8,::ffff:127.0.0.0/104,::1

# Preferably use IP-Addresses for whitelist lookups:
Whitelist = 192.168.0.0/31,192.168.1.0/30
# Domain_Whitelist = mx1.not-example.com,mx2.not-example.com
```

Then add this line to `docker-compose.yml`:

```yaml
volumes:
  - ./docker-data/dms/config/postfix-policyd-spf.conf:/etc/postfix-policyd-spf-python/policyd-spf.conf
```
