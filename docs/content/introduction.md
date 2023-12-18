---
title: Introduction
---

# An Overview of Mail Server Infrastructure

This article answers the question "What is a mail server, and how does it perform its duty?" and it gives the reader an introduction to the field that covers everything you need to know to get started with DMS.

## The Anatomy of a Mail Server

A mail server is only a part of a [client-server relationship][wikipedia-clientserver] aimed at exchanging information in the form of [emails][wikipedia-email]. Exchanging emails requires using specific means (programs and protocols).

DMS provides you with the server portion, whereas the client can be anything from a terminal via text-based software (eg. [Mutt][software-mutt]) to a fully-fledged desktop application (eg. [Mozilla Thunderbird][software-thunderbird], [Microsoft Outlook][software-outlook]…), to a web interface, etc.

Unlike the client-side where usually a single program is used to perform retrieval and viewing of emails, the server-side is composed of many specialized components. The mail server is capable of accepting, forwarding, delivering, storing and overall exchanging messages, but each one of those tasks is actually handled by a specific piece of software. All of these "agents" must be integrated with one another for the exchange to take place.

DMS has made informed choices about those components and their (default) configuration. It offers a comprehensive platform to run a fully featured mail server in no time!

## Components

The following components are required to create a [complete delivery chain][wikipedia-emailagent]:

- **MUA**: a [Mail User Agent][wikipedia-mua] is basically any client/program capable of sending emails to a mail server; while also capable of fetching emails from a mail server for presenting them to the end users.
- **MTA**: a [Mail Transfer Agent][wikipedia-mta] is the so-called "mail server" as seen from the MUA's perspective. It's a piece of software dedicated to accepting submitted emails, then forwarding them-where exactly will depend on an email's final destination. If the receiving MTA is responsible for the FQDN the email is sent to, then an MTA is to forward that email to an MDA (see below). Otherwise, it is to transfer (ie. forward, relay) to another MTA, "closer" to the email's final destination.
- **MDA**: a [Mail Delivery Agent][wikipedia-mda] is responsible for accepting emails from an MTA and dropping them into their recipients' mailboxes, whichever the form.

Here's a schematic view of mail delivery:

```txt
Sending an email:    MUA ----> MTA ----> (MTA relays) ----> MDA
Fetching an email:   MUA <--------------------------------- MDA
```

There may be other moving parts or sub-divisions (for instance, at several points along the chain, specialized programs may be analyzing, filtering, bouncing, editing… the exchanged emails).

In a nutshell, DMS provides you with the following components:

- A MTA: [Postfix](http://www.postfix.org/)
- A MDA: [Dovecot](https://dovecot.org/)
- A bunch of additional programs to improve security and emails processing

Here's where DMS's toolchain fits within the delivery chain:

```txt
                                    docker-mailserver is here:
                                                        ┏━━━━━━━┓
Sending an email:   MUA ---> MTA ---> (MTA relays) ---> ┫ MTA ╮ ┃
Fetching an email:  MUA <------------------------------ ┫ MDA ╯ ┃
                                                        ┗━━━━━━━┛
```

??? example "An Example"

    Let's say Alice owns a Gmail account, `alice@gmail.com`; and Bob owns an account on a DMS instance, `bob@dms.io`.

    Make sure not to conflate these two very different scenarios:
    A) Alice sends an email to `bob@dms.io` => the email is first submitted to MTA `smtp.gmail.com`, then relayed to MTA `smtp.dms.io` where it is then delivered into Bob's mailbox.
    B) Bob sends an email to `alice@gmail.com` => the email is first submitted to MTA `smtp.dms.io`, then relayed to MTA `smtp.gmail.com` and eventually delivered into Alice's mailbox.

    In scenario *A* the email leaves Gmail's premises, that email's *initial* submission is _not_ handled by your DMS instance(MTA); it merely receives the email after it has been relayed by Gmail's MTA. In scenario *B*, the DMS instance(MTA) handles the submission, prior to relaying.

    The main takeaway is that when a third-party sends an email to a DMS instance(MTA) (or any MTA for that matter), it does _not_ establish a direct connection with that MTA. Email submission first goes through the sender's MTA, then some relaying between at least two MTAs is required to deliver the email. That will prove very important when it comes to security management.

