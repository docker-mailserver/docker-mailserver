..todo..  - Please contribute more to help others debug this package
## Invalid username or Password


1. Login Container

```bash
docker exec -it <mycontainer> bash
```

2. Check log files

`/var/log/mail`
could not find any mention of incorrect logins here
neither in the dovecot logs

3. Make sure you set your hostname to 'mail' or whatever you specified in your docker-compose.yml file or else your FQDN will be wrong

## Installation Errors

1. During setup, if you get errors trying to edit files inside of the container, you likely need to install vi:

    `sudo su`

    `docker exec -it <mycontainer> apt-get install -y vim`
