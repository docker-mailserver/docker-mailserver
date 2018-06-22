This is a list of all configuration files and directories which are optional or automatically generated in your `config` directory.

## Directories:
- **sieve-filter:** directory for sieve filter scripts. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-Sieve-filters)
- **sieve-pipe:** directory for sieve pipe scripts. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-Sieve-filters)
- **opendkim:** DKIM directory. Autoconfigurable via [setup.sh config dkim](https://github.com/tomav/docker-mailserver/wiki/Setup-docker-mailserver-using-the-script-setup.sh#config). See [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-DKIM) for further info
- **ssl:** SSL Certificate directory. Autoconfigurable via [setup.sh config ssl](https://github.com/tomav/docker-mailserver/wiki/Setup-docker-mailserver-using-the-script-setup.sh#config). Make sure to read the [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-SSL) as well to get a working mail server.

## Files:
- **{user_email_address}.dovecot.sieve:** User specific Sieve filter file. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-Sieve-filters)
- **before.dovecot.sieve:** Global Sieve filter file, applied prior to the ${login}.dovecot.sieve filter. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-Sieve-filters)
- **after.dovecot.sieve**: Global Sieve filter file, applied after the ${login}.dovecot.sieve filter. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-Sieve-filters)
- **postfix-main.cf:** Every line will be added to the postfix main configuration. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Override-Default-Postfix-Configuration)
- **postfix-master.cf:** Every line will be added to the postfix master configuration. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Override-Default-Postfix-Configuration)
- **postfix-accounts.cf:** User accounts file. Modify via the [setup.sh email](https://github.com/tomav/docker-mailserver/wiki/Setup-docker-mailserver-using-the-script-setup.sh#email) script.
- **postfix-send-access.cf:** List of users denied sending. Modify via [setup.sh email restrict](https://github.com/tomav/docker-mailserver/wiki/Setup-docker-mailserver-using-the-script-setup.sh#email)
- **postfix-receive-access.cf:** List of users denied receiving. Modify via [setup.sh email restrict](https://github.com/tomav/docker-mailserver/wiki/Setup-docker-mailserver-using-the-script-setup.sh#email)
- **postfix-virtual.cf:** Alias configuration file. Modify via [setup.sh alias](https://github.com/tomav/docker-mailserver/wiki/Setup-docker-mailserver-using-the-script-setup.sh#alias)
- **postfix-sasl-password.cf:** listing of relayed domains with their respective username:password. Modify via `setup.sh relay add-auth <domain> <username> [<password>]`. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-Relay-Hosts#sender-dependent-authentication)
- **postfix-relaymap.cf:** domain-specific relays and exclusions Modify via `setup.sh relay add-domain` and `setup.sh relay exclude-domain`. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-Relay-Hosts#sender-dependent-relay-host)
- **postfix-regexp.cf:** Regular expression alias file. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-Aliases#configuring-regexp-aliases)
- **ldap-users.cf:** Configuration for the virtual user mapping (virtual_mailbox_maps). See the [start-mailserver.sh](https://github.com/tomav/docker-mailserver/blob/a564cca0e55feba40e273a5419d4c9a864460bf6/target/start-mailserver.sh#L583) script
- **ldap-groups.cf:** Configuration for the virtual alias mapping (virtual_alias_maps). See the [start-mailserver.sh](https://github.com/tomav/docker-mailserver/blob/a564cca0e55feba40e273a5419d4c9a864460bf6/target/start-mailserver.sh#L583) script
- **ldap-aliases.cf:** Configuration for the virtual alias mapping (virtual_alias_maps). See the [start-mailserver.sh](https://github.com/tomav/docker-mailserver/blob/a564cca0e55feba40e273a5419d4c9a864460bf6/target/start-mailserver.sh#L583) script
- **ldap-domains.cf:** Configuration for the virtual domain mapping (virtual_mailbox_domains). See the [start-mailserver.sh](https://github.com/tomav/docker-mailserver/blob/a564cca0e55feba40e273a5419d4c9a864460bf6/target/start-mailserver.sh#L583) script
- **whitelist_clients.local:** Whitelisted domains, not considered by postgrey. Enter one host or domain per line.
- **spamassassin-rules.cf:** Antispam rules for Spamassassin. See [wiki](https://github.com/tomav/docker-mailserver/wiki/FAQ-and-Tips#how-can-i-manage-my-custom-spamassassin-rules)
- **fail2ban-fail2ban.cf:** Additional config options for fail2ban.cf. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-Fail2ban)
- **fail2ban-jail.cf:** Additional config options for fail2ban's jail behaviour. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-Fail2ban)
- **amavis.cf:** replaces the /etc/amavis/conf.d/50-user file
- **dovecot.cf:** replaces /etc/dovecot/local.conf. See [wiki](https://github.com/tomav/docker-mailserver/wiki/Override-Default-Dovecot-Configuration)
