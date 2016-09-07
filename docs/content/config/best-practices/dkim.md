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

## Debug the DKIM TXT Record

You can debug your TXT record with the `dig` tool.

```
dig TXT mail._domainkey.domain.tld
```

Output:

```
; <<>> DiG 9.10.3-P4-Debian <<>> TXT mail._domainkey.domain.tld
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 39669
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 512
;; QUESTION SECTION:
;mail._domainkey.domain.tld. IN	TXT

;; ANSWER SECTION:
mail._domainkey.domain.tld. 3600 IN TXT	"v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCxBSjG6RnWAdU3oOlqsdf2WC0FOUmU8uHVrzxPLW2R3yRBPGLrGO1++yy3tv6kMieWZwEBHVOdefM6uQOQsZ4brahu9lhG8sFLPX4MaKYN/NR6RK4gdjrZu+MYSdfk3THgSbNwIDAQAB"

;; Query time: 50 msec
;; SERVER: 127.0.1.1#53(127.0.1.1)
;; WHEN: Wed Sep 07 18:22:57 CEST 2016
;; MSG SIZE  rcvd: 310
```