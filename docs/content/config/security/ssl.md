There are multiple options to enable SSL:

* using [letsencrypt](https://letsencrypt.org/) (recommended)
* using self-signed certificates with the provided tool
* using your own certificates

After installation, you can test your setup with [checktls.com](https://www.checktls.com/TestReceiver).

### Let's encrypt (recommended)

To enable Let's Encrypt on your mail server, you have to:

* get your certificate using [letsencrypt client](https://github.com/letsencrypt/letsencrypt)
* add an environment variable `SSL_TYPE` with value `letsencrypt` (see `docker-compose.yml.dist`)
* mount your whole `letsencrypt` folder to `/etc/letsencrypt`
* the certs folder name located in `letsencrypt/live/` must be the `fqdn` of your container responding to the `hostname` command. The full qualified domain name (`fqdn`) inside the docker container is build combining the `hostname` and `domainname` values of the docker-compose file, e. g.: hostname: `mail`; domainname: `myserver.tld`; fqdn: `mail.myserver.tld`

You don't have anything else to do. Enjoy.

#### Example using docker for letsencrypt
Make a directory to store your letsencrypt logs and configs.

In my case
```
mkdir -p /home/ubuntu/docker/letsencrypt/log 
mkdir -p /home/ubuntu/docker/letsencrypt/etc/letsencrypt
cd /home/ubuntu/docker/letsencrypt
```

Now get the certificate (modify ```mail.myserver.tld```) and following the certbot instructions.
This will need access to port 443 from the internet, adjust your firewall if needed
```
docker run --rm -ti -v $PWD/log/:/var/log/letsencrypt/ -v $PWD/etc/:/etc/letsencrypt/ -p 443:443 deliverous/certbot certonly --standalone -d mail.myserver.tld
```
You can now mount /home/ubuntu/docker/letsencrypt/etc/ in /etc/letsencrypt of ```docker-mailserver```

To renew your certificate just run (this will need access to port 443 from the internet, adjust your firewall if needed)
```
docker run --rm -ti -v $PWD/log/:/var/log/letsencrypt/ -v $PWD/etc/:/etc/letsencrypt/ -p 443:443 deliverous/certbot renew
```


### Self-signed certificates (testing only)

You can easily generate a self-signed SSL certificate by using the following command:

    docker run -ti --rm -v "$(pwd)"/config/ssl:/ssl -h mail.my-domain.com -t tvial/docker-mailserver generate-ssl-certificate

    # Press enter
    # Enter a password when needed
    # Fill information like Country, Organisation name
    # Fill "my-domain.com" as FQDN for CA, and "mail.my-domain.com" for the certificate.
    # They HAVE to be different, otherwise you'll get a `TXT_DB error number 2`
    # Don't fill extras
    # Enter same password when needed
    # Sign the certificate? [y/n]:y
    # 1 out of 1 certificate requests certified, commit? [y/n]y

    # will generate:
    # config/ssl/mail.my-domain.com-key.pem (used in postfix)
    # config/ssl/mail.my-domain.com-req.pem (only used to generate other files)
    # config/ssl/mail.my-domain.com-cert.pem (used in postfix)
    # config/ssl/mail.my-domain.com-combined.pem (used in courier)
    # config/ssl/demoCA/cacert.pem (certificate authority)

Note that the certificate will be generate for the container `fqdn`, that is passed as `-h` argument.
Check the following page for more information regarding [postfix and SSL/TLS configuration](http://www.mad-hacking.net/documentation/linux/applications/mail/using-ssl-tls-postfix-courier.xml).

To use the certificate:

* add `SSL_TYPE=self-signed` to your container environment variables
* if a matching certificate (files listed above) is found in `config/ssl`, it will be automatically setup in postfix and dovecot. You just have to place them in `config/ssl` folder.

### Custom certificate files

You can also provide your own certificate files. Add these entries to your `docker-compose.yml`:

    volumes:
      - /etc/ssl:/tmp/ssl:ro
    environment:
    - SSL_TYPE=manual
    - SSL_CERT_PATH=/tmp/ssl/cert/public.crt
    - SSL_KEY_PATH=/tmp/ssl/private/private.key

This will mount the path where your ssl certificates reside as read-only under `/tmp/ssl`. Then all you have to do is to specify the location of your private key and the certificate.

Please note that you may have to restart your mailserver once the certificates change.

### Testing certificate

From your host:

    docker exec mail openssl s_client -connect 0.0.0.0:25 -starttls smtp -CApath /etc/ssl/certs/

or

    docker exec mail openssl s_client -connect 0.0.0.0:143 -starttls imap -CApath /etc/ssl/certs/


And you should see the certificate chain, the server certificate and:

    Verify return code: 0 (ok)

### Plain text access

Not recommended for purposes other than testing.

Just add this to config/dovecot.cf:

```
ssl = yes
disable_plaintext_auth=no
```

These options in conjunction mean:

```
ssl=yes and disable_plaintext_auth=no: SSL/TLS is offered to the client, but the client isn't required to use it. The client is allowed to login with plaintext authentication even when SSL/TLS isn't enabled on the connection. This is insecure, because the plaintext password is exposed to the internet.
```