One important thing to note is that MTA and MDA programs may actually handle _multiple_ tasks (which is the case with DMS's Postfix and Dovecot).

For instance, Postfix is both an SMTP server (accepting emails) and a relaying MTA (transferring, ie. sending emails to other MTA/MDA); Dovecot is both an MDA (delivering emails in mailboxes) and an IMAP server (allowing MUAs to fetch emails from the _mail server_). On top of that, Postfix may rely on Dovecot's authentication capabilities.

The exact relationship between all the components and their respective (sometimes shared) responsibilities is beyond the scope of this document. Please explore this wiki & the web to get more insights about DMS's toolchain.

## About Security & Ports

### Introduction

In the previous section, three components were outlined. Each one of those is responsible for a specific task when it comes to exchanging emails:

- **Submission**: for a MUA (client), the act of sending actual email data over the network, toward an MTA (server).
- **Transfer** (aka. **Relay**): for an MTA, the act of sending actual email data over the network, toward another MTA (server) closer to the final destination (where an MTA will forward data to an MDA).
- **Retrieval**: for a MUA (client), the act of fetching actual email data over the network, from an MDA.

Postfix handles **Submission** (_and may handle **Relay**_), whereas Dovecot handles **Retrieval**. They both need to be accessible by MUAs in order to act as servers, therefore they expose public [endpoints on specific TCP ports][docs-understandports]. Those endpoints _may_ be secured, using an encryption scheme and TLS certificates.

When it comes to the specifics of email exchange, we have to look at protocols and ports enabled to support all the identified purposes. There are several valid options and they've been evolving overtime.

### Overview

The following picture gives a visualization of the interplay of all components and their [respective ports][docs-understandports]:

```txt
  ┏━━━━━━━━━━ Submission ━━━━━━━━━━━━━┓┏━━━━━━━━━━━━━ Transfer/Relay ━━━━━━━━━━━┓

                            ┌─────────────────────┐                    ┌┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┐
MUA ----- STARTTLS -------> ┤(587)   MTA ╮    (25)├ <-- cleartext ---> ┊ Third-party MTA ┊
    ----- implicit TLS ---> ┤(465)       │        |                    └┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┘
    ----- cleartext ------> ┤(25)        │        |
                            |┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄|
MUA <---- STARTTLS -------- ┤(143)   MDA ╯        |
    <---- implicit TLS ---- ┤(993)                |
                            └─────────────────────┘

  ┗━━━━━━━━━━ Retrieval ━━━━━━━━━━━━━━┛
```

If you're new to email infrastructure, both that table and the schema may be confusing.
Read on to expand your understanding and learn about DMS's configuration, including how you can customize it.

### Submission - SMTP

For a MUA to send an email to an MTA, it needs to establish a connection with that server, then push data packets over a network that both the MUA (client) and the MTA (server) are connected to. The server implements the [SMTP][wikipedia-smtp] protocol, which makes it capable of handling _Submission_.

In the case of DMS, the MTA (SMTP server) is Postfix. The MUA (client) may vary, yet its Submission request is performed as [TCP][wikipedia-tcp] packets sent over the _public_ internet. This exchange of information may be secured in order to counter eavesdropping.

Now let's say I own an account on a DMS instance, `me@dms.io`. There are two very different use-cases for Submission:

1. I want to send an email to someone
2. Someone wants to send you an email

In the first scenario, I will be submitting my email directly to my DMS instance/MTA (Postfix), which will then relay the email to its recipient's MTA for final delivery. In this case, Submission is first handled by establishing a direct connection to my own MTA-so at least for this portion of the delivery chain, I'll be able to ensure security/confidentiality. Not so much for what comes next, ie. relaying between MTAs and final delivery.

In the second scenario, a third-party email account owner will be first submitting an email to some third-party MTA. I have no control over this initial portion of the delivery chain, nor do I have control over the relaying that comes next. My MTA will merely accept a relayed email coming "out of the blue".

My MTA will thus have to support two kinds of Submission:

- Outbound Submission (self-owned email is submitted directly to the MTA, then is relayed "outside")
- Inbound Submission (third-party email has been submitted & relayed, then is accepted "inside" by the MTA)

```txt
  ┏━━━ Outbound Submission ━━━┓

                    ┌────────────────────┐                    ┌┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┐
Me ---------------> ┤                    ├ -----------------> ┊                 ┊
                    │       My MTA       │                    ┊ Third-party MTA ┊
                    │                    ├ <----------------- ┊                 ┊
                    └────────────────────┘                    └┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┘

                              ┗━━━━━━━━━━ Inbound Submission ━━━━━━━━━━┛
```

#### Outbound Submission

When it comes to securing Outbound Submission you should prefer to use _Implicit TLS connection via ESMTP on port 465_ (see [RFC 8314][rfc-8314]). Please read our article about [**Understanding the Ports**][docs-understandports] for more details!

!!! warning

    This Submission setup is sometimes referred to as [SMTPS][wikipedia-smtps]. Long story short: this is incorrect and should be avoided.

Although a very satisfactory setup, Implicit TLS on port 465 is somewhat "cutting edge". There exists another well established mail Submission setup that must be supported as well, SMTP+STARTTLS on port 587. It uses Explicit TLS: the client starts with a cleartext connection, then the server informs a TLS-encrypted "upgraded" connection may be established, and the client _may_ eventually decide to establish it prior to the Submission. Basically it's an opportunistic, opt-in TLS upgrade of the connection between the client and the server, at the client's discretion, using a mechanism known as [STARTTLS][wikipedia-starttls] that both ends need to implement.

In many implementations, the mail server doesn't enforce TLS encryption, for backwards compatibility. Clients are thus free to deny the TLS-upgrade proposal (or [misled by a hacker](https://security.stackexchange.com/questions/168998/what-happens-if-starttls-dropped-in-smtp) about STARTTLS not being available), and the server accepts unencrypted (cleartext) mail exchange, which poses a confidentiality threat and, to some extent, spam issues. [RFC 8314 (section 3.3)][rfc-8314-s33] recommends for a mail server to support both Implicit and Explicit TLS for Submission, _and_ to enforce TLS-encryption on ports 587 (Explicit TLS) and 465 (Implicit TLS). That's exactly DMS's default configuration: abiding by RFC 8314, it [enforces a strict (`encrypt`) STARTTLS policy](http://www.postfix.org/postconf.5.html#smtpd_tls_security_level), where a denied TLS upgrade terminates the connection thus (hopefully but at the client's discretion) preventing unencrypted (cleartext) Submission.

