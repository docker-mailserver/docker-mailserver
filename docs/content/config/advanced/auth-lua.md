---
title: 'Advanced | Lua Authentication'
---

## Introduction

Dovecot has the ability to let users create their own custom user provisioning and authentication providers in [Lua](https://en.wikipedia.org/wiki/Lua_(programming_language)#Syntax). This allows any data source that can be approached from Lua to be used for authentication, including web servers. It is possible to do more with Dovecot and Lua, but other use cases fall outside of the scope of this documentation page.

!!! warning

    DMS offers minimal support for Lua-based authentication due to it being an advanced method that can be used in many different ways. Do not open issues on GitHub or request support from DMS contributors for Lua scripts. The documentation on this page is all that is needed to get your own development started. Look elsewhere for Lua support.

!!! warning

    Lua-based authentication relies on a Dovecot plugin. Dovecot is known to sometimes deprecate and remove support for their plugins (such as [CheckPassword](https://doc.dovecot.org/configuration_manual/authentication/checkpassword/)). DMS will drop support immediately if at some moment continued inclusion of the Lua plugin would not align with the DMS development process anymore.

There are several questions you should ask yourself before you start:

1. Do I want to use Lua to identify mailboxes and verify that users are are authorized to use mail services? This refers in the world of Dovecot to Lua providing 'userdb' functionality, as in a data source for user provisioning.
1. Do I want to use Lua to verify passwords that users authenticate with for IMAP/POP3/SMTP in their (web) mail clients? This refers in the world of Dovecot to Lua providing 'passdb' functionality, as in a data source for user password verification.
1. If the answer is 'yes' to question 1 or 2: are there other methods that better facilitate my use case aside of custom scripts which rely on me being a developer and not just a user?

If the answer is 'no' to question 3, Lua-based authentication might just be the thing for you.

Each implementation of Lua-based authentication is fully custom. Therefore it is impossible to write documentation that covers every scenario. Instead, this page describes a single scenario. If that scenario is followed, you will learn vital aspects that are necessary to kickstart your own Lua development:

- How to override Dovecot's default configuration to disable parts that conflict with your scenario.
- How to make Dovecot use your Lua script.
- How to add your own Lua script and any libraries it uses.
- How to debug your Lua script.

## The example scenario

This scenario starts with [DMS being configured to use LDAP][docs-authldap] for mailbox identification, user authorization and user authentication. In this scenario, [Nextcloud](https://nextcloud.com/) is also a service that uses the same LDAP server for user identification, authorization and authentication.

The goal of this scenario is to have Dovecot not authenticate the user against LDAP, but against Nextcloud. Furthermore, the user should should only be able to authenticate using a randomly generated [Nextcloud application password](https://docs.nextcloud.com/server/latest/user_manual/en/session_management.html#managing-devices) and not the main password of the user account (stored in LDAP). The idea behind this is that a compromised mailbox password does not compromise the user's account entirely. To make this work, password reset through mail is disabled in Nextcloud.

If the application password is configured correctly, an adversary can only use it to access the user's mailbox (since it uses an application password that is compromised) and the user's CalDAV and CardDAV data on Nextcloud. File access through WebDAV can be disabled for the application password used to access mail. Having CalDAV and CardDAV compromised by the same password is a minor setback. If an adversary gets access to a Nextcloud application password through a device of the user, it is likely that the adversary also gets access to the user's calendars and contact lists anyway (locally or through the same account settings used by mail and Cal-/CardDAV synchronization). The user's stored files in Nextcloud, the LDAP account and any other services that rely on it would still be protected. A bonus is that a user is able to revoke and renew the mailbox password in Nextcloud for whatever reason, through a friendly user interface with all the security measures applies by the Nextcloud instance.

There is also a risk that a Nextcloud application password used for something else is compromised and is used to access the user's mailbox before it is revoked. Discussion of that risk falls outside of the scope of this scenario.

To answer the questions asked earlier for this specific scenario:

1. Do I want to use Lua to identify mailboxes and verify that users are are authorized to use mail services? **No. Provisioning is done through LDAP.**
1. Do I want to use Lua to verify passwords that users authenticate with for IMAP/POP3/SMTP in their mail clients? **Yes. Password authentication is done through Lua.**
1. If the answer is 'yes' to question 1 or 2: are there other methods that better facilitate my use case instead of custom scripts which rely on me being a developer and not just a user? **No. Only HTTP can be used to authenticate against Nextcloud, which is not supported by Dovecot or DMS.**

While it is possible to extend what Nextcloud supports with [Nextcloud apps](https://apps.nextcloud.com/), there is currently a mismatch between what DMS supports and what Nextcloud applications support. This might change in the future. For now, Lua will be used to bridge the gap between DMS and Nextcloud for authentication only (Dovecot passdb), while LDAP will still be used to identify mailboxes and verify authorization (Dovecot userdb).

## Container variables to adjust

Since Docker Mailserver provides minimal support for Lua with Dovecot, there are no environment variables to configure specifically for Lua. Some environment variables that do exist for other aspects of DMS might need to be configured based on the scenario you want to follow.

In the case of the example scenario, the environment variables must be configured as if users will be authenticated against LDAP (to support identification of mailboxes and verifying authorizations through LDAP). See [LDAP Authentication][docs-authldap] for more information. In addition, the following variables are required:

???+ example

    DMS configuration environment variables to let Postfix apply Lua authentication by proxy through Dovecot for authenticated SMTP.

    ```yaml
    - ENABLE_SASLAUTHD=1
    - SASLAUTHD_MECHANISMS=rimap
    - SASLAUTHD_MECH_OPTIONS=127.0.0.1
    ```

## Modifying Dovecot's configuration

Add the following volume values to the relevant part of `compose.yaml`:

???+ example

    Override and add Dovecot configuration files and lua scripts.

    ```yaml
        volumes:
          - ./docker-data/dms/config/dovecot/auth-ldap.conf.ext:/etc/dovecot/conf.d/auth-ldap.conf.ext:ro
          - ./docker-data/dms/config/dovecot/auth-lua-httpbasic.conf:/etc/dovecot/conf.d/auth-lua-httpbasic.conf:ro
          - ./docker-data/dms/config/dovecot/lua/:/etc/dovecot/lua/:ro
    ```

The first volume line [overrides][docs-dovecotoverrideconfiguration] Dovecot's standard LDAP authentication configuration file. The second line [adds][docs-dovecotaddconfiguration] a new configuration file for Lua authentication. The third line adds a directory which will contain Lua scripts. The files and directory will not be changed from inside the container, which is why they are configured as read-only.

Make the necessary changes on the filesystem (*where `mailserver` is the container name*):
```bash
mkdir -p ./docker-data/dms/config/dovecot/lua
docker cp mailserver:/etc/dovecot/conf.d/auth-ldap.conf.ext ./docker-data/dms/config/dovecot/auth-ldap.conf.ext
```

Edit configuration file `./docker-data/dms/config/dovecot/auth-ldap.conf.ext`. Comment out the passdb section. An excerpt of what that part would look like after you are done:
```
#passdb {
#  driver = ldap
#
#  # Path for LDAP configuration file, see example-config/dovecot-ldap.conf.ext
#  args = /etc/dovecot/dovecot-ldap.conf.ext
#}
```

Don't touch anything else in the file.

Create configuration file `./docker-data/dms/config/dovecot/auth-lua-httpbasic.conf` with contents:
```
passdb {
  driver = lua
  args = file=/etc/dovecot/lua/auth-httpbasic.lua blocking=yes
}
```

That is all for configuring Dovecot.

## Create the Lua script

Create Lua file `./docker-data/dms/config/dovecot/lua/auth-httpbasic.lua` with contents:

```lua
local http_url = "https://nextcloud.example.com/remote.php/dav/"
local http_method = "PROPFIND"
local http_status_ok = 207
local http_status_failure = 401
local http_header_forwarded_for = "X-Forwarded-For"

package.path = package.path .. ";/etc/dovecot/lua/?.lua"
local base64 = require("base64")

local http_client = dovecot.http.client {
    timeout = 1000;
    max_attempts = 1;
    debug = false;
}

function script_init()
  return 0
end

function script_deinit()
end

function is_nextcloud_apppassword(password)
  return string.find(password, "%w%w%w%w%w%-%w%w%w%w%w%-%w%w%w%w%w%-%w%w%w%w%w%-%w%w%w%w%w") ~= nil
end

function auth_passdb_lookup(req)
  if not is_nextcloud_apppassword(req.password)
  then
    return dovecot.auth.PASSDB_RESULT_PASSWORD_MISMATCH, ""
  end

  local auth_request = http_client:request {
    url = http_url;
    method = http_method;
  }
  auth_request:add_header("Authorization", "Basic " .. base64.encode(req.user .. ":" .. req.password))
  auth_request:add_header(http_header_forwarded_for, req.remote_ip)
  local auth_response = auth_request:submit()

  local returnStatus = dovecot.auth.PASSDB_RESULT_INTERNAL_FAILURE
  local returnDesc = http_method .. " - " .. http_url .. " - " .. auth_response:status() .. " " .. auth_response:reason()
  if auth_response:status() == http_status_ok
  then
    returnStatus = dovecot.auth.PASSDB_RESULT_OK
    returnDesc = "nopassword=y"
  elseif auth_response:status() == http_status_failure
  then
    returnStatus = dovecot.auth.PASSDB_RESULT_PASSWORD_MISMATCH
    returnDesc = ""
  end
  return returnStatus, returnDesc
```

Replace the hostname in the URL to the actual hostname of Nextcloud.

Dovecot [provides an HTTP client for use in Lua](https://doc.dovecot.org/admin_manual/lua/#dovecot.http.client). Aside of that, Lua by itself is pretty barebones. It chooses library compactness over included functionality. You can see that in the inefficiently typed regular expression in `is_nextcloud_apppassword()`, which is used because [Lua does not offer full support for regular expressions](https://www.lua.org/pil/20.2.html). You can also see Lua's limited functionality in that a separate library is referenced to add support for Base64 encoding, which is required for [HTTP basic access authentication](https://en.wikipedia.org/wiki/Basic_access_authentication). This library (also a Lua script) is not included. It must be downloaded and stored in the same directory:

```bash
cd ./docker-data/dms/config/dovecot/lua
curl -JLO https://raw.githubusercontent.com/iskolbin/lbase64/master/base64.lua
```

Only use native (pure Lua) libraries as dependencies, such as `base64.lua` from the example. This ensures maximum compatibility. Performance is less of an issue since Lua scripts written for Dovecot probably won't be long or complex, and there won't be a lot of data processing by Lua itself. To see which Lua version is used by Dovecot if you plan to do something that is version dependent, run:

```bash
docker exec mailserver strings /usr/lib/dovecot/libdovecot-lua.so|grep '^LUA_'
```

## Debugging a Lua script

Aside of succeeded and failed authentication attempts for any passdb backend, Dovecot also logs Lua scripting errors and messages send to Dovecot's [Lua API log functions](https://doc.dovecot.org/admin_manual/lua/#dovecot.i_debug). The combined DMS log (including that of Dovecot) can be viewed using `docker logs mailserver` (*where `mailserver` is the container name*). If the log is too noisy (due to other processes in the container also logging to it), `docker exec mailserver cat /var/log/mail/mail.log` can be used to view the log of Dovecot and Postfix specifically. If working with HTTP in Lua, setting `debug = true;` when initiating `dovecot.http.client` will create debug log messages for every HTTP request and response.

Note that Lua runs compiled bytecode, and that scripts will be compiled when they are initially started. Once compiled, the bytecode is cached and changes in the script will not be processed. [Restart sub-service Dovecot][docs-faqalterdms] using `docker exec mailserver supervisorctl restart dovecot` to have Dovecot load a changed Lua script.

[docs-authldap]: ./auth-ldap.md
[docs-dovecotoverrideconfiguration]: ./override-defaults/dovecot.md#override-configuration
[docs-dovecotaddconfiguration]: ./override-defaults/dovecot.md#add-configuration
[docs-faqalterdms]: ../../faq.md#how-to-alter-a-running-dms-instance-without-relaunching-the-container
