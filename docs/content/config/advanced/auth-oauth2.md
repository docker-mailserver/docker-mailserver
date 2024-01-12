---
title: 'Advanced | Basic OAuth2 Authentication'
---

## Introduction

!!! warning "This is only a supplement to the existing account provisioners"

    Accounts must still be managed via the configured [`ACCOUNT_PROVISIONER`][env::account-provisioner] (FILE or LDAP).

    Reasoning for this can be found in [#3480][gh-pr::oauth2]. Future iterations on this feature may allow it to become a full account provisioner.

[gh-pr::oauth2]: https://github.com/docker-mailserver/docker-mailserver/pull/3480
[env::account-provisioner]: ../environment.md#account_provisioner

The present OAuth2 support provides the capability for 3rd-party applications such as Roundcube to authenticate with DMS (dovecot) by using a token obtained from an OAuth2 provider, instead of passing passwords around.

## Example (Authentik & Roundcube)

This example assumes you have:

- A working DMS server set up
- An Authentik server set up ([documentation](https://goauthentik.io/docs/installation/))
- A Roundcube server set up (either [docker](https://hub.docker.com/r/roundcube/roundcubemail/) or [bare metal](https://github.com/roundcube/roundcubemail/wiki/Installation))

!!! example "Setup Instructions"

    === "1. Docker Mailserver"
        Edit the following values in `mailserver.env`:
        ```env
        # -----------------------------------------------
        # --- OAUTH2 Section ----------------------------
        # -----------------------------------------------

        # empty => OAUTH2 authentication is disabled
        # 1 => OAUTH2 authentication is enabled
        ENABLE_OAUTH2=1

        # Specify the user info endpoint URL of the oauth2 provider
        OAUTH2_INTROSPECTION_URL=https://authentik.example.com/application/o/userinfo/
        ```

    === "2. Authentik"
        1. Create a new OAuth2 provider
        2. Note the client id and client secret
        3. Set the allowed redirect url to the equivalent of `https://roundcube.example.com/index.php/login/oauth` for your RoundCube instance.

    === "3. Roundcube"
        Add the following to `oauth2.inc.php` ([documentation](https://github.com/roundcube/roundcubemail/wiki/Configuration)):

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
