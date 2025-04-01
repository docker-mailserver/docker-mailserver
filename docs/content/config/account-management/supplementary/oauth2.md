---
title: 'Account Management | OAuth2 Support'
hide:
  - toc # Hide Table of Contents for this page
---

# Authentication - OAuth2 / OIDC

This feature enables support for delegating DMS account authentication through to an external _Identity Provider_ (IdP).

!!! warning "Receiving mail requires a DMS account to exist"

    If you expect DMS to receive mail, you must provision an account into DMS in advance. Otherwise DMS has no awareness of your externally manmaged users and will reject delivery.

    There are [plans to implement support to provision users through a SCIM 2.0 API][dms-feature-request::scim-api]. An IdP that can operate as a SCIM Client (eg: Authentik) would then integrate with DMS for user provisioning. Until then you must keep your user accounts in sync manually via your configured [`ACCOUNT_PROVISIONER`][docs::env::account-provisioner].

??? info "How the feature works"

    1. A **mail client must have support** to acquire an OAuth2 token from your IdP (_however many clients lack generic OAuth2 / OIDC provider support_).
    2. The mail client then provides that token as the user password via the login mechanism `XOAUTH2` or `OAUTHBEARER`.
    3. DMS (Dovecot) will then check the validity of that token against the Authentication Service it was configured with.
    4. If the response returned is valid for the user account, authentication is successful.

    [**XOAUTH2**][google::xoauth2-docs] (_Googles widely adopted implementation_) and **OAUTHBEARER** (_the newer variant standardized by [RFC 7628][rfc::7628] in 2015_) are supported as standards for verifying that a OAuth Bearer Token (_[RFC 6750][rfc::6750] from 2012_) is valid at the identity provider that created the token. The token itself in both cases is expected to be can an opaque _Access Token_, but it is possible to use a JWT _ID Token_ (_which encodes additional information into the token itself_).

    A mail client like Thunderbird has limited OAuth2 / OIDC support. The software maintains a hard-coded list of providers supported. Roundcube is a webmail client that does have support for generic providers, allowing you to integrate with a broader range of IdP services.

    ---

    **Documentation for this feature is WIP**

    See the [initial feature support][dms-feature::oauth2-pr] and [existing issues][dms-feature::oidc-issues] for guidance that has not yet been documented officially.

??? tip "Verify authentication works"

    If you have a compatible mail client you can verify login through that.

    ---

    ??? example "CLI - Verify with `curl`"

        ```bash
        # Shell into your DMS container:
        docker exec -it dms bash

        # Adjust these variables for the methods below to use:
        export AUTH_METHOD='OAUTHBEARER' USER_ACCOUNT='hello@example.com' ACCESS_TOKEN='DMS_YWNjZXNzX3Rva2Vu'

        # Authenticate via IMAP (Dovecot):
        curl --silent --url 'imap://localhost:143' \
            --login-options "AUTH=${AUTH_METHOD}" --user "${USER_ACCOUNT}" --oauth2-bearer "${ACCESS_TOKEN}" \
            --request 'LOGOUT' \
            && grep "dovecot: imap-login: Login: user=<${USER_ACCOUNT}>, method=${AUTH_METHOD}" /var/log/mail/mail.log

        # Authenticate via SMTP (Postfix), sending a mail with the same sender(from) and recipient(to) address:
        # NOTE: `curl` seems to require `--upload-file` with some mail content provided to test SMTP auth.
        curl --silent --url 'smtp://localhost:587' \
            --login-options "AUTH=${AUTH_METHOD}" --user "${USER_ACCOUNT}" --oauth2-bearer "${ACCESS_TOKEN}" \
            --mail-from "${USER_ACCOUNT}" --mail-rcpt "${USER_ACCOUNT}" --upload-file - <<< 'RFC 5322 content - not important' \
            && grep "postfix/submission/smtpd.*, sasl_method=${AUTH_METHOD}, sasl_username=${USER_ACCOUNT}" /var/log/mail/mail.log
        ```

        ---

        **Troubleshooting:**

        - Add `--verbose` to the curl options. This will output the protocol exchange which includes if authentication was successful or failed.
        - The above example chains the `curl` commands with `grep` on DMS logs (_for Dovecot and Postfix services_). When not running `curl` from the DMS container, ensure you check the logs correctly, or inspect the `--verbose` output instead.

    !!! warning "`curl` bug with `XOAUTH2`"

        [Older releases of `curl` have a bug with `XOAUTH2` support][gh-issue::curl::xoauth2-bug] since `7.80.0` (Nov 2021) but fixed from `8.6.0` (Jan 2024). It treats `XOAUTH2` as `OAUTHBEARER`.

        If you use `docker exec` to run `curl` from within DMS, the current DMS v14 release (_Debian 12 with curl `7.88.1`_) is affected by this bug.

