---
title: 'Override the Default Configs | Dovecot'
---

## Add Configuration

The Dovecot configuration of DMS can easily be extended providing a `docker-data/dms/config/dovecot.cf` file.
[Dovecot documentation](https://doc.dovecot.org/configuration_manual/) remains the best place to find configuration options.

Your DMS folder structure should look like this example:

```txt
├── docker-data/dms/config
│   ├── dovecot.cf
│   ├── postfix-accounts.cf
│   └── postfix-virtual.cf
├── compose.yaml
└── README.md
```

One common option to change is the maximum number of connections per user:

```cf
mail_max_userip_connections = 100
```

Another important option is the `default_process_limit` (defaults to `100`). If high-security mode is enabled you'll need to make sure this count is higher than the maximum number of users that can be logged in simultaneously.

This limit is quickly reached if users connect to DMS with multiple end devices.

## Override Configuration

DMS ships its own, self-contained Dovecot configuration. It does not depend on the configuration files that Debian or the Dovecot Community Edition (CE) packages provide. The main file `/etc/dovecot/dovecot.conf` is read by Dovecot in this order:

1. The settings of DMS itself (_`/etc/dovecot/dovecot.conf`, some of them are adjusted at startup according to ENV_)
2. All `*.conf` files in `/etc/dovecot/features.d/` (_features that DMS enabled_)
3. All `*.conf` files in `/etc/dovecot/conf.d/` (_your own files_)
4. `/etc/dovecot/local.conf` (_your `dovecot.cf`_)

Settings that are read later override earlier ones, while sections like `namespace` or `mailbox` and boolean lists like `mail_plugins` are merged. Thus you rarely need to replace a file: add your own file to `/etc/dovecot/conf.d/` instead. It overrides the features, regardless of its file name. For each file you want to add, add a list entry under the `volumes` key:

```yaml
services:
  mailserver:
    volumes:
      - ./docker-data/dms/mail-data/:/var/mail/
      - ./docker-data/dms/config/dovecot/90-custom.conf:/etc/dovecot/conf.d/90-custom.conf:ro
```

!!! note "Features"

    DMS copies the optional features it enables from `/etc/dovecot/features/` to `/etc/dovecot/features.d/` during startup (_`auth-passwdfile.conf`, `auth-ldap.conf`, `auth-oauth2.conf`, `quota.conf` and `rspamd-learn.conf`_). Any file in `conf.d/` overrides them.

    To adjust a feature, override its settings in your own file or in `dovecot.cf`. To inspect it, run `docker exec mailserver cat /etc/dovecot/features/<NAME>.conf`.

You can obtain the configuration of DMS from the running container (_where `mailserver` is the container name_), to see which settings you can override:

```sh
docker exec mailserver cat /etc/dovecot/dovecot.conf
```

## Statistics

DMS keeps Dovecot's upstream defaults for the `stats` service. To verify it works, run:

```sh
docker exec -it mailserver doveadm -f table stats dump
```

To collect metrics or expose them via the OpenMetrics `http` listener, add the relevant configuration to `dovecot.cf` as described in the [Dovecot statistics docs](https://doc.dovecot.org/main/core/config/statistics.html).

## Debugging

To debug your dovecot configuration you can use:

- This command: `./setup.sh debug login doveconf | grep <some-keyword>`
- Or: `docker exec -it mailserver doveconf | grep <some-keyword>`

!!! note
    [`setup.sh`][github-file-setupsh] is included in the DMS repository. Make sure to use the one matching your image version release.

The file `docker-data/dms/config/dovecot.cf` is copied internally to `/etc/dovecot/local.conf`. To verify the file content, run:

```sh
docker exec -it mailserver cat /etc/dovecot/local.conf
```

[github-file-setupsh]: https://github.com/docker-mailserver/docker-mailserver/blob/master/setup.sh
