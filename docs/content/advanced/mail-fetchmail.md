To enable the [fetchmail](http://www.fetchmail.info) service to retrieve e-mails set the environment variable `ENABLE_FETCHMAIL` to `1`. Your `docker-compose.yml` file should look like following snippet:

```
...
environment:
  - ENABLE_FETCHMAIL=1
...
```

Generate a file called `fetchmail.cf` and place it in the `config` folder. Your dockermail folder should look like this example:

```
├── config
│   ├── dovecot.cf
│   ├── fetchmail.cf
│   ├── postfix-accounts.cf
│   └── postfix-virtual.cf
├── docker-compose.yml
└── README.md
```

# Configuration

A detailed description of the configuration options can be found in the [online version of the manual page](http://www.fetchmail.info/fetchmail-man.html).

## Example IMAP configuration

```
poll 'imap.example.com' proto imap
	user 'username'
	pass 'secret'
	is 'user1@domain.tld'
```

## Example POP3 configuration

```
poll 'pop3.example.com' proto pop3
	user 'username'
	pass 'secret'
	is 'user2@domain.tld'
```

__IMPORTANT__: Don’t forget the last line: e. g. `is 'user1@domain.tld'`. After `is` you have to specify one email address from the configuration file `config/postfix-accounts.cf`. 

More details how to configure fetchmail can be found in the [fetchmail man page in the chapter “The run control file”](http://www.fetchmail.info/fetchmail-man.html#31). 

# Debugging

To debug your `fetchmail.cf` configuration run this command:

```
./setup.sh debug fetchmail
```

For more informations about the configuration script `setup.sh` [[read the corresponding wiki page|Setup-docker-mailserver-using-the-script-setup.sh]].

By default the fetchmail service searches very 5 minutes for new mails on your external mail accounts.