## Config Examples

### Authentik with Roundcube

This example assumes you have already set up:

- A working DMS server
- An Authentik server ([documentation][authentik::docs::install])
- A Roundcube server ([docker image][roundcube::dockerhub-image] or [bare metal install][roundcube::docs::install])

!!! example "Setup Instructions"

    === "1. Docker Mailserver"

        Update your Docker Compose ENV config to include:

        ```env title="compose.yaml"
        services:
          mailserver:
            env:
              # Enable the feature:
              - ENABLE_OAUTH2=1
              # Specify the user info endpoint URL of the oauth2 server for token inspection:
              - OAUTH2_INTROSPECTION_URL=https://authentik.example.com/application/o/userinfo/
        ```

    === "2. Authentik"

        1. Create a new OAuth2 provider.
        2. Note the client id and client secret. Roundcube will need this.
        3. Set the allowed redirect url to the equivalent of `https://roundcube.example.com/index.php/login/oauth` for your RoundCube instance.

    === "3. Roundcube"

        Add the following to `oauth2.inc.php` ([documentation][roundcube::docs::config]):

        ```php
        $config['oauth_provider'] = 'generic';
        $config['oauth_provider_name'] = 'Authentik';
        $config['oauth_client_id'] = '<insert client id here>';
        $config['oauth_client_secret'] = '<insert client secret here>';
        $config['oauth_auth_uri'] = 'https://authentik.example.com/application/o/authorize/';
        $config['oauth_token_uri'] = 'https://authentik.example.com/application/o/token/';
        $config['oauth_identity_uri'] = 'https://authentik.example.com/application/o/userinfo/';

        // Optional: disable SSL certificate check on HTTP requests to OAuth server. For possible values, see:
        // http://docs.guzzlephp.org/en/stable/request-options.html#verify
        $config['oauth_verify_peer'] = false;

        $config['oauth_scope'] = 'email openid profile';
        $config['oauth_identity_fields'] = ['email'];

        // Boolean: automatically redirect to OAuth login when opening Roundcube without a valid session
        $config['oauth_login_redirect'] = false;
        ```

[dms-feature::oauth2-pr]: https://github.com/docker-mailserver/docker-mailserver/pull/3480
[dms-feature::oidc-issues]: https://github.com/docker-mailserver/docker-mailserver/issues?q=label%3Afeature%2Fauth-oidc
[docs::env::account-provisioner]: ../../environment.md#account_provisioner
[dms-feature-request::scim-api]: https://github.com/docker-mailserver/docker-mailserver/issues/4090

[google::xoauth2-docs]: https://developers.google.com/gmail/imap/xoauth2-protocol#the_sasl_xoauth2_mechanism
[rfc::6750]: https://datatracker.ietf.org/doc/html/rfc6750
[rfc::7628]: https://datatracker.ietf.org/doc/html/rfc7628
[gh-issue::curl::xoauth2-bug]: https://github.com/curl/curl/issues/10259#issuecomment-1907192556

[authentik::docs::install]: https://goauthentik.io/docs/installation/
[roundcube::dockerhub-image]: https://hub.docker.com/r/roundcube/roundcubemail
[roundcube::docs::install]: https://github.com/roundcube/roundcubemail/wiki/Installation
[roundcube::docs::config]: https://github.com/roundcube/roundcubemail/wiki/Configuration
