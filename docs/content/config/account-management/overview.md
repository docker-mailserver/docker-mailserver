# Account Management - Overview

## Mail Accounts - Domains, Addresses, Aliases

`ACCOUNT_PROVISIONER` and supplementary pages referenced here.

Anchor heading links stubbed out below.

### Accounts

### Aliases

### Quotas

## Technical Overview

- Postfix handles when mail is delivered (inbound) to DMS, or sent (outbound) from DMS.
- Dovecot manages mailbox storage for mail delivered to your DMS user accounts.

??? abstract "Technical Details - Postfix"

    Postfix needs to know how to handle inbound and outbound mail by asking these queries:

    === "Inbound"

        - What mail domains is DMS responsible for handling? (_for accepting mail delivered_)
        - What are valid mail addresses for those mail domains? (_reject delivery for users that don't exist_)
        - Are there any aliases to redirect mail to 1 or more users, or forward to externally?

    === "Outbound"

        - When `SPOOF_PROTECTION=1`, how should DMS restrict the sender address? (_eg: Users may only send mail from their associated mailbox address_)

??? abstract "Technical Details - Dovecot"

    Dovecot additionally handles authenticating user accounts for sending and retrieving mail:

    - Over the ports for IMAP and POP3 connections (_110, 143, 993, 995_).
    - As the default configured SASL provider, which Postfix delegates user authentication through (_for the submission(s) ports 465 & 587_). Saslauthd can be configured as an alternative SASL provider.

    Dovecot splits all authentication lookups into two categories:

    - A [PassDB][dovecot::docs::passdb] lookup most importantly authenticates the user. It may also provide any other necessary pre-login information.
    - A [UserDB][dovecot::docs::userdb] lookup retrieves post-login information specific to a user.