- **DMS's default configuration enables and _requires_ Explicit TLS (STARTTLS) on port 587 for Outbound Submission.**
- It does not enable Implicit TLS Outbound Submission on port 465 by default. One may enable it through simple custom configuration, either as a replacement or (better!) supplementary mean of secure Submission.
- It does not support old MUAs (clients) not supporting TLS encryption on ports 587/465 (those should perform Submission on port 25, more details below). One may relax that constraint through advanced custom configuration, for backwards compatibility.

A final Outbound Submission setup exists and is akin SMTP+STARTTLS on port 587, but on port 25. That port has historically been reserved specifically for unencrypted (cleartext) mail exchange though, making STARTTLS a bit wrong to use. As is expected by [RFC 5321][rfc-5321], DMS uses port 25 for unencrypted Submission in order to support older clients, but most importantly for unencrypted Transfer/Relay between MTAs.

- **DMS's default configuration also enables unencrypted (cleartext) on port 25 for Outbound Submission.**
- It does not enable Explicit TLS (STARTTLS) on port 25 by default. One may enable it through advanced custom configuration, either as a replacement (bad!) or as a supplementary mean of secure Outbound Submission.
- One may also secure Outbound Submission using advanced encryption scheme, such as DANE/DNSSEC and/or MTA-STS.

#### Inbound Submission

Granted it's still very difficult enforcing encryption between MTAs (Transfer/Relay) without risking dropping emails (when relayed by MTAs not supporting TLS-encryption), Inbound Submission is to be handled in cleartext on port 25 by default.

- **DMS's default configuration enables unencrypted (cleartext) on port 25 for Inbound Submission.**
- It does not enable Explicit TLS (STARTTLS) on port 25 by default. One may enable it through advanced custom configuration, either as a replacement (bad!) or as a supplementary mean of secure Inbound Submission.
- One may also secure Inbound Submission using advanced encryption scheme, such as DANE/DNSSEC and/or MTA-STS.

Overall, DMS's default configuration for SMTP looks like this:

```txt
  ┏━━━ Outbound Submission ━━━┓

                    ┌────────────────────┐                    ┌┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┐
Me -- cleartext --> ┤(25)            (25)├ --- cleartext ---> ┊                 ┊
Me -- TLS      ---> ┤(465)  My MTA       │                    ┊ Third-party MTA ┊
Me -- STARTTLS ---> ┤(587)               │                    ┊                 ┊
                    │                (25)├ <---cleartext ---- ┊                 ┊
                    └────────────────────┘                    └┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┘

                              ┗━━━━━━━━━━ Inbound Submission ━━━━━━━━━━┛
```

### Retrieval - IMAP

A MUA willing to fetch an email from a mail server will most likely communicate with its [IMAP][wikipedia-imap] server. As with SMTP described earlier, communication will take place in the form of data packets exchanged over a network that both the client and the server are connected to. The IMAP protocol makes the server capable of handling _Retrieval_.

