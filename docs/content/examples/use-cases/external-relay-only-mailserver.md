---
title: 'Use Cases | Use an external mailserver as inbound and outbound relay'
hide:
  - toc
---
## Introduction

Sometimes it's useful to have a public "relay-only" mailserver, that forwards all inbound mail to a private DMS instance and forwards all outbound mail to a receiving mailserver. There are a few reasons for this setup:
  
* I don't want to have my private mail lying around on a VPS.
* I want to be able to quickly move from one VPS to another without having to carry all my mail around.
* etc.

The following guide assumes you have a public server with a static IP on a hosting provider of your choice. This server will not have any local mailboxes. And that you have a private server eg at home, or somewhere else. This server will host DMS. Furthermore this example assumes a VPN connection between both servers to make things easier. How to set that up is out of scope, there are a lot of guides online.

## DNS setup

We will briefly go through the DNS part of the setup. It's similar to the general recommended setup for all mailservers. Let's assume our public server has a public reachable IP address of `123.123.123.123` and the hostname `mail.example.com`. Set your A, MX and PTR records like you would for DMS.

```txt
$ORIGIN example.com
@     IN  A      123.123.123.123
mail  IN  A      123.123.123.123

; mail server for example.com
@     IN  MX  10 mail.example.com.
```

And the associated PTR record. SPF records should also be setup as you normally would for `mail.example.com`.

## Public host postfix setup

Now we need to install postfix on your public host. The functionality that is needed for this setup is not yet implemented in DMS, so a vanilla postfix will probably be easier to work with, especially since we only use this server as inbound and outbound relay. It's necessary to adjust some settings. We will assume that the VPN is setup on `192.168.2.0/24`, with the public instance using `192.168.2.2` and the private instance using `192.168.2.3`. Let's start with the `main.cf`:

```txt
# See /usr/share/postfix/main.cf.dist for a commented, more complete version


# Debian specific:  Specifying a file name will cause the first
# line of that file to be used as the name.  The Debian default
# is /etc/mailname.
#myorigin = /etc/mailname

myorigin = example.com
mydestination = localhost
local_recipient_maps =
local_transport = error:local mail delivery is disabled

smtpd_banner = $myhostname ESMTP $mail_name (Debian/GNU)
biff = no

# appending .domain is the MUA's job.
append_dot_mydomain = no

# Uncomment the next line to generate "delayed mail" warnings
#delay_warning_time = 4h

readme_directory = no

# See http://www.postfix.org/COMPATIBILITY_README.html -- default to 3.6 on
# fresh installs.
compatibility_level = 3.6



# TLS parameters
smtpd_tls_cert_file=/etc/postfix/certificates/mail.example.com.crt
smtpd_tls_key_file=/etc/postfix/certificates/mail.example.com.key
smtpd_tls_security_level=may

smtp_tls_CApath=/etc/ssl/certs
smtp_tls_security_level=may
smtp_tls_session_cache_database = btree:${data_directory}/smtp_scache


smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
myhostname = mail.example.com
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
transport_maps = hash:/etc/postfix/transport
relay_domains = $mydestination, hash:/etc/postfix/relay
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128 192.168.2.0/24
mailbox_size_limit = 0
recipient_delimiter = +
inet_interfaces = all
inet_protocols = ipv4
maillog_file = /var/log/postfix.log
```

Let's highlight some of the important parts. Remove any mentions of `mail.example.com` from `mydestination`, in fact you can just set localhost or nothing at all here. We want all the mail to be relayed. For good measure also disable `local_recipient_maps`. I'll skip over the TLS parts. You should use a proper certificate for `mail.example.com`. You can also harden your host as you want. Important are `transport_maps = hash:/etc/postfix/transport` and `relay_domains = $mydestination, hash:/etc/postfix/relay` which I will show in a second. Furthermore `mynetworks` should contain your VPN network.

!!! warning "Open relay"

    Please be aware that setting `mynetworks` to a public CIDR will leave you with an open relay. **Only** set it to the CIDR of your VPN beyond the localhost ranges.

Let's look at `/etc/postfix/transport`:
```txt
example.com relay:[192.168.2.3]:25
```
the transport file specifies which relay each domain is using. If you have multiple domains, you can add them there, too. If you use a smarthost add `* relay:[X.X.X.X]:port` to the bottom, eg `* relay:[relay1.org]:587`, which will relay everything outbound via this relay host. `/etc/postfix/relay` looks like this:
```txt
example.com   OK
*             OK
```
This file specifies which domains should be relayed. We want `example.com` to be relayed inbound and everything else relayed outbound. Run `postmap /etc/postfix/transport` and `postmap /etc/postfix/relay` to have the files be useable by postfix. With that the public server is done.

## private DMS instance

You can setup your DMS instance as you normally would. Just be careful to not give it a hostname of `mail.example.com`. Instead use `internal-mail.example.com` or something similar. DKIM can be setup as usual since it considers checks whether the message body has been tampered with, which our public relay doesn't do. Set DKIM up for `mail.example.com`. Next we need to configure our outbound relay from our private instance, so that all mail gets send out via our public instance (or from there towards a smarthost). The setup is similar to the default relay setup. `postfix-relaymap.cf` looks like:

```txt
@example.com  [192.168.2.2]:25
```
meaning all mail example.com gets relayed via the public instance through our VPN. You can also set `postfix-sasl-password.cf` like

```txt
@example.com user:secret
```
the username and password don't matter, since we use `mynetworks`. But you can configure a proper SASL account with credentials for added protection or instead of a VPN. Furthermore we need to create `postfix-main.cf` with

```txt
mynetworks = 192.168.2.0/24
```
so that the relay _towards_ our private instance from the public instance via the VPN works. You can also use SASL of course. And with that everything is done.

## IMAP/POP3

IMAP and POP3 need to point towards your private instance, since that is where the mailboxes live, which means you need to have a way for your MUA to connect to it.
