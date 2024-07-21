---
title: 'Account Management | Provisioner (File)'
---

# Provisioner - File

## Management via the `setup` CLI

The best way to manage DMS accounts and related config files is through our `setup` CLI provided within the container.

!!! example "Using the `setup` CLI"

    Try the following within the DMS container (`docker exec -it <CONTAINER NAME> bash`):

    - Add an account: `setup email add <EMAIL ADDRESS>`
    - Add an alias: `setup alias add <FROM ALIAS> <TO TARGET ADDRESS>`
    - Learn more about the available subcommands via: `setup help`

    ```bash
    # Starts a basic DMS instance and then shells into the container to use the `setup` CLI:
    docker run --rm -itd --name dms --hostname mail.example.com mailserver/docker-mailserver
    docker exec -it dms bash

    # Create an account:
    setup email add hello@example.com your-password-here

    # Create an alias:
    setup alias add your-alias-here@example.com hello@example.com

    # Limit the mailbox capacity to 10 MiB:
    setup quota set hello@example.com 10M
    ```

    ??? tip "Secure password input"

        When you don't provide a password to the command, you will be prompted for one. This avoids the password being captured in your shell history.

        ```bash
        # As you input your password it will not update.
        # Press the ENTER key to apply the hidden password input.
        $ setup email add hello@example.com
        Enter Password:
        Confirm Password:
        ```

!!! note "Account removal via `setup email del`"

    When you remove a DMS account with this command, it will also remove any associated aliases and quota.

    The command will also prompt for deleting the account mailbox from disk, or can be forced with the `-y` flag.

## Config Reference

These config files belong to the [Config Volume][docs::volumes::config].

### Accounts

!!! info

    **Config file:** `docker-data/dms/config/postfix-accounts.cf`

    ---

    The config format is line-based with two fields separated by the delimiter `|`:

    - **User:** The primary email address for the account mailbox to use.
    - **Password:** A SHA512-CRYPT hash of the account password (_in this example it is `secret`_).

    ??? tip "Password hash without the `setup email add` command"

        A compatible password hash can be generated with:

        ```bash
        doveadm pw -s SHA512-CRYPT -u hello@example.com -p secret
        ```

!!! example "`postfix-accounts.cf` config file"

    In this example DMS manages mail for the domain `example.com`:

    ```cf title="postfix-accounts.cf"
    hello@example.com|{SHA512-CRYPT}$6$W4rxRQwI6HNMt9n3$riCi5/OqUxnU8eZsOlZwoCnrNgu1gBGPkJc.ER.LhJCu7sOg9i1kBrRIistlBIp938GdBgMlYuoXYUU5A4Qiv0
    ```

    ---

    **Dovecot "extra fields"**

    [Appending a third column will customize "extra fields"][gh-issue::provisioner-file::accounts-extra-fields] when converting account data into a Dovecot UserDB entry.

    DMS is not aware of these customizations beyond carrying them over, expect potential for bugs when this feature breaks any assumed conventions used in the scripts (_such as changing the mailbox path or type_).

!!! note

    Account creation will normalize the provided email address to lowercase, as DMS does not support multiple case-sensitive address variants.

    The email address chosen will also represent the _login username_ credential for mail clients to authenticate with.

### Aliases

!!! info

    **Config file:** `docker-data/dms/config/postfix-virtual.cf`

    ---

    The config format is line-based with key value pairs (**alias** --> **target address**), with white-space as a delimiter.

!!! example "`postfix-virtual.cf` config file"

    In this example DMS manages mail for the domain `example.com`:

    ```cf-extra title="postfix-virtual.cf"
    # Alias delivers to an existing account:
    alias1@example.com hello@example.com

    # Alias forwards to an external email address:
    alias2@example.com external-account@gmail.com
    ```