In the case of DMS, the IMAP server is Dovecot. The MUA (client) may vary, yet its Retrieval request is performed as [TCP][wikipedia-tcp] packets sent over the _public_ internet. This exchange of information may be secured in order to counter eavesdropping.

Again, as with SMTP described earlier, the IMAP protocol may be secured with either Implicit TLS (aka. [IMAPS][wikipedia-imaps] / IMAP4S) or Explicit TLS (using STARTTLS).

The best practice as of 2020 is to enforce IMAPS on port 993, rather than IMAP+STARTTLS on port 143 (see [RFC 8314][rfc-8314]); yet the latter is usually provided for backwards compatibility.

**DMS's default configuration enables both Implicit and Explicit TLS for Retrievial, on ports 993 and 143 respectively.**

### Retrieval - POP3

Similarly to IMAP, the older POP3 protocol may be secured with either Implicit or Explicit TLS.

The best practice as of 2020 would be [POP3S][wikipedia-pop3s] on port 995, rather than [POP3][wikipedia-pop3]+STARTTLS on port 110 (see [RFC 8314][rfc-8314]).

**DMS's default configuration disables POP3 altogether.** One should expect MUAs to use TLS-encrypted IMAP for Retrieval.

## How Does DMS Help With Setting Everything Up?

As a _batteries included_ container image, DMS provides you with all the required components and a default configuration to run a decent and secure mail server. One may then customize all aspects of its internal components.

- Simple customization is supported through [Docker Compose configuration][github-file-compose] and the [env-mailserver][github-file-envmailserver] configuration file.
- Advanced customization is supported through providing "monkey-patching" configuration files and/or [deriving your own image][github-file-dockerfile] from DMS's upstream, for a complete control over how things run.

Eventually, it is up to _you_ deciding exactly what kind of transportation/encryption to use and/or enforce, and to customize your instance accordingly (with looser or stricter security). Be also aware that protocols and ports on your server can only go so far with security; third-party MTAs might relay your emails on insecure connections, man-in-the-middle attacks might still prove effective, etc. Advanced counter-measure such as DANE, MTA-STS and/or full body encryption (eg. PGP) should be considered as well for increased confidentiality, but ideally without compromising backwards compatibility so as to not block emails.

[docs-understandports]: ./config/security/understanding-the-ports.md
[github-file-compose]: https://github.com/docker-mailserver/docker-mailserver/blob/master/compose.yaml
[github-file-envmailserver]: https://github.com/docker-mailserver/docker-mailserver/blob/master/mailserver.env
[github-file-dockerfile]: https://github.com/docker-mailserver/docker-mailserver/blob/master/Dockerfile
[rfc-2487]: https://tools.ietf.org/html/rfc2487
[rfc-5321]: https://tools.ietf.org/html/rfc5321
[rfc-8314]: https://tools.ietf.org/html/rfc8314
[rfc-8314-s33]: https://tools.ietf.org/html/rfc8314#section-3.3
[software-mutt]: https://en.wikipedia.org/wiki/Mutt_(email_client)
[software-outlook]: https://en.wikipedia.org/wiki/Microsoft_Outlook
[software-thunderbird]: https://en.wikipedia.org/wiki/Mozilla_Thunderbird
[wikipedia-clientserver]: https://en.wikipedia.org/wiki/Client%E2%80%93server_model
[wikipedia-email]: https://en.wikipedia.org/wiki/Email
[wikipedia-emailagent]: https://en.wikipedia.org/wiki/Email_agent_(infrastructure)
[wikipedia-imap]: https://en.wikipedia.org/wiki/IMAP
[wikipedia-imaps]: https://en.wikipedia.org/wiki/IMAPS
[wikipedia-mda]: https://en.wikipedia.org/wiki/Mail_delivery_agent
[wikipedia-mta]: https://en.wikipedia.org/wiki/Message_transfer_agent
[wikipedia-mua]: https://en.wikipedia.org/wiki/Email_client
[wikipedia-pop3]: https://en.wikipedia.org/wiki/POP3
[wikipedia-pop3s]: https://en.wikipedia.org/wiki/POP3S
[wikipedia-smtp]: https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol
[wikipedia-smtps]: https://en.wikipedia.org/wiki/SMTPS
[wikipedia-starttls]: https://en.wikipedia.org/wiki/Opportunistic_TLS
[wikipedia-tcp]: https://en.wikipedia.org/wiki/Transmission_Control_Protocol
