---
title: 'Account Management | OAuth2 Support'
---

## Introduction

!!! warning "This is only a supplement to the existing account provisioners"

    Accounts must still be managed via the configured [`ACCOUNT_PROVISIONER`][docs::env::account-provisioner] (`FILE` or `LDAP`).

    Reasoning for this can be found in [#3480][gh-pr::oauth2]. Future iterations on this feature may allow it to become a full account provisioner.

[gh-pr::oauth2]: https://github.com/docker-mailserver/docker-mailserver/pull/3480
[docs::env::account-provisioner]: ../../environment.md#account_provisioner

The present OAuth2 support provides the capability for 3rd-party applications such as Roundcube to authenticate with DMS (dovecot) by using a token obtained from an OAuth2 provider, instead of passing passwords around.

## Example (Authentik with Roundcube)

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

[authentik::docs::install]: https://goauthentik.io/docs/installation/
[roundcube::dockerhub-image]: https://hub.docker.com/r/roundcube/roundcubemail
[roundcube::docs::install]: https://github.com/roundcube/roundcubemail/wiki/Installation
[roundcube::docs::config]: https://github.com/roundcube/roundcubemail/wiki/Configuration
