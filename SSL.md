# docker-mailserver with ssl

There are multiple options to enable SSL:

* using [letsencrypt](https://letsencrypt.org/) (recommended)
* using self-signed certificates with the provided tool

After installation, you can test your setup with [checktls.com](https://www.checktls.com/TestReceiver).

## let's encrypt (recommended)

To enable Let's Encrypt on your mail server, you have to:

* get your certificate using [letsencrypt client](https://github.com/letsencrypt/letsencrypt)
* add an environment variable `DMS_SSL` with value `letsencrypt` (see `docker-compose.yml.dist`)
* mount your `letsencrypt` folder to `/etc/letsencrypt`

You don't have anything else to do. Enjoy.

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

To use the certificate:

* add an `DMS_SSL=self-signed` to your container environment variables
* if a matching certificate (files listed above) is found in `postfix/ssl`, it will be automatically setup in postfix and courier-imap-ssl. You just have to place them in `postfix/ssl` folder.
