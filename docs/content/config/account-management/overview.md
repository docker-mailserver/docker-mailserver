# Account Management - Overview

## Mail Accounts - Domains, Addresses, Aliases

**TODO:** `ACCOUNT_PROVISIONER` and supplementary pages referenced here.

!!! info

    In the DMS docs, there may be references to the sub-components of an address (`local-part@domain-part`).

### Accounts

To receive or send mail, you'll need to provision users into DMS with accounts. A DMS account will provide information such as their email address, login username, and any aliases.

The email address assigned to an account is relevant for:

- Receiving delivery to an inbox, when DMS receives mail for that address as the recipient (_or an alias that resolves to it_).
- Mail submission with:
    - `SPOOF_PROTECTION=1` restricts the sender address to the DMS account email address, unless additional sender addresses have been permitted via supported config.
    - `SPOOF_PROTECTION=0` allows DMS accounts to use any sender address, only a single DMS account is necessary to send mail with different sender addresses.

??? warning "Email address considerations"

    An email address should conform to the standard [permitted charset and format](https://stackoverflow.com/questions/2049502/what-characters-are-allowed-in-an-email-address/2049510#2049510).

    DMS has features that need to reserve special characters to work correctly. Ensure those characters are not present in email addresses you configure for DMS, or disable / opt-out of the feature.

    - [Sub-addressing](#sub-addressing) is enabled by default with the _tag delimiter_ `+`. This can be configured, or be unset to opt-out.

### Aliases

You may read [Postfix's documentation on virtual aliases][postfix-docs::virtual-alias] first.

An alias is a full email address that will either be:

- Delivered to an existing account
- Redirected to one or more other email addresses

Known issues
Alias and Account names cannot overlap
Wildcard and need to alias each real account.. (no longer supported?)

### Sub-addressing

!!! info

    [Subaddressing][wikipedia::subaddressing] (_aka **Plus Addressing** or **Address Tags**_) is a feature that allows you to receive mail to an address which includes a tag appended to the `local-part` of a valid account address.

    - A subaddress has a tag delimiter (_default: `+`_), followed by the tag: `<local-part>+<tag>@<domain-part>`
    - The subaddress `user+github@example.com` would deliver mail to the same mailbox as `user@example.com`.
    - Tags are dynamic. Anything between the `+` and `@` is understood as the tag, no additional configuration required.
    - Only the first occurence of the tag delimiter is recognized. Any additional occurences become part of the tag value itself.

!!! tip "When is subaddressing useful?"

    A common use-case is to use a unique tag for each service you register your email address with.

    - Routing delivery to different folders in your mailbox based on the tag (_via a [Sieve filter][docs::sieve::subaddressing]_).
    - Data leaks or bulk sales of email addresses.
        - If spam / phishing mail you receive has not removed the tag, you will have better insight into where your address was compromised from.
        - When the expected tag is missing, this additionally helps identify bad actors. Especially when mail delivery is routed to subfolders by tag.
    - For more use-cases, view the end of [this article][web::subaddress-use-cases].

??? tip "Changing the tag delimiter"

    Add `recipient_delimiter = +` to these config override files (_replacing `+` with your preferred delimiter_):

    - Postfix: `docker-data/dms/config/postfix-main.cf`
    - Dovecot: `docker-data/dms/config/dovecot.cf`

??? tip "Opt-out of subaddressing"

    Follow the advice to change the tag delimiter, but instead set an empty value (`recipient_delimiter =`).

??? warning "Only for receiving, not sending"

    Do not attempt to send mail from these tagged addresses, they are not equivalent to aliases.

    This feature is only intended to be used when a mail client sends to a DMS managed recipient address. While DMS does not restrict the sender address you choose to send mail from (_provided `SPOOF_PROTECTION` has not been enabled_), it is often [forbidden by mail services][ms-exchange-docs::limitations].

??? abstract "Technical Details"

    The configured tag delimiter (`+`) allows both Postfix and Dovecot to recognize subaddresses. Without this feature configured, the subaddresses would be considered as separate mail accounts rather than routed to a common account address.

    ---

    Internally DMS has the tag delimiter configured by:

    - Applying the Postfix `main.cf` setting: [`recipient_delimiter = +`][postfix-docs::recipient-delimiter]
    - Dovecot has the equivalent setting set as `+` by default: [`recipient_delimiter = +`][dovecot-docs::config::recipient-delimiter]

### Quotas

- `imap-quota` is enabled and allow clients to query their mailbox usage.
- Dovecot quotas are compatible with LDAP, **but it's not implemented** (_PRs are welcome!_).

Known issues
default feature enabled, dovecot creates dummy accounts to workaround alias limitation.

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

[docs::sieve::subaddressing]: ../advanced/mail-sieve.md#subaddress-mailbox-routing
[web::subaddress-use-cases]: https://www.codetwo.com/admins-blog/plus-addressing/
[wikipedia::subaddressing]: https://en.wikipedia.org/wiki/Email_address#Sub-addressing
[ms-exchange-docs::limitations]: https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/plus-addressing-in-exchange-online#using-plus-addresses

[postfix-docs::virtual-alias]: http://www.postfix.org/VIRTUAL_README.html#virtual_alias
[postfix-docs::recipient-delimiter]: http://www.postfix.org/postconf.5.html#recipient_delimiter
[dovecot-docs::config::recipient-delimiter]: https://doc.dovecot.org/settings/core/#core_setting-recipient_delimiter
