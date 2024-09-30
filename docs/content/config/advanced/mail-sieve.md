---
title: 'Advanced | Email Filtering with Sieve'
---

## User-Defined Sieve Filters

!!! warning "Advice may be outdated"

    This section was contributed by the community some time ago and some configuration examples may be outdated.

[Sieve][sieve-info] allows to specify filtering rules for incoming emails that allow for example sorting mails into different folders depending on the title of an email.

!!! info "Global vs User order"

    There are global and user specific filters which are filtering the incoming emails in the following order:

    Global-before -> User specific -> Global-after

Global filters are applied to EVERY incoming mail for EVERY email address.

- To specify a global Sieve filter provide a `docker-data/dms/config/before.dovecot.sieve` or a `docker-data/dms/config/after.dovecot.sieve` file with your filter rules.
- If any filter in this filtering chain discards an incoming mail, the delivery process will stop as well and the mail will not reach any following filters (e.g. global-before stops an incoming spam mail: The mail will get discarded and a user-specific filter won't get applied.)

To specify a user-defined Sieve filter place a `.dovecot.sieve` file into a virtual user's mail folder (e.g. `/var/mail/example.com/user1/home/.dovecot.sieve`). If this file exists dovecot will apply the filtering rules.

It's even possible to install a user provided Sieve filter at startup during users setup: simply include a Sieve file in the `docker-data/dms/config/` path for each user login that needs a filter. The file name provided should be in the form `<user_login>.dovecot.sieve`, so for example for `user1@example.com` you should provide a Sieve file named `docker-data/dms/config/user1@example.com.dovecot.sieve`.

An example of a sieve filter that moves mails to a folder `INBOX/spam` depending on the sender address:

!!! example

    ```sieve
    require ["fileinto", "reject"];

    if address :contains ["From"] "spam@spam.com" {
      fileinto "INBOX.spam";
    } else {
      keep;
    }
    ```

!!! warning

    That folders have to exist beforehand if sieve should move them.

Another example of a sieve filter that forward mails to a different address:

!!! example

      ```sieve
      require ["copy"];

      redirect :copy "user2@not-example.com";
      ```

Just forward all incoming emails and do not save them locally:

!!! example

    ```sieve
    redirect "user2@not-example.com";
    ```

You can also use external programs to filter or pipe (process) messages by adding executable scripts in `docker-data/dms/config/sieve-pipe` or `docker-data/dms/config/sieve-filter`.

This can be used in lieu of a local alias file, for instance to forward an email to a webservice.

- These programs can then be referenced by filename, by all users.
- Note that the process running the scripts run as a privileged user.
- For further information see [Dovecot's docs][dovecot-docs::sieve-pipe].

```sieve
require ["vnd.dovecot.pipe"];
pipe "external-program";
```

For more examples or a detailed description of the Sieve language have a look at [the official site][sieve-info::examples]. Other resources are available on the internet where you can find several [examples][third-party::sieve-examples].

[dovecot-docs::sieve-pipe]: https://doc.dovecot.org/configuration_manual/sieve/plugins/extprograms/#pigeonhole-plugin-extprograms
[sieve-info]: http://sieve.info/
[sieve-info::examples]: http://sieve.info/examplescripts
[third-party::sieve-examples]: https://support.tigertech.net/sieve#sieve-example-rules-jmp

## Automatic Sorting Based on Sub-addresses { #subaddress-mailbox-routing }

When mail is delivered to your account, it is possible to organize storing mail into folders by the [subaddress (tag)][docs::accounts-subaddressing] used.

!!! example "Example: `user+<tag>@example.com` to `INBOX/<Tag>`"

    This example sorts mail into inbox folders by their tag:

    ```sieve title="docker-data/dms/config/user@example.com.dovecot.sieve"
    require ["envelope", "fileinto", "mailbox", "subaddress", "variables"];

    # Check if the mail recipient address has a tag (:detail)
    if envelope :detail :matches "to" "*" {
      # Create a variable `tag`, with the the captured `to` value normalized (SoCIAL => Social)
      set :lower :upperfirst "tag" "${1}";

      # Store the mail into a folder with the tag name, nested under your inbox folder:
      if mailboxexists "INBOX.${tag}" {
        fileinto "INBOX.${tag}";
      } else {
        fileinto :create "INBOX.${tag}";
      }
    }
    ```

    When receiving mail for `user+social@example.com` it would be delivered into the `INBOX/Social` folder.

??? tip "Only redirect mail for specific tags"

    If you want to only handle specific tags, you could replace the envelope condition and tag assignment from the prior example with:

    ```sieve title="docker-data/dms/config/user@example.com.dovecot.sieve"
    # Instead of `:matches`, use the default comparator `:is` (exact match)
    if envelope :detail "to" "social" {
      set "tag" "Social";
    ```

    ```sieve title="docker-data/dms/config/user@example.com.dovecot.sieve"
    # Alternatively you can also provide a list of values to match:
    if envelope :detail "to" ["azure", "aws"] {
      set "tag" "Cloud";
    ```

    ```sieve title="docker-data/dms/config/user@example.com.dovecot.sieve"
    # Similar to `:matches`, except `:regex` provides enhanced pattern matching.
    # NOTE: This example needs you to `require` the "regex" extension
    if envelope :detail :regex "to" "^cloud-(azure|aws)$" {
      # Normalize the captured azure/aws tag as the resolved value is no longer fixed:
      set :lower :upperfirst "vendor" "${1}";
      # If a `.` exists in the tag, it will create nested folders:
      set "tag" "Cloud.${vendor}";
    ```

    **NOTE:** There is no need to lowercase the tag in the conditional as the [`to` value is a case-insensitive check][sieve-docs::envelope].

??? abstract "Technical Details"

    - Dovecot supports this feature via the _Sieve subaddress extension_ ([RFC 5233][rfc::5233::sieve-subaddress]).
    - Only a single tag per subaddress is supported. Any additional tag delimiters are part of the tag value itself.
    - The Dovecot setting [`recipient_delimiter`][dovecot-docs::config::recipient_delimiter] (default: `+`) configures the tag delimiter. This is where the `local-part` of the recipient address will split at, providing the `:detail` (tag) value for Sieve.

    ---

    `INBOX` is the [default namespace configured by Dovecot][dovecot-docs::namespace].

    - If you omit the `INBOX.` prefix from the sieve script above, the mailbox (folder) for that tag is created at the top-level alongside your Trash and Junk folders.
    - The `.` between `INBOX` and `${tag}` is important as a [separator to distinguish mailbox names][dovecot-docs::mailbox-names]. This can vary by mailbox format or configuration. DMS uses [`Maildir`][dovecot-docs::mailbox-formats::maildir] by default, which uses `.` as the separator.
    - [`lmtp_save_to_detail_mailbox = yes`][dovecot-docs::config::lmtp_save_to_detail_mailbox] can be set in `/etc/dovecot/conf.d/20-lmtp.conf`:
        - This implements the feature globally, except for the tag normalization and `INBOX.` prefix parts of the example script.
        - However, if the sieve script is also present, the script has precedence and will handle this task instead when the condition is successful, otherwise falling back to the global feature.

## Manage Sieve

The [Manage Sieve](https://doc.dovecot.org/admin_manual/pigeonhole_managesieve_server/) extension allows users to modify their Sieve script by themselves. The authentication mechanisms are the same as for the main dovecot service. ManageSieve runs on port `4190` and needs to be enabled using the `ENABLE_MANAGESIEVE=1` environment variable.

!!! example

    ```yaml title="compose.yaml"
    ports:
      - "4190:4190"
    environment:
      - ENABLE_MANAGESIEVE=1
    ```

All user defined sieve scripts that are managed by ManageSieve are stored in the user's home folder in `/var/mail/example.com/user1/home/sieve`. Just one Sieve script might be active for a user and is sym-linked to `/var/mail/example.com/user1/home/.dovecot.sieve` automatically.

!!! note

    ManageSieve makes sure to not overwrite an existing `.dovecot.sieve` file. If a user activates a new sieve script the old one is backed up and moved to the `sieve` folder.

The extension is known to work with the following ManageSieve clients:

- **[Sieve Editor](https://github.com/thsmi/sieve)**  a portable standalone application based on the former Thunderbird plugin.
- **[Kmail](https://kontact.kde.org/components/kmail/)**  the mail client of [KDE](https://kde.org/)'s Kontact Suite.

[docs::accounts-subaddressing]: ../account-management/overview.md#sub-addressing

[dovecot-docs::namespace]: https://doc.dovecot.org/configuration_manual/namespace/
[dovecot-docs::mailbox-names]: https://doc.dovecot.org/configuration_manual/sieve/usage/#mailbox-names
[dovecot-docs::mailbox-formats::maildir]: https://doc.dovecot.org/admin_manual/mailbox_formats/maildir/#maildir-mbox-format
[dovecot-docs::config::lmtp_save_to_detail_mailbox]: https://doc.dovecot.org/settings/core/#core_setting-lmtp_save_to_detail_mailbox
[dovecot-docs::config::recipient_delimiter]: https://doc.dovecot.org/settings/core/#core_setting-recipient_delimiter

[rfc::5233::sieve-subaddress]: https://datatracker.ietf.org/doc/html/rfc5233
[sieve-docs::envelope]: https://thsmi.github.io/sieve-reference/en/test/core/envelope.html
