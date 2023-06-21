---
title: 'Override the Default Configs | Dovecot'
---

## Add Configuration

The Dovecot default configuration can easily be extended providing a `docker-data/dms/config/dovecot.cf` file.
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

For major configuration changes it’s best to override the dovecot configuration files. For each configuration file you want to override, add a list entry under the `volumes` key.

```yaml
services:
  mailserver:
    volumes:
      - ./docker-data/dms/mail-data/:/var/mail/
      - ./docker-data/dms/config/dovecot/10-master.conf:/etc/dovecot/conf.d/10-master.conf
```

You will first need to obtain the configuration from the running container (_where `mailserver` is the container name_):

```sh
mkdir -p ./docker-data/dms/config/dovecot
docker cp mailserver:/etc/dovecot/conf.d/10-master.conf ./docker-data/dms/config/dovecot/10-master.conf
```

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
