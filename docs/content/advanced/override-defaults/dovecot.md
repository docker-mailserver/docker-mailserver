# Add configuration

The Dovecot default configuration can easily be extended providing a `config/dovecot.cf` file.
[Dovecot documentation](http://wiki.dovecot.org/FrontPage) remains the best place to find configuration options.

Your `docker-mailserver` folder should look like this example:

```
├── config
│   ├── dovecot.cf
│   ├── postfix-accounts.cf
│   └── postfix-virtual.cf
├── docker-compose.yml
└── README.md
```

One common option to change is the maximum number of connections per user:

```
mail_max_userip_connections = 100
```


# Override configuration

For major configuration changes it’s best to override the `dovecot` configuration files. For each configuration file you want to override, add a list entry under the `volumes:` key.

```yaml
version: '2'

services:
  mail:
  ...
    volumes:
      - maildata:/var/mail
      ...
      - ./config/dovecot/10-master.conf:/etc/dovecot/conf.d/10-master.conf

```

# Debugging

To debug your dovecot configuration you can use this command:

```sh
./setup.sh debug login doveconf | grep <some-keyword>
```

[setup.sh](https://github.com/tomav/docker-mailserver/blob/master/setup.sh) is included in the `docker-mailserver` repository.

or

```sh
docker exec -ti <your-container-name> doveconf | grep <some-keyword>
```

The  `config/dovecot.cf` is copied to `/etc/dovecot/local.conf`. To check this file run:

```sh
docker exec -ti <your-container-name> cat /etc/dovecot/local.conf
```
