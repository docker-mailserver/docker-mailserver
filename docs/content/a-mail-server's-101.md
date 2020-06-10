What is a mail server and how does it perform its duty?  
Here's an introduction to the field that covers everything you need to know to get started with docker-mailserver.

## Anatomy of a mail server

A mail server is only a part of a [client-server relationship](https://en.wikipedia.org/wiki/Client%E2%80%93server_model) aimed at exchanging information in the form of emails. Exchanging emails requires using specific means (programs and protocols).

This project provides with the server portion, whereas "the" client can be anything from a console, text-only software (eg. [Mutt](https://en.wikipedia.org/wiki/Mutt_(email_client))) to a fully-fledged desktop application (eg. [Mozilla Thunderbird](https://en.wikipedia.org/wiki/Mozilla_Thunderbird), [Microsoft Outlook](https://en.wikipedia.org/wiki/Microsoft_Outlook)…), to a webmail, etc.

Unlike the client side where usually a single program is used, there are many components making up the server. Specialized piece of software handle atomic tasks, such as receiving emails, dropping emails into mailboxes, sending emails to other mail servers, filtering emails, exposing emails to authorized clients, etc.

The docker-mailserver project has made some informed choices about those components and offers a comprehensive platform to run a feature-full mail server.

## Components

The following components are required to create a [complete delivery chain](https://en.wikipedia.org/wiki/Email_agent_(infrastructure)):

- MUA: a [Mail User Agent](https://en.wikipedia.org/wiki/Email_client) is basically any client/program capable of sending emails to arbitrary mail servers; and most of the times, capable of fetching emails from such mail servers.
- MTA: a [Mail Transfer Agent](https://en.wikipedia.org/wiki/Message_transfer_agent) is the so-called "mail server" as seen from the MUA's perspective. It's a piece of software dedicated to accepting emails: either from MUAs or from other MTA (the latter task being symmetrical, meaning a MTA is also is capable of sending/transferring emails to other MTA, hence the name).
- MDA: a [Mail Delivery Agent](https://en.wikipedia.org/wiki/Mail_delivery_agent) is responsible for accepting emails from an MTA, but instead of forwarding it, it is capable of dropping those emails into their recipients' mailboxes, whichever the form.

There may be other moving parts or sub-divisions. For instance, at several point specialized programs may be filtering, bouncing, editing… exchanged emails.

In a nutshell, docker-mailserver provides you with the following agents:

- MTA: Postfix
- MDA: Dovecot

and with some specialized, companion programs to form a complete delivery chain (minus the MUA of course).

> One important thing to know is that both the MTA and MDA programs actually handle _multiple_ tasks. For instance, Postfix is both an SMTP server (accepting email) and an MTA (transfering email); Dovecot is both an MDA (delivering emails in mailboxes) and an IMAP server (allowing MUAs to fetch emails from the so-called mail server). On top of that, Postfix may rely on Dovecot's authentication capabilities. The exact relationship between all the components and their respective or, sometimes, shared responsibilities is beyond the scope of this document. Explore the wiki to get more insights about the toolchain.

## About security, ports…

For both Postfix and Dovecot need to be accessible from the outside to act as servers, they expose themselves through TCP ports, which may be secured using different schemes.

### SMTP

A MUA sending an email to a [SMTP](https://en.wikipedia.org/wiki/SMTP) server communicates using data packets exchanged over a network that both the client and the server are part of. In the case of docker-mailserver, the server is Postfix. The MUA may be anything, and its submission/request is (most frequently!) performed as [TCP](https://en.wikipedia.org/wiki/Transmission_Control_Protocol) packets sent over the _public_ internet. This exchange of information may, or may not, be secured in order to counter eavesdropping.

**The best practice as of 2020 would be [SMTPS](https://en.wikipedia.org/wiki/SMTPS) over port 465**. It has the server _enforce_ the client into using an encrypted TCP connection, using [TLS](https://en.wikipedia.org/wiki/Transport_Layer_Security) (see [RFC 8314](https://tools.ietf.org/html/rfc8314)). With this setup, the mail server should deny any client attempting at submitting emails in plain text; it should require a TLS-encrypted exchange to exist from the get go (no connection upgrade using an opt-in STARTTLS mechanism, see next paragraph). That SMTPS setup is said to _Implicit_ (aka. enforced) TLS encryption.

Another well-documented, extensively used mail submission setup is SMTP+STARTTLS. It uses _Explicit_ (aka. opportunistic) TLS over port 587, with an opt-in TLS upgrade of the client-to-server connection using using [STARTTLS](https://en.wikipedia.org/wiki/Opportunistic_TLS). With this setup, the mail server should accept unencrypted requests but should automatically respond to the client with an "offer" to upgrade the connection to a TLS-encrypted one; but it also should allow the client to deny that proposal and eventually still accept unencrypted mail exchange (although some servers may eventually deny unencrypted trafic). Overall, this setup requires more configuration and is less secure by design (hence the name "opportunistic"). As of 2020, it is recommended by RFC 8314 for mail servers to support it, but as a to-be-deprecated protocol and to encourage clients to switch to SMTPS.

A final setup exists and is akin SMTP+STARTTLS, but over port 25. That port has historically been reserved specifically for plain text mail exchange. One may upgrade the connection on port 25 to a TLS-encrypted one, but that should be considered a non-normative usage. It's better reserving port 25 for plain text trafic in order to support older clients, and inter-MTA exchange (although obviously non-secure).

### IMAP

A MUA reading emails from an [IMAP](https://en.wikipedia.org/wiki/IMAP) server communicates using data packets exchanged over a network that both the client and the server are part of. In the case of docker-mailserver, the server is Dovecot. The MUA may be anything, and its retrieval request is (most frequently!) performed as [TCP](https://en.wikipedia.org/wiki/Transmission_Control_Protocol) packets sent over the _public_ internet. This exchange of information may, or may not, be secured in order to counter eavesdropping.

As with SMTP (described above), the IMAP protocol may be secured with either: _Implicit_ (enforced) TLS (aka. [IMAPS](https://en.wikipedia.org/wiki/IMAPS), sometimes written IMAP4S); or _Explicit_ (opportunistic) TLS using STARTTLS.

**The best practice as of 2020 would be IMAPS over port 993**, rather than IMAP+STARTTLS over port 143 (see [RFC 8314](https://tools.ietf.org/html/rfc8314)).

### POP3

Similarly to IMAP, POP3 may be secured with either: _Implicit_ (enforced) TLS (aka. POP3S); or _Explicit_ (opportunistic) TLS using STARTTLS.

**The best practice as of 2020 would be [POP3S](https://en.wikipedia.org/wiki/POP3S) over port 995**, rather than [POP3](https://en.wikipedia.org/wiki/POP3)+STARTTLS over port 110 (see [RFC 8314](https://tools.ietf.org/html/rfc8314)).

### Summary of ports/security setups

When talking about emails, the following applies:

| Protocol | Purpose              | Default port w/ opt-in Encryption<sup>1</sup> | Enforced Encryption    |
|----------|----------------------|-----------------------------------------------|------------------------|
| SMTP     | Transfer<sup>2</sup> | 25                                            | N/A                    |
| ESMTP    | Submission           | 587 _(deprecated<sup>4</sup>)_                | SMTPS 465<sup>3</sup>  |
| POP3     | Retrieval            | 110 _(deprecated<sup>4</sup>)_                | POP3S 995              |
| IMAP4    | Retrieval            | 143 _(deprecated<sup>4</sup>)_                | IMAPS 993              |

1. An insecure, unencrypted connection *may* be upgraded to a secured one (over TLS) when _both_ ends support the `STARTTLS` mechanism. On ports 110, 143 and 587, `docker-mailserver` *will* reject a connection that cannot be secured with STARTTLS (_preventing [MITM attacks](https://stackoverflow.com/questions/15796530/what-is-the-difference-between-ports-465-and-587/32460763#32460763) trough a downgrading_). Note that port 25 is [required](https://serverfault.com/questions/623692/is-it-still-wrong-to-require-starttls-on-incoming-smtp-messages) to support insecure connections; whereas other ports are not and may be limited to STARTTLS (which docker-mailserver enforces).
2. Port 25 is for _incoming_ mail transfer_, ie. it receives email and may filter for spam and viruses upon reception. For transferring _outgoing_ mail (eg. sending emails from within docker-mailserver to another mail server), you should prefer the submission ports (465, 587), which require authentication in docker-mailserver. Unless a relay host is configured, outgoing email will _leave_ the server via port 25 (thus outbound traffic must not be blocked by your provider or firewall).
3. Port 465 is a submission port again since 2018, see [RFC 8314](https://tools.ietf.org/html/rfc8314). Originally a secure variant of port 25, it is now dedicated to SMTPS.
4. [RFC 8314](https://tools.ietf.org/html/rfc8314) is recommending that clear text exchanges to be abandoned and that all three common IETF mail protocols to be used only in implicit mode (no STARTTLS).

## How does docker-mailserver help with setting everything up?

As a _batteries included_ Docker image, docker-mailserver provides you with all the required components and a default configuration to run a mail server. On top of that, the [env-mailserver](https://github.com/tomav/docker-mailserver/blob/master/env-mailserver.dist) configuration file (and some other optional, advanced files!) allow you to tweak your setup extensively. You may even derive your own image from docker-mailserver for a complete control!

When it comes to security, one may consider docker-mailserver's **default** configuration to _not_ be 100% secure:

- it supports port 25 (unencrypted trafic by design)
- it enforces [strict (`encrypt`) opportunistic](http://www.postfix.org/postconf.5.html#smtpd_tls_security_level) TLS-encrypted connections on ports 110 (POP3), 143 (IMAP) and 587 (SMTP) using STARTTLS
- it does _not_ support enforced TLS-encrypted connections (POP3S, IMAPS, SMTPS)

That default setup has been consciously chosen, for the project aims at supporting _by default and without custom configuration required_ all kinds of clients, including ones not supporting TLS, or ones not able (== not configured) to use enforced/implicit TLS-encrypted connections but still capable of handling opportunistic TLS.

We believe docker-mailserver's default configuration (enforcing TLS, either opportunistic or implicit) to be a good middle ground: it goes slightly beyond [RFC 2487](https://tools.ietf.org/html/rfc2487) "old" (1999) recommandation and, through configuration, makes it pretty easy to abide by the "newest" (2018) [RFC 8314](https://tools.ietf.org/html/rfc8314), under the assumption that most MUA (clients) nowadays support TLS. Eventually, it is up to you deciding exactly what kind of transportation encryption to use and/or enforce, and to customize your instance accordingly (looser or stricter security); with the help of the project's documentation.

The [README](https://github.com/tomav/docker-mailserver) is the best starting point in configuring and running your mail server. You may then explore this wiki to cover additional topics, including but not limited to, security.
