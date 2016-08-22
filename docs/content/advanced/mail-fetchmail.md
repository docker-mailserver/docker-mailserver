To enable the `fetchmail` service to retrieve e-mails set the environment variable `ENABLE_FETCHMAIL` to `1`
Your `docker-compose.yml` file should look like following snippet:

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

## Example IMAP configuration

```
poll imap.example.com with proto IMAP
	user 'username' there with
	password 'secret'
	is 'user1@domain.tld'
	here ssl
```

## Example POP3 configuration

```
poll pop3.example.com with proto POP3
	user 'username' there with
	password 'secret'
	is 'user2@domain.tld'
	here options keep ssl
```

To debug your `fetchmail.cf` configuration run this command:

```
docker run --rm \
  -v "$(pwd)/config:/tmp/docker-mailserver" \
  -ti tvial/docker-mailserver:latest \
  sh -c "cat /etc/fetchmailrc_general /tmp/docker-mailserver/fetchmail.cf > /etc/fetchmailrc; /etc/init.d/fetchmail debug-run"
```

By default the fetchmail service searches very 5 minutes for new mails on your external mail accounts.