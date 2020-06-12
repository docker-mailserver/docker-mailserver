What is a mail server and how does it perform its duty?  
Here's an introduction to the field that covers everything you need to know to get started with docker-mailserver.

## Anatomy of a mail server

A mail server is only a part of a [client-server relationship](https://en.wikipedia.org/wiki/Client%E2%80%93server_model) aimed at exchanging information in the form of [emails](https://en.wikipedia.org/wiki/Email). Exchanging emails requires using specific means (programs and protocols).

docker-mailserver provides you with the server portion, whereas "the" client can be anything from a console, text-only software (eg. [Mutt](https://en.wikipedia.org/wiki/Mutt_(email_client))) to a fully-fledged desktop application (eg. [Mozilla Thunderbird](https://en.wikipedia.org/wiki/Mozilla_Thunderbird), [Microsoft Outlook](https://en.wikipedia.org/wiki/Microsoft_Outlook)…), to a webmail, etc.

Unlike the client side where usually a single program is used to perform retrieval and reading of emails, the server side is composed of many specialized components. "The" mail server is capable of accepting, forwarding, delivering, storing and overall exchanging messages, but each one of those tasks is actually handled by a specific piece of software. All those "agents" must be integrated with one another for the exchange to take place.

docker-mailserver has made some informed choices about those components and their (default) configuration. It offers a comprehensive platform to run a feature-full mail server in no time!

## Components

The following components are required to create a [complete delivery chain](https://en.wikipedia.org/wiki/Email_agent_(infrastructure)):

- MUA: a [Mail User Agent](https://en.wikipedia.org/wiki/Email_client) is basically any client/program capable of sending emails to arbitrary mail servers; and most of the times, capable of fetching emails from such mail servers and presenting them to the end users.
- MTA: a [Mail Transfer Agent](https://en.wikipedia.org/wiki/Message_transfer_agent) is the so-called "mail server" as seen from the MUA's perspective. More specifically, it's a piece of software dedicated to accepting, and in some cases, transfering/relaying emails. A MTA may accept incoming emails either from MUAs or from other MTAs. It may then relay emails to either other MTAs or, eventually, an MDA.
- MDA: a [Mail Delivery Agent](https://en.wikipedia.org/wiki/Mail_delivery_agent) is responsible for accepting emails from a MTA, but instead of forwarding it to another MTA, it is responsible for dropping emails into their recipients' mailboxes, whichever the form.

Here's a schematic view of mail delivery:

```txt
Sending an email:    MUA ---> MTA ---> MTA ---> ... ---> MTA ---> MDA
Fetching an email:   MUA <--------------------------------------- MDA
```

There may be other moving parts or sub-divisions (for instance, at several point along the chain, specialized programs may be analyzing, filtering, bouncing, editing… the exchanged emails).

In a nutshell, docker-mailserver provides you with the following components:

- MTA: [Postfix](http://www.postfix.org/)
- MDA: [Dovecot](https://dovecot.org/)
- a bunch of additional programs to improve security and emails processing

Here's where docker-mailserver's toochain fits within the delivery chain:

```txt
                                    docker-mailserver is here:
                                                         ┏━━━━━━━┓
Sending an email:    MUA ---> MTA ---> MTA ---> ... ---> ┫ MTA ╮ ┃
Fetching an email:   MUA <------------------------------ ┫ MDA ╯ ┃
                                                         ┗━━━━━━━┛
```

By default, docker-mailserver does not act as a relay nor does it accept emails from relays. It only handles direct email trafic, bound to a specific hostname. Thus our schema can be further simplified to look like this:

```txt
         docker-mailserver is here:
                              ┏━━━━━━━┓
Sending an email:    MUA ---> ┫ MTA ╮ ┃
Fetching an email:   MUA <--- ┫ MDA ╯ ┃
                              ┗━━━━━━━┛
```

> Of course the MUA and docker-mailserver's MTA may be located in distant (network-wise) places, so don't expect a _direct_ connection between MUAs and your mail server. It is very likely email trafic will hop through several relaying HTTP(S) server-but those will not be MTA servers, so are irrelevant here.

One important thing to note is that MTA and MDA programs may actually handle _multiple_ tasks (which is the case with docker-mailserver's Postfix and Dovecot).

For instance, Postfix is both a SMTP server (accepting emails) and a relaying MTA (transfering ie. sending emails to other MTA/MDA); Dovecot is both a MDA (delivering emails in mailboxes) and an IMAP server (allowing MUAs to fetch emails from the so-called "mail server"). On top of that, Postfix may rely on Dovecot's authentication capabilities!

The exact relationship between all the components and their respective (and sometimes, shared) responsibilities is beyond the scope of this document. Please explore this wiki & the web to get more insights about docker-mailserver's toolchain.

## About security & ports

In the previous section, different components were outlined. Each one of those is responsible for a specific task, it has a specific purpose.

Three main purposes exist when it comes to exchanging emails:

- _Submission_: for a MUA (client), the act of sending actual email data over the network, toward a MTA (server).
- _Transfer_ (aka. _Relay_): for a MTA, the act of sending actual email data over the network, toward another MTA (server) closer to the final destination (where a MTA will forward data to a MDA).
- _Retrieval_: for a MUA (client), the act of fetching actual email data over the network, from a MDA.

Postfix handles Submission (and might handle Relay), whereas Dovecot handles Retrieval. They both need to be accessible by MUAs in order to act as servers, therefore they expose public endpoints on specific TCP ports. Those endpoints _may_ be secured, using an encryption scheme.

When it comes to the specifics of email exchange, we have to look at protocols and ports enabled to support all the identified purposes. There are several valid options and they've been evolving overtime.

**Here's docker-mailserver's _default_ configuration:**

| Purpose        | Protocol | TCP port / encryption          |
|----------------|----------|--------------------------------|
| Transfer/Relay | SMTP     | 25 (unencrypted)               |
| Submission     | ESMTP    | 587 (encrypted using STARTTLS) |
| Retrieval      | IMAP4    | 143 (encrypted using STARTTLS) + 993 (TLS) |
| Retrieval      | POP3     | _Not activated_                |

```txt
 ┏━━━━━━━━━━ Submission ━━━━━━━━━┓┏━━━━━━━━━━━━━ Transfer/Relay ━━━━━━━━━━━┓
                        ┌─────────────────────┐                    ┌┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┐
MUA ----- STARTTLS ---> ┤(587)   MTA ╮    (25)├ <-- plain text --> ┊ Third-party MTA ┊
    ---- plain text --> ┤(25)        │        |                    └┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┘
                        |┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄|
MUA <---- STARTTLS ---- ┤(143)   MDA ╯        |
    <-- enforced TLS -- ┤(993)                |
                        └─────────────────────┘
 ┗━━━━━━━━━━ Retrieval ━━━━━━━━━━┛
```

If you're new to the field, both that table and schema may be confusing.  
Read on to gain insights about all those concepts, docker-mailserver's configuration and how you could customize it.

### Submission - SMTP

A MUA willing to send an email to a MTA needs to establish a connection with that server, then push data packets over a network that both the MUA (client) and the MTA (server) are connected to. The server implements the [SMTP](https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol) protocol, which makes it capable of handling _Submission_.

In the case of docker-mailserver, the MTA (SMTP server) is Postfix. The MUA (client) may vary, yet its Submission request is performed as [TCP](https://en.wikipedia.org/wiki/Transmission_Control_Protocol) packets sent over the _public_ internet. This exchange of information may be secured in order to counter eavesdropping.

The best practice as of 2020 would be to handle emails Submission using an _Implicit TLS connection with an ESMTP server on port 465_ (see [RFC 8314](https://tools.ietf.org/html/rfc8314)). Let's break it down.

- Implicit TLS means the server _enforces_ the client into using an encrypted TCP connection, using [TLS](https://en.wikipedia.org/wiki/Transport_Layer_Security). With this kind of connection, the MUA _has_ to establish a TLS-encrypted connection from the get go. The mail server would deny any client attempting at submitting emails in plain text (== not secure) or requesting a plain text connection to be upgraded to a TLS-encrypted one (== eventually secure). It is also known as Enforced TLS.
- [ESMTP](https://en.wikipedia.org/wiki/ESMTP) is [SMTP](https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol) + extensions. It's the version of the SMTP protocol that most mail servers speak nowadays. For the purpose of this documentation, ESMTP and SMTP are synonymous.
- Port 465 is (starting 2018) the reserved TCP port for Implicit TLS Submission. There is acually a boisterous history to that port's usage, but let's keep it simple.

> Note: this Submission setup is sometimes refered to as [SMTPS](https://en.wikipedia.org/wiki/SMTPS). Long story short: this is incorrect and should be avoided.

Although a very satisfactory setup, Implicit TLS on port 465 is somewhat "cutting edge". There exists another well established mail Submission setup that must be supported as well, SMTP+STARTTLS on port 587. It uses Explicit TLS: the client starts with a plain text connection, then the server informs a TLS-encrypted "upgraded" connection may be established, and the client _may_ eventually decide to establish it prior to the Submission. Basically it's an opportunistic, opt-in TLS upgrade of the connection between the client and the server, at the client's discretion, using a mechanism known as [STARTTLS](https://en.wikipedia.org/wiki/Opportunistic_TLS) that both ends need to implement.

In many implementations, the mail server doesn't enforce TLS encryption, for backwards compatibility. Clients are thus free to deny the TLS-upgrade proposal, and the server eventually accepts unencrypted (plain text) mail exchange, which poses a confidentiality threat and, to some extent, spam issues. [RFC 8314 (section 3.3)](https://tools.ietf.org/html/rfc8314) recommends for mail servers to support both Implicit and Explicit TLS for Submission, _and_ to enforce TLS-encryption on ports 587 (Explicit TLS) and 465 (Implicit TLS). That's exactly docker-mailserver's default configuration: abiding by RFC 8314, it [enforces a strict (`encrypt`) STARTTLS policy](http://www.postfix.org/postconf.5.html#smtpd_tls_security_level), where a denied TLS upgrade terminates the connection thus preventing unencrypted (plain text) Submission by the client.

- **docker-mailserver's default configuration enables and _requires_ Explicit TLS (STARTTLS) for Submission on port 587.**
- It does not enable Implicit TLS Submission on port 465 by default. One may enable it through simple custom configuration, either as a replacement or (better!) supplementary mean of secure Submission.
- It does not support old MUAs (clients) not supporting TLS encryption. One may relax that constraint through advanced custom configuration, for backwards compatibility.

A final Submission setup exists and is akin SMTP+STARTTLS on port 587, but on port 25. That port has historically been reserved specifically for unencrypted (plain text) mail exchange though, making STARTTLS a bit of a misusage. As is expected by [RFC 5321](https://tools.ietf.org/html/rfc5321), docker-mailserver uses port 25 for unencrypted Submission in order to support older clients (Submission), but most importantly for unencrypted Transfer/Relay between MTAs.

- **docker-mailserver's default configuration enables unencrypted (plain text) for Transfer/Relay on port 25.**
- It does not enable Explicit TLS (STARTTLS) Transfer/Relay on port 25 by default. One may enable it through advanced custom configuration, either as a replacement (bad!) or as a supplementary mean of secure Transfer/Relay.
- One may also secure Transfer/Relay on port 25 using advanced encryption scheme, such as DANE and/or MTA-STS.

### Retrieval - IMAP

A MUA willing to fetch an email from a mail server will most likely communicate with its [IMAP](https://en.wikipedia.org/wiki/IMAP) server. As with SMTP described earlier, communication will take place in the form of data packets exchanged over a network that both the client and the server are connected to. The IMAP protocol makes the server capable of handling _Retrieval_.

In the case of docker-mailserver, the IMAP server is Dovecot. The MUA (client) may vary, yet its Retrieval request is performed as [TCP](https://en.wikipedia.org/wiki/Transmission_Control_Protocol) packets sent over the _public_ internet. This exchange of information may be secured in order to counter eavesdropping.

Again, as with SMTP described earlier, the IMAP protocol may be secured with either Implicit TLS (aka. [IMAPS](https://en.wikipedia.org/wiki/IMAPS)/IMAP4S) or Explicit TLS (using STARTTLS).

The best practice as of 2020 is to enforce IMAPS on port 993, rather than IMAP+STARTTLS on port 143 (see [RFC 8314](https://tools.ietf.org/html/rfc8314)); yet the latter is usually provided for backwards compatibility.

**docker-mailserver's default configuration enables both Implicit and Explicit TLS for Retrievial, on ports 993 and 143 respectively.**

### Retrieval - POP3

Similarly to IMAP, the older POP3 protocol may be secured with either Implicit or Explicit TLS.

The best practice as of 2020 would be [POP3S](https://en.wikipedia.org/wiki/POP3S) on port 995, rather than [POP3](https://en.wikipedia.org/wiki/POP3)+STARTTLS on port 110 (see [RFC 8314](https://tools.ietf.org/html/rfc8314)).

**docker-mailserver's default configuration disables POP3 altogether.** One should expect MUAs to use TLS-encrypted IMAP for Retrieval.

## How does docker-mailserver help with setting everything up?

As a _batteries included_ Docker image, docker-mailserver provides you with all the required components and a default configuration, to run a decent and secure mail server.

One may customize all aspects of internal components.
- Simple customization is supported through [docker-compose configuration](https://github.com/tomav/docker-mailserver/blob/master/docker-compose.yml.dist) and the [env-mailserver](https://github.com/tomav/docker-mailserver/blob/master/env-mailserver.dist) configuration file.
- Advanced customization is supported through providing "monkey-patching" configuration files and/or [deriving your own image](https://github.com/tomav/docker-mailserver/blob/master/Dockerfile) from docker-mailserver's upstream, for a complete control over how things run!

On the subject of security, one might consider docker-mailserver's **default** configuration to _not_ be 100% secure:

- it enables unencrypted trafic on port 25 for Transfer/Relay (between MTAs for MX service)
- it enables Explicit TLS (STARTTLS) on port 587 for SMTP, instead of Implicit TLS on port 465

We believe docker-mailserver's default configuration to be a good middle ground: it goes slightly beyond "old" (1999) [RFC 2487](https://tools.ietf.org/html/rfc2487); and with developper-friendly configuration settings, it makes it pretty easy to abide by the "newest" (2018) [RFC 8314](https://tools.ietf.org/html/rfc8314).

Eventually, it is up to _you_ deciding exactly what kind of transportation/encryption to use and/or enforce, and to customize your instance accordingly (with looser or stricter security).

The [README](https://github.com/tomav/docker-mailserver) is the best starting point in configuring and running your mail server. You may then explore this wiki to cover additional topics, including but not limited to, security.