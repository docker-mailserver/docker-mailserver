## Overview of email ports

### Explicit TLS (aka Opportunistic TLS) - Opt-in Encryption

Communication on these ports begin in [cleartext](https://www.denimgroup.com/resources/blog/2007/10/cleartext-vs-pl/), indicating support for `STARTTLS`. If both client and server support `STARTTLS` the connection will be secured over TLS, otherwise no encryption will be used.

Support for `STARTTLS` is not always implemented correctly, which can lead to leaking credentials(client sending too early) prior to a TLS connection being established. Third-parties such as some ISPs have also been known to intercept the `STARTTLS` exchange, modifying network traffic to prevent establishing a secure connection.

Due to these security concerns, [RFC 8314 (Section 4.1)](https://tools.ietf.org/html/rfc8314#section-4.1) encourages you to **prefer Implicit TLS ports where possible**. 

### Implicit TLS - Enforced Encryption

Communication is always encrypted, avoiding the above mentioned issues with Explicit TLS.

You may know of these ports as **SMTPS, POP3S, IMAPS**, which indicate the protocol in combination with a TLS connection. However, Explicit TLS ports provide the same benefit when `STARTTLS` is successfully negotiated; Implicit TLS better communicates the improved security to all three protocols (SMTP/POP3/IMAP over Implicit TLS). 

Additionally, referring to port 465 as *SMTPS* would be incorrect, as it is a submissions port requiring authentication to proceed via *ESMTP*, whereas ESMTPS has a different meaning(STARTTLS supported). Port 25 may lack Implicit TLS, but can be configured to be more secure between trusted parties via MTA-STS, STARTTLS Policy List, DNSSEC and DANE.

| Protocol | Explicit TLS<sup>1</sup> | Implicit TLS    | Purpose              |
|----------|--------------------------|-----------------|----------------------|
| SMTP     | 25                       | N/A             | Transfer<sup>2</sup> |
| ESMTP    | 587                      | 465<sup>3</sup> | Submission           |
| POP3     | 110                      | 995             | Retrieval            |
| IMAP4    | 143                      | 993             | Retrieval            |

1. A connection *may* be secured over TLS when both ends support `STARTTLS`. On ports 110, 143 and 587, `docker-mailserver` will reject a connection that cannot be secured. Port 25 is [required](https://serverfault.com/questions/623692/is-it-still-wrong-to-require-starttls-on-incoming-smtp-messages) to support insecure connections.
2. Receives email, `docker-mailserver` additionally filters for spam and viruses. For submitting email to the server to be sent to third-parties, you should prefer the *submission* ports(465, 587) - which require authentication. Unless a relay host is configured(eg SendGrid), outgoing email will leave the server via port 25(thus outbound traffic must not be blocked by your provider or firewall).
3. A *submission* port since 2018 ([RFC 8314](https://tools.ietf.org/html/rfc8314)). Previously a secure variant of port 25.

## Security

**TODO:** *This section should provide any related configuration advice, and probably expand on and link to resources about DANE, DNSSEC, MTA-STS and STARTTLS Policy list, with advice on how to configure/setup these added security layers.*

**TODO:** *A related section or page on ciphers used may be useful, although less important for users to be concerned about.*

### TLS connections on mail servers, compared to web browsers

Unlike with HTTP where a web browser client communicates directly with the server providing a website, a secure TLS connection as discussed below is not the equivalent safety that HTTPS provides when the transit of email (receiving or sending) is sent through third-parties, as the secure connection is only between two machines, any additional machines (MTAs) between the MUA and the MDA depends on them establishing secure connections between one another successfully. 

Other machines that facilitate a connection that generally aren't taken into account can exist between a client and server, such as those where your connection passes through your ISP provider are capable of compromising a cleartext connection through interception.