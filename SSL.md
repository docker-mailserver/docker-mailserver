# docker-mailserver with ssl

There are multiple options to enable SSL:

* using [letsencrypt](https://letsencrypt.org/)
* using self-signed certificates with the provided tool

## let's encrypt

To enable Let's Encrypt on your mail server, you have to add en environment variable `DMS_SSL` with value `letsencrypt` (see `docker-compose.yml.dist`)
You also have to mount your `letsencrypt` folder to `/etc/letsencrypt` and it should look like that:

    ├── etc
    │   └── letsencrypt
    │       ├── accounts
    │       ├── archive
    │       │   └── mail.domain.com
    │       │       ├── cert1.pem
    │       │       ├── chain1.pem
    │       │       ├── fullchain1.pem
    │       │       └── privkey1.pem
    │       ├── csr
    │       ├── keys
    │       ├── live
    │       │   └── mail.domain.com
    │       │       ├── cert.pem -> ../../archive/mail.domain.com/cert1.pem
    │       │       ├── chain.pem -> ../../archive/mail.domain.com/chain1.pem
    │       │       ├── combined.pem
    │       │       ├── fullchain.pem -> ../../archive/mail.domain.com/fullchain1.pem
    │       │       └── privkey.pem -> ../../archive/mail.domain.com/privkey1.pem
    │       └── renewal

You don't have anything else to do.

## self signed certificates

You can easily generate a self-signed SSL certificate by using the following command:

  docker run -ti --rm -v "$(pwd)"/postfix/ssl:/ssl -h mail.my-domain.com -t tvial/docker-mailserver generate-ssl-certificate

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
  # postfix/ssl/mail.my-domain.com-key.pem (used in postfix)
  # postfix/ssl/mail.my-domain.com-req.pem (only used to generate other files)
  # postfix/ssl/mail.my-domain.com-cert.pem (used in postfix)
  # postfix/ssl/mail.my-domain.com-combined.pem (used in courier)
  # postfix/ssl/demoCA/cacert.pem (certificate authority)

Note that the certificate will be generate for the container `fqdn`, that is passed as `-h` argument.
Check the following page for more information regarding [postfix and SSL/TLS configuration](http://www.mad-hacking.net/documentation/linux/applications/mail/using-ssl-tls-postfix-courier.xml).

If a matching certificate (files listed above) is found in `postfix/ssl`, it will be automatically setup in postfix and courier-imap-ssl. You just have to place them in `postfix/ssl` folder.