??? warning "Known Issues"

    **`setup` CLI prevents an alias and account sharing an address:**

    You cannot presently add a new account (`setup email add`) or alias (`setup alias add`) with an address which already exists as an alias or account in DMS.

    This [restriction was enforced][gh-issue::bugs::account-alias-overlap] due to [problems it could cause][gh-issue::bugs::account-alias-overlap-problem], although there are [use-cases where you may legitimately require this functionality][gh-issue::feature-request::allow-account-alias-overlap].

    For now you must manually edit the `postfix-virtual.cf` file as a workaround. There are no run-time checks outside of the `setup` CLI related to this restriction.

    ---

    **Wildcard catch-all support (`@example.com`):**

    While this type of alias without a local-part is supported, you must keep in mind that aliases in Postfix have a higher precedence than a real address associated to a DMS account.

    As a result, the wildcard is matched first and will direct mail for that entire domain to the alias target address. To work around this, [you will need an alias for each non-alias address of that domain][gh-issue::bugs::wildcard-catchall].

    Additionally, Postfix will read the alias config and choose the alias value that matches the recipient address first. Ensure your more specific aliases for the domain are declared above the wildcard alias in the config file.

    ---

    **Aliasing to another alias or multiple recipients:**

    [While aliasing to multiple recipients is possible][gh-discussions::no-support::alias-multiple-targets], DMS does not officially support that.

    - You may experience issues when our feature integrations don't expect more than one target per alias.
    - These concerns also apply to the usage of nested aliases (_where the recipient target provided is to an alias instead of a real address_). An example is the [incompatibility with `setup alias add`][gh-issue::bugs::alias-nested].

#### Configuring RegEx aliases

!!! info

    **Config file:** `docker-data/dms/config/postfix-regexp.cf`

    ---

    This config file is similar to the above `postfix-virtual.cf`, but the alias value is instead configured with a regex pattern.

    There is **no `setup` CLI support** for this feature, it is config only.

!!! example "`postfix-regexp.cf` config file"

    Deliver all mail for `test` users to `qa@example.com` instead:

    ```cf-extra title="postfix-regexp.cf"
    # Remember to escape regex tokens like `.` => `\.`, otherwise
    # your alias pattern may be more permissive than you intended:
    /^test[0-9][0-9]*@example\.com/ qa@example.com
    ```

??? abstract "Technical Details"

    `postfix-virtual.cf` has precedence, `postfix-regexp.cf` will only be checked if no alias match was found in `postfix-virtual.cf`.

    These files are both copied internally to `/etc/postfix/` and configured in `main.cf` for the `virtual_alias_maps` setting. As `postfix-virtual.cf` is declared first for that setting, it will be processed before using `postfix-regexp.cf` as a fallback.

### Quotas

!!! info

    **Config file:** `docker-data/dms/config/dovecot-quotas.cf`

    ----

    The config format is line-based with two fields separated by the delimiter `:`:

    - **Dovecot UserDB account:** The user DMS account. It should have a matching field in `postfix-accounts.cf`.
    - **Quota limit:** Expressed in bytes (_binary unit suffix is supported: `M` => `MiB`, `G` => `GiB`_).

!!! example "`dovecot-quotas.cf` config file"

    For the account with the mailbox address of `hello@example.com`, it may not exceed 5 GiB in storage:

    ```cf-extra title="dovecot-quotas.cf"
    hello@example.com:5G
    ```

[docs::volumes::config]: ../../advanced/optional-config.md#volumes-config
[gh-issue::provisioner-file::accounts-extra-fields]: https://github.com/docker-mailserver/docker-mailserver/issues/4117
[gh-issue::feature-request::allow-account-alias-overlap]: https://github.com/docker-mailserver/docker-mailserver/issues/3528
[gh-issue::bugs::account-alias-overlap-problem]: https://github.com/docker-mailserver/docker-mailserver/issues/3350#issuecomment-1550528898
[gh-issue::bugs::account-alias-overlap]: https://github.com/docker-mailserver/docker-mailserver/issues/3022#issuecomment-1807816689
[gh-issue::bugs::wildcard-catchall]: https://github.com/docker-mailserver/docker-mailserver/issues/3022#issuecomment-1610452561
[gh-issue::bugs::alias-nested]: https://github.com/docker-mailserver/docker-mailserver/issues/3622#issuecomment-1794504849
[gh-discussions::no-support::alias-multiple-targets]: https://github.com/orgs/docker-mailserver/discussions/3805#discussioncomment-8215417
