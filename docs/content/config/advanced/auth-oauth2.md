---
title: 'Advanced | Basic OAuth2 Authentication'
---

## Introduction

**Warning** - This is only a supplement to the existing account provisioners; FILE and LDAP. Accounts must still be created using the `setup` command or added to the LDAP directory respectively. Reasoning for this can be found in #3579. Future iterations on this feature may allow it to be a full account provisioner.

For now, this adds the ability for a 3rd party application such as Roundcube to authenticate with DMS (dovecot) using a token obtained from an OAuth2 provider instead of passing passwords around.

## Example (Authentik & Roundcube)

???+ example "Authentik"
    1. Create a new OAuth2 provider
    2. Note the client id and client secret
    3. Set the allowed redirect url to `https://roundcube.domain.com/index.php/login/oauth` (obviously changing your domain as needed)

???+ example "Docker Mailserver `mailserver.env`"
    ```env
    # -----------------------------------------------
    # --- OAUTH2 Section ----------------------------
    # -----------------------------------------------

    # empty => OAUTH2 authentication is disabled
    # 1 => OAUTH2 authentication is enabled
    ENABLE_OAUTH2=1

    # empty => verySecretId
    # Specify the OAuth2 client ID
    OAUTH2_CLIENT_ID=<insert client id here>

    # empty => verySecretSecret
    # Specify the OAuth2 client secret
    OAUTH2_CLIENT_SECRET=<insert client secret here>

    # empty => https://oauth2.domain.com/userinfo/
    # Specify the user info endpoint URL of the oauth2 provider
    OAUTH2_INTROSPECTION_URL=https://authentik.domain.com/application/o/userinfo/
    ```

???+ example "Roundcube `oauth2.inc.php` ([documentation](https://github.com/roundcube/roundcubemail/wiki/Configuration))"
    ```php
    $config['oauth_provider'] = 'generic';
    $config['oauth_provider_name'] = 'Authentik';
    $config['oauth_client_id'] = '<insert client id here>';
    $config['oauth_client_secret'] = '<insert client secret here>';
    $config['oauth_auth_uri'] = 'https://authentik.domain.com/application/o/authorize/';
    $config['oauth_token_uri'] = 'https://authentik.domain.com/application/o/token/';
    $config['oauth_identity_uri'] = 'https://authentik.domain.com/application/o/userinfo/';

    // Optional: disable SSL certificate check on HTTP requests to OAuth server
    // See http://docs.guzzlephp.org/en/stable/request-options.html#verify for possible values
    $config['oauth_verify_peer'] = false;

    $config['oauth_scope'] = 'email openid profile';
    $config['oauth_identity_fields'] = ['email'];

    // Boolean: automatically redirect to OAuth login when opening Roundcube without a valid session
    $config['oauth_login_redirect'] = false;
    ```
