---
title: 'Troubleshooting | Debugging'
---

!!! info "Contributions Welcome!"
    Please contribute your solutions to help the community :heart:

## Enable Verbose Debugging Output

You may find it useful to set [`LOG_LEVEL`][docs-environment-log-level] environment variable.

## Invalid Username or Password

1. Shell into the container:

    ```sh
    docker exec -it <my-container> bash
    ```

2. Check log files in `/var/log/mail` could not find any mention of incorrect logins here neither in the dovecot logs.

3. Check the supervisors logs in `/var/log/supervisor`. You can find the logs for startup of fetchmail, postfix and others here - they might indicate problems during startup.

4. Make sure you set your hostname to `mail` or whatever you specified in your `docker-compose.yml` file or else your FQDN will be wrong.

## Installation Errors

During setup, if you get errors trying to edit files inside of the container, you likely need to install `vi`:

```sh
sudo su
docker exec -it <my-container> apt-get install -y vim
```

## Testing Connection

I spent HOURS trying to debug "Connection Refused" and "Connection closed by foreign host" errors when trying to use telnet to troubleshoot my connection. I was also trying to connect from my email client (macOS mail) around the same time. Telnet had also worked earlier, so I was extremely confused as to why it suddenly stopped working. I stumbled upon `fail2ban.log` in my container. In short, when trying to get my macOS client working, I exceeded the number of failed login attempts and fail2ban put dovecot and postfix in jail! I got around it by whitelisting my ipaddresses (my ec2 instance and my local computer)

```sh
sudo su
docker exec -it mailserver bash
cd /var/log
cat fail2ban.log | grep dovecot

# Whitelist IP addresses:
fail2ban-client set dovecot addignoreip <server ip>  # Server
fail2ban-client set postfix addignoreip <server ip>
fail2ban-client set dovecot addignoreip <client ip>  # Client
fail2ban-client set postfix addignoreip <client ip>

# This will delete the jails entirely - nuclear option
fail2ban-client stop dovecot
fail2ban-client stop postfix
```

## Sent email is never received

Some hosting provides have a stealth block on port 25. Make sure to check with your hosting provider that traffic on port 25 is allowed

Common hosting providers known to have this issue:

- [Azure](https://docs.microsoft.com/en-us/azure/virtual-network/troubleshoot-outbound-smtp-connectivity)
- [AWS EC2](https://aws.amazon.com/premiumsupport/knowledge-center/ec2-port-25-throttle/)

[docs-environment-log-level]: ../environment.md#log_level
