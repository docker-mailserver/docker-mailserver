What is a mail server and how does it perform its duty?  
Here's an introduction to the field that covers everything you need to know to get started with docker-mailserver.

## Anatomy of a mail server

A mail server is only a part of a [client-server relationship](https://en.wikipedia.org/wiki/Client%E2%80%93server_model) aimed at exchanging information in the form of emails.

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

| Protocol | Opt-in Encryption<sup>1</sup>   | Enforced Encryption | Purpose              |
|----------|---------------------------------|---------------------|----------------------|
| SMTP     | 25                              | N/A                 | Transfer<sup>2</sup> |
| ESMTP    | 587 _(deprecated<sup>4</sup>)_  | 465<sup>3</sup>     | Submission           |
| POP3     | 110 _(deprecated<sup>4</sup>)_  | 995                 | Retrieval            |
| IMAP4    | 143 _(deprecated<sup>4</sup>)_  | 993                 | Retrieval            |

1. A connection *may* be secured over TLS when _both_ ends support `STARTTLS`. On ports 110, 143 and 587, `docker-mailserver` will reject a connection that cannot be secured _(preventing [MITM attacks](https://stackoverflow.com/questions/15796530/what-is-the-difference-between-ports-465-and-587/32460763#32460763) trough a downgrading)_. Port 25 is [required](https://serverfault.com/questions/623692/is-it-still-wrong-to-require-starttls-on-incoming-smtp-messages) to support insecure connections.
2. Port 25 receives email and filters for spam and viruses. For submitting outgoing mail you should prefer the submission ports (465, 587), which require authentication in docker-mailserver. Unless a relay host is configured, outgoing email will _leave_ the server via port 25 (thus outbound traffic must not be blocked by your provider or firewall).
3. Port 465 is a submission port since 2018, see [RFC 8314](https://tools.ietf.org/html/rfc8314). Originally a secure variant of port 25, it is now dedicated to SMTPS.
4. [RFC 8314](https://tools.ietf.org/html/rfc8314) is recommending that clear text exchanges to be abandoned and that all three common IETF mail protocols to be used only in implicit mode (no STARTTLS).

## How does docker-mailserver help with setting everything up?

As a _batteries included_ Docker image, docker-mailserver provides you with all the required components and a default configuration to run a mail server. On top of that, the [env-mailserver](https://github.com/tomav/docker-mailserver/blob/master/env-mailserver.dist) configuration file (and some other optional, advanced files!) allow you to tweak your setup extensively. You may even derive your own image from docker-mailserver for a complete control.

The default configuration may _not_ be considered 100% secure, because it aims at supporting all kinds of clients, including older ones not able to use TLS-encrypted connections. It is up to you deciding which kind of transportation encryption to use / enforce.

The [README](https://github.com/tomav/docker-mailserver) is the best starting point in configuring and running your mail server. You may the explore this wiki to cover additional topics, including but not limited to, security.
