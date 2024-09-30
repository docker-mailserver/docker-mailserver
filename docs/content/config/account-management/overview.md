# Account Management - Overview

This page provides a technical reference for account management in DMS.

!!! note "Account provisioners and alternative authentication support"

    Each [`ACCOUNT_PROVISIONER`][docs::env::account-provisioner] has a separate page for configuration guidance and caveats:

    - [`FILE` provisioner docs][docs::account-provisioner::file]
    - [`LDAP` provisioner docs][docs::account-provisioner::ldap]

    Authentication from the provisioner can be supplemented with additional methods:

    - [OAuth2 / OIDC][docs::account-auth::oauth2] (_allow login from an external authentication service_)
    - [Master Accounts][docs::account-auth::master-accounts] (_access the mailbox of any DMS account_)

    ---

    For custom authentication requirements, you could [implement this with Lua][docs::examples::auth-lua].

## Accounts

!!! info

    To receive or send mail, you'll need to provision user accounts into DMS (_as each provisioner page documents_).

    ---

    A DMS account represents a user with their _login username_ + password, and optional config like aliases and quota.

    - Sending mail from different addresses **does not require** aliases or separate accounts.
    - Each account is configured with a _primary email address_ that a mailbox is associated to.

??? info "Primary email address"

    The email address associated to an account creates a mailbox. This address is relevant:

    - When DMS **receives mail** for that address as the recipient (_or an alias that resolves to it_), to identify which mailbox to deliver into.
    - With **mail submission**:
        - `SPOOF_PROTECTION=1` **restricts the sender address** to the DMS account email address (_unless additional sender addresses have been permitted via supported config_).
        - `SPOOF_PROTECTION=0` allows DMS accounts to **use any sender address** (_only a single DMS account is necessary to send mail with different sender addresses_).

    ---

    For more details, see the [Technical Overview](#technical-overview) section.

??? note "Support for multiple mail domains"

    No extra configuration in DMS is required after provisioning an account with an email address.

    - The DNS records for a domain should direct mail to DMS and allow DMS to send mail on behalf of that domain.
    - DMS does not need TLS certificates for your mail domains, only for the DMS FQDN (_the `hostname` setting_).

??? warning "Choosing a compatible email address"

    An email address should conform to the standard [permitted charset and format][email-syntax::valid-charset-format] (`local-part@domain-part`).

    ---

    DMS has features that need to reserve special characters to work correctly. Ensure those characters are not present in email addresses you configure for DMS, otherwise disable / opt-out of the feature.

    - [Sub-addressing](#sub-addressing) is enabled by default with `+` as the _tag delimiter_. The tag can be changed, feature opt-out when the tag is explicitly unset.

### Aliases

!!! info

    Aliases allow receiving mail:

    - As an alternative delivery address for a DMS account mailbox.
    - To redirect / forward to an external address outside of DMS like `@gmail.com`.

??? abstract "Technical Details (_Local vs Virtual aliases_)"

    Aliases are managed through Postfix which supports _local_ and _virtual_ aliases:

    - **Local aliases** are for mail routed to the [`local` delivery agent][postfix::delivery-agent::local] (see [associated alias config format][postfix::config-table::local-alias])
        - You rarely need to configure this. It is used internally for system unix accounts belonging to the services running in DMS (_including `root`_).
        - `postmaster` may be a local alias to `root`, and `root` to a virtual alias or real email address.
        - Any mail sent through the `local` delivery agent will not be delivered to an inbox managed by Dovecot (_unless you have configured a local alias to redirect mail to a valid address or alias_).
        - The domain-part of an these aliases belongs to your DMS FQDN (_`hostname: mail.example.com`, thus `user@mail.example.com`_). Technically there is no domain-part at this point, that context is used when routing delivery, the local delivery agent only knows of the local-part (_an alias or unix account_).
    - [**Virtual aliases**][postfix-docs::virtual-alias] are for mail routed to the [`virtual` delivery agent][postfix::delivery-agent::virtual] (see [associated alias config format][postfix::config-table::virtual-alias])
        - When alias support in DMS is discussed without the context of being a local or virtual alias, it's likely the virtual kind (_but could also be agnostic_).
        - The domain-part of an these aliases belongs to a mail domain managed by DMS (_like `user@example.com`_).

    !!! tip "Verify alias resolves correctly"

        You can run `postmap -q <alias> <table>` in the container to verify an alias resolves to the expected target. If the target is also an alias, the command will not expand that alias to resolve the actual recipient(s).

        For the `FILE` provisioner, an example would be: `postmap -q alias1@example.com /etc/postfix/virtual`. For the `LDAP` provisioner you'd need to adjust the table path.

    !!! info "Side effect - Dovecot Quotas (`ENABLE_QUOTAS=1`)"

        As a side effect of the alias workaround for the `FILE` provisioner with this feature, aliases can be used for account login. This is not intentional.

### Quotas

!!! info

    Enables mail clients with the capability to query a mailbox for disk-space used and capacity limit.

    - This feature is enabled by default, opt-out via [`ENABLE_QUOTAS=0`][docs::env::enable-quotas]
    - **Not implemented** for the LDAP provisioner (_PR welcome! View the [feature request for implementation advice][gh-issue::dms-feature-request::dovecot-quotas-ldap]_)

??? tip "How are quotas useful?"

    Without quota limits for disk storage, a mailbox could fill up the available storage which would cause delivery failures to all mailboxes.

    Quotas help by preventing that abuse, so that only a mailbox exceeding the assigned quota experiences a delivery failure instead of negatively impacting others (_provided disk space is available_).

??? abstract "Technical Details"

    The [Dovecot Quotas feature][gh-pr::dms-feature::dovecot-quotas] is configured by enabling the [Dovecot `imap-quota` plugin][dovecot-docs::plugin::imap-quota] and using the [`count` quota backend][dovecot-docs::config::quota-backend-count].

    ---

    **Dovecot workaround for Postfix aliases**

    When mail is delivered to DMS, Postfix will query Dovecot with the recipient(s) to verify quota has not been exceeded.

    This allows early rejection of mail arriving to DMS, preventing a spammer from taking advantage of a [backscatter][wikipedia::backscatter] source if the mail was accepted by Postfix, only to later be rejected by Dovecot for storage when the quota limit was already reached.

    However, Postfix does not resolve aliases until after the incoming mail is accepted.

    1. Postfix queries Dovecot (_a [`check_policy_service` restriction tied to the Dovecot `quota-status` service][dms::workaround::dovecot-quotas::notes-1]_) with the recipient (_the alias_).
    2. `dovecot: auth: passwd-file(alias@example.com): unknown user` is logged, Postfix is then informed that the recipient mailbox is not full even if it actually was (_since no such user exists in the Dovecot UserDB_).
    3. However, when the real mailbox address that the alias would later resolve into does have a quota that exceeded the configured limit, Dovecot will refuse the mail delivery from Postfix which introduces a backscatter source for spammers.

    As a [workaround to this problem with the `ENABLE_QUOTAS=1` feature][dms::workaround::dovecot-quotas::summary], DMS will add aliases as fake users into Dovecot UserDB (_that are configured with the same data as the real address the alias would resolve to, thus sharing the same mailbox location and quota limit_). This allows Postfix to properly be aware of an aliased mailbox having exceeded the allowed quota.

    **NOTE:** This workaround **only supports** aliases to a single target recipient of a real account address / mailbox.

    - Additionally, aliases that resolve to another alias or to an external address would both fail the UserDB lookup, unable to determine if enough storage is available.
    - A proper fix would [implement a Postfix policy service][dms::workaround::dovecot-quotas::notes-2] that could correctly resolve aliases to valid entries in the Dovecot UserDB, querying the `quota-status` service and returning that response to Postfix.

## Sub-addressing

!!! info

    [Subaddressing][wikipedia::subaddressing] (_aka **Plus Addressing** or **Address Tags**_) is a feature that allows you to receive mail to an address which includes a tag appended to the `local-part` of a valid account address.

    - A subaddress has a tag delimiter (_default: `+`_), followed by the tag: `<local-part>+<tag>@<domain-part>`
    - The subaddress `user+github@example.com` would deliver mail to the same mailbox as `user@example.com`.
    - Tags are dynamic. Anything between the `+` and `@` is understood as the tag, no additional configuration required.
    - Only the first occurence of the tag delimiter is recognized. Any additional occurences become part of the tag value itself.

??? tip "When is subaddressing useful?"

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

## Technical Overview

!!! info

    This section provides insight for understanding how Postfix and Dovecot services are involved. It is intended as a reference for maintainers and contributors.

    - **Postfix** - Handles when mail is delivered (inbound) to DMS, or sent (outbound) from DMS.
    - **Dovecot** - Manages access and storage for mail delivered to the DMS account mailboxes of your users.

??? abstract "Technical Details - Postfix (Inbound vs Outbound)"

    Postfix needs to know how to handle inbound and outbound mail by asking these queries:

    === "Inbound"

        - What mail domains is DMS responsible for handling? (_for accepting mail delivered_)
        - What are valid mail addresses for those mail domains? (_reject delivery for users that don't exist_)
        - Are there any aliases to redirect mail to 1 or more users, or forward to externally?

    === "Outbound"

        - When `SPOOF_PROTECTION=1`, how should DMS restrict the sender address? (_eg: Users may only send mail from their associated mailbox address_)

??? abstract "Technical Details - Dovecot (Authentication)"

    Dovecot additionally handles authenticating user accounts for sending and retrieving mail:

    - Over the ports for IMAP and POP3 connections (_110, 143, 993, 995_).
    - As the default configured SASL provider, which Postfix delegates user authentication through (_for the submission(s) ports 465 & 587_). Saslauthd can be configured as an alternative SASL provider.

    Dovecot splits all authentication lookups into two categories:

    - A [PassDB][dovecot::docs::passdb] lookup most importantly authenticates the user. It may also provide any other necessary pre-login information.
    - A [UserDB][dovecot::docs::userdb] lookup retrieves post-login information specific to a user.

[docs::env::account-provisioner]: ../environment.md#account_provisioner
[docs::account-provisioner::file]: ./provisioner/file.md
[docs::account-provisioner::ldap]: ./provisioner/ldap.md
[docs::account-auth::oauth2]: ./supplementary/oauth2.md
[docs::account-auth::master-accounts]: ./supplementary/master-accounts.md
[docs::examples::auth-lua]: ../../examples/use-cases/auth-lua.md
[email-syntax::valid-charset-format]: https://stackoverflow.com/questions/2049502/what-characters-are-allowed-in-an-email-address/2049510#2049510

[postfix-docs::virtual-alias]: http://www.postfix.org/VIRTUAL_README.html#virtual_alias
[postfix-docs::recipient-delimiter]: http://www.postfix.org/postconf.5.html#recipient_delimiter
[dovecot-docs::config::recipient-delimiter]: https://doc.dovecot.org/settings/core/#core_setting-recipient_delimiter
[postfix::delivery-agent::local]: https://www.postfix.org/local.8.html
[postfix::delivery-agent::virtual]: https://www.postfix.org/virtual.8.html
[postfix::config-table::local-alias]: https://www.postfix.org/aliases.5.html
[postfix::config-table::virtual-alias]: https://www.postfix.org/virtual.5.html

[docs::env::enable-quotas]: ../environment.md#enable_quotas
[gh-issue::dms-feature-request::dovecot-quotas-ldap]: https://github.com/docker-mailserver/docker-mailserver/issues/2957
[dovecot-docs::config::quota-backend-count]: https://doc.dovecot.org/configuration_manual/quota/quota_count/#quota-backend-count
[dovecot-docs::plugin::imap-quota]: https://doc.dovecot.org/settings/plugin/imap-quota-plugin/
[gh-pr::dms-feature::dovecot-quotas]: https://github.com/docker-mailserver/docker-mailserver/pull/1469
[wikipedia::backscatter]: https://en.wikipedia.org/wiki/Backscatter_%28email%29
[dms::workaround::dovecot-quotas::notes-1]: https://github.com/docker-mailserver/docker-mailserver/issues/2091#issuecomment-954298788
[dms::workaround::dovecot-quotas::notes-2]: https://github.com/docker-mailserver/docker-mailserver/pull/2248#issuecomment-953754532
[dms::workaround::dovecot-quotas::summary]: https://github.com/docker-mailserver/docker-mailserver/pull/2248#issuecomment-955088677

[docs::sieve::subaddressing]: ../advanced/mail-sieve.md#subaddress-mailbox-routing
[web::subaddress-use-cases]: https://www.codetwo.com/admins-blog/plus-addressing
[wikipedia::subaddressing]: https://en.wikipedia.org/wiki/Email_address#Sub-addressing
[ms-exchange-docs::limitations]: https://learn.microsoft.com/en-us/exchange/recipients-in-exchange-online/plus-addressing-in-exchange-online#using-plus-addresses

[dovecot::docs::passdb]: https://doc.dovecot.org/configuration_manual/authentication/password_databases_passdb
[dovecot::docs::userdb]: https://doc.dovecot.org/configuration_manual/authentication/user_databases_userdb
