The Dovecot default configuration can easily be overridden providing a `config/dovecot.cf` file.
This file can also be used to specify additional configurations.
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
