..todo..  - Please contribute more to help others debug this package

## Enable verbose debugging output

You may find it useful to enable the [DMS_DEBUG](https://github.com/tomav/docker-mailserver#dms_debug) environment variable.

## Invalid username or Password


1. Login Container

```bash
docker exec -it <mycontainer> bash
```

2. Check log files

`/var/log/mail`
could not find any mention of incorrect logins here
neither in the dovecot logs

3. Check the supervisors logfiles
`/var/log/supervisor`
You can find the logs for startup of fetchmail, postfix and others here - they might indicate problems during startup

4. Make sure you set your hostname to 'mail' or whatever you specified in your docker-compose.yml file or else your FQDN will be wrong

## Installation Errors

1. During setup, if you get errors trying to edit files inside of the container, you likely need to install vi:

``` bash
sudo su
docker exec -it <mycontainer> apt-get install -y vim
```
## Testing Connection
I spent HOURS trying to debug "Connection Refused" and "Connection closed by foreign host" errors when trying to use telnet to troubleshoot my connection. I was also trying to connect from my email client (macOS mail) around the same time. Telnet had also worked earlier, so I was extremely confused as to why it suddenly stopped working. I stumbled upon fail2ban.log in my container. In short, when trying to get my macOS client working, I exceeded the number of failed login attempts and fail2ban put dovecot and postfix in jail! I got around it by whitelisting my ipaddresses (my ec2 instance and my local computer)

```bash
sudo su
docker exec -ti mail bash
cd /var/log
cat fail2ban.log | grep dovecot

# Whitelist ip addresses:
fail2ban-client set dovecot addignoreip <server ip>  # Server
fail2ban-client set postfix addignoreip <server ip>
fail2ban-client set dovecot addignoreip <client ip>  # Client
fail2ban-client set postfix addignoreip <client ip>

# this will delete the jails entirely - nuclear option
fail2ban-client stop dovecot
fail2ban-client stop postfix
```

## Send email is never received

Some hosting provides have a stealth block on port 25. Make sure to check with your hosting provider that traffic on port 25 is allowed

Common hosting providers known to have this issue:
- [Azure](https://docs.microsoft.com/en-us/azure/virtual-network/troubleshoot-outbound-smtp-connectivity)
- [AWS EC2](https://aws.amazon.com/premiumsupport/knowledge-center/ec2-port-25-throttle/)