# Warning! Not yet implemented feature

To enable the `fetchmail` service to retrieve e-mails set the environment variable `ENABLE_FETCHMAIL` to `1`
Your `docker-compose.yml` file should look like following snippet:

```
...
environment:
  - ENABLE_FETCHMAIL=1
...
```

Generate a file called `fetchmail.cf` and place it in the `config` folder.

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

By default the fetchmail service searches very 5 minutes for new mails on your external mail accounts.