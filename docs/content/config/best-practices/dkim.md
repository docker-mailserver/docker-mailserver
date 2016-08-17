To enable DKIM signature, you must have created your mail accounts.
Once its done, just run from inside the directory of docker-compose.yml:

    docker run --rm \
      -v "$(pwd)/config":/tmp/docker-mailserver \
      -ti tvial/docker-mailserver:latest generate-dkim-config

Now the keys are generated, you can configure your DNS server by just pasting the content of `config/opedkim/keys/domain.tld/mail.txt` in your `domain.tld.hosts` zone.

```
; OpenDKIM
mail._domainkey	IN	TXT	( "v=DKIM1; k=rsa; "
	  "p=AZERTYUIOPQSDFGHJKLMWXCVBN/AZERTYUIOPQSDFGHJKLMWXCVBN/AZERTYUIOPQSDFGHJKLMWXCVBN/AZERTYUIOPQSDFGHJKLMWXCVBN/AZERTYUIOPQSDFGHJKLMWXCVBN/AZERTYUIOPQSDFGHJKLMWXCVBN/AZERTYUIOPQSDFGHJKLMWXCVBN/AZERTYUIOPQSDFGHJKLMWXCVBN" )  ; ----- DKIM key mail for domain.tld

```

## Verify-only

If you want DKIM to only verify incoming emails, the following version of /etc/opendkim.conf may be useful (right now there is no easy mechanism for installing it other than forking the repo):
```
# This is a simple config file verifying messages only

#LogWhy                 yes
Syslog                  yes
SyslogSuccess           yes

Socket                  inet:12301@localhost
PidFile                 /var/run/opendkim/opendkim.pid

ReportAddress           postmaster@my-domain.com
SendReports             yes

Mode                    v
```