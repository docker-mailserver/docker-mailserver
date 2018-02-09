From [Wikipedia](https://en.wikipedia.org/wiki/Sender_Policy_Framework):

> Sender Policy Framework (SPF) is a simple email-validation system designed to detect email spoofing by providing a mechanism to allow receiving mail exchangers to check that incoming mail from a domain comes from a host authorized by that domain's administrators. The list of authorized sending hosts for a domain is published in the Domain Name System (DNS) records for that domain in the form of a specially formatted TXT record. Email spam and phishing often use forged "from" addresses, so publishing and checking SPF records can be considered anti-spam techniques.

To add a SPF record in your DNS, insert the following line in your DNS zone:

    ; Check that MX is declared
    domain.com. IN  MX 1 mail.domain.com.

    ; Add SPF record
    domain.com. IN TXT "v=spf1 mx ~all" 

Increment DNS serial and reload configuration.

## Backup MX, Secondary MX

For whitelisting a IP-Address from the SPF test, you can create a config file(See [policyd-spf.conf](http://www.linuxcertif.com/man/5/policyd-spf.conf/)) and mount that file into `/etc/postfix-policyd-spf-python/policyd-spf.conf`

**Example:**

Create and edit a policyd-spf.conf file here `/<your Docker-Mailserver dir>/config/postfix-policyd-spf.conf`:
```shell
debugLevel = 1 
#0(only errors)-4(complete data received)

skip_addresses = 127.0.0.0/8,::ffff:127.0.0.0/104,::1

# Preferably use IP-Addresses for whitelist lookups:
Whitelist = 192.168.0.0/31,192.168.1.0/30
# Domain_Whitelist = mx1.mybackupmx.com,mx2.mybackupmx.com

```
Then add this line to `docker-compose.yml` below the `volumes:` section

```yaml
- ./config/postfix-policyd-spf.conf:/etc/postfix-policyd-spf-python/policyd-spf.conf
```