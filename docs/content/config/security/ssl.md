---
title: 'Security | TLS (aka SSL)'
---

There are multiple options to enable SSL:

- Using [letsencrypt](#lets-encrypt-recommended) (recommended)
- Using [Caddy](#caddy)
- Using [Traefik](#traefik)
- Using [self-signed certificates](#self-signed-certificates-testing-only) with the provided tool
- Using [your own certificates](#custom-certificate-files)

After installation, you can test your setup with:

- [`checktls.com`](https://www.checktls.com/TestReceiver)
- [`testssl.sh`](https://github.com/drwetter/testssl.sh)

## Let's Encrypt (Recommended)

To enable Let's Encrypt on your mail server, you have to:

- Get your certificate using [letsencrypt client](https://github.com/letsencrypt/letsencrypt)
- Add an environment variable `SSL_TYPE` with value `letsencrypt` (see [`docker-compose.yml`][github-file-compose])
- Mount your whole `letsencrypt` folder to `/etc/letsencrypt`
- The certs folder name located in `letsencrypt/live/` must be the `fqdn` of your container responding to the `hostname` command. The `fqdn` (full qualified domain name) inside the docker container is built combining the `hostname` and `domainname` values of the `docker-compose` file, eg:

    ```yaml
    services:
      mail:
        hostname: mail
        domainname: myserver.tld
        fqdn: mail.myserver.tld
    ```

You don't have anything else to do. Enjoy.

### Example using Docker for Let's Encrypt

1. Make a directory to store your letsencrypt logs and configs. In my case:

    ```sh
    mkdir -p /home/ubuntu/docker/letsencrypt 
    cd /home/ubuntu/docker/letsencrypt
    ```

2. Now get the certificate (modify `mail.myserver.tld`) and following the certbot instructions.

3. This will need access to port 80 from the internet, adjust your firewall if needed:

    ```sh
    docker run --rm -it \
      -v $PWD/log/:/var/log/letsencrypt/ \
      -v $PWD/etc/:/etc/letsencrypt/ \
      -p 80:80 \
      certbot/certbot certonly --standalone -d mail.myserver.tld
    ```

4. You can now mount `/home/ubuntu/docker/letsencrypt/etc/` in `/etc/letsencrypt` of `docker-mailserver`.

    To renew your certificate just run (this will need access to port 443 from the internet, adjust your firewall if needed):

    ```sh
    docker run --rm -it \
      -v $PWD/log/:/var/log/letsencrypt/ \
      -v $PWD/etc/:/etc/letsencrypt/ \
      -p 80:80 \
      -p 443:443 \
      certbot/certbot renew
    ```

### Example using Docker, `nginx-proxy` and `letsencrypt-nginx-proxy-companion`

If you are running a web server already, it is non-trivial to generate a Let's Encrypt certificate for your mail server using `certbot`, because port 80 is already occupied. In the following example, we show how `docker-mailserver` can be run alongside the docker containers `nginx-proxy` and `letsencrypt-nginx-proxy-companion`.

There are several ways to start `nginx-proxy` and `letsencrypt-nginx-proxy-companion`. Any method should be suitable here.

For example start `nginx-proxy` as in the `letsencrypt-nginx-proxy-companion` [documentation](https://github.com/JrCs/docker-letsencrypt-nginx-proxy-companion):

```sh
docker run --detach \
  --name nginx-proxy \
  --restart always \
  --publish 80:80 \
  --publish 443:443 \
  --volume /server/letsencrypt/etc:/etc/nginx/certs:ro \
  --volume /etc/nginx/vhost.d \
  --volume /usr/share/nginx/html \
  --volume /var/run/docker.sock:/tmp/docker.sock:ro \
  jwilder/nginx-proxy
```

Then start `nginx-proxy-letsencrypt`:

```sh
docker run --detach \
  --name nginx-proxy-letsencrypt \
  --restart always \
  --volume /server/letsencrypt/etc:/etc/nginx/certs:rw \
  --volumes-from nginx-proxy \
  --volume /var/run/docker.sock:/var/run/docker.sock:ro \
  jrcs/letsencrypt-nginx-proxy-companion
```

Start the rest of your web server containers as usual.

Start another container for your `mail.myserver.tld`. This will generate a Let's Encrypt certificate for your domain, which can be used by `docker-mailserver`. It will also run a web server on port 80 at that address:

```sh
docker run -d \
  --name webmail \
  -e "VIRTUAL_HOST=mail.myserver.tld" \
  -e "LETSENCRYPT_HOST=mail.myserver.tld" \
  -e "LETSENCRYPT_EMAIL=foo@bar.com" \
  library/nginx
```

You may want to add `-e LETSENCRYPT_TEST=true` to the above while testing to avoid the Let's Encrypt certificate generation rate limits.

Finally, start the mailserver with the `docker-compose.yml`. Make sure your mount path to the letsencrypt certificates is correct.

Inside your `/path/to/mailserver/docker-compose.yml` (for the mailserver from this repo) make sure volumes look like below example:

```yaml
volumes:
  - maildata:/var/mail
  - mailstate:/var/mail-state
  - ./config/:/tmp/docker-mailserver/
  - /server/letsencrypt/etc:/etc/letsencrypt/live
```

Then: `/path/to/mailserver/docker-compose up -d mail`

### Example using Docker, `nginx-proxy` and `letsencrypt-nginx-proxy-companion` with `docker-compose`

The following `docker-compose.yml` is the basic setup you need for using `letsencrypt-nginx-proxy-companion`. It is mainly derived from its own wiki/documenation.

???+ example "Example Code"

    ```yaml
    version: "2"

    services:
      nginx: 
        image: nginx
        container_name: nginx
        ports:
          - 80:80
          - 443:443
        volumes:
          - /mnt/data/nginx/htpasswd:/etc/nginx/htpasswd
          - /mnt/data/nginx/conf.d:/etc/nginx/conf.d
          - /mnt/data/nginx/vhost.d:/etc/nginx/vhost.d
          - /mnt/data/nginx/html:/usr/share/nginx/html
          - /mnt/data/nginx/certs:/etc/nginx/certs:ro
        networks:
          - proxy-tier
        restart: always

      nginx-gen:
        image: jwilder/docker-gen
        container_name: nginx-gen
        volumes:
          - /var/run/docker.sock:/tmp/docker.sock:ro
          - /mnt/data/nginx/templates/nginx.tmpl:/etc/docker-gen/templates/nginx.tmpl:ro
        volumes_from:
          - nginx
        entrypoint: /usr/local/bin/docker-gen -notify-sighup nginx -watch -wait 5s:30s /etc/docker-gen/templates/nginx.tmpl /etc/nginx/conf.d/default.conf
        restart: always

      letsencrypt-nginx-proxy-companion:
        image: jrcs/letsencrypt-nginx-proxy-companion
        container_name: letsencrypt-companion
        volumes_from:
          - nginx
        volumes:
          - /var/run/docker.sock:/var/run/docker.sock:ro
          - /mnt/data/nginx/certs:/etc/nginx/certs:rw
        environment:
          - NGINX_DOCKER_GEN_CONTAINER=nginx-gen
          - DEBUG=false
        restart: always

    networks:
      proxy-tier:
        external:
          name: nginx-proxy
    ```

The second part of the setup is the actual mail container. So, in another folder, create another `docker-compose.yml` with the following content (Removed all ENV variables for this example):

???+ example "Example Code"

    ```yaml
    version: '2'
    services:
      mail:
        image: mailserver/docker-mailserver:latest
        hostname: ${HOSTNAME}
        domainname: ${DOMAINNAME}
        container_name: ${CONTAINER_NAME}
        ports:
        - "25:25"
        - "143:143"
        - "465:465"
        - "587:587"
        - "993:993"
        volumes:
        - ./mail:/var/mail
        - ./mail-state:/var/mail-state
        - ./config/:/tmp/docker-mailserver/
        - /mnt/data/nginx/certs/:/etc/letsencrypt/live/:ro
        cap_add:
        - NET_ADMIN
        - SYS_PTRACE
        restart: always

      cert-companion:
        image: nginx
        environment:
          - "VIRTUAL_HOST="
          - "VIRTUAL_NETWORK=nginx-proxy"
          - "LETSENCRYPT_HOST="
          - "LETSENCRYPT_EMAIL="
        networks:
          - proxy-tier
        restart: always

    networks:
      proxy-tier:
        external:
          name: nginx-proxy
    ```

The mail container needs to have the letsencrypt certificate folder mounted as a volume. No further changes are needed. The second container is a dummy-sidecar we need, because the mail-container do not expose any web-ports. Set your ENV variables as you need. (`VIRTUAL_HOST` and `LETSENCRYPT_HOST` are mandandory, see documentation)

### Example using the Let's Encrypt Certificates on a Synology NAS

Version 6.2 and later of the Synology NAS DSM OS now come with an interface to generate and renew letencrypt certificates. Navigation into your DSM control panel and go to Security, then click on the tab Certificate to generate and manage letsencrypt certificates.

Amongst other things, you can use these to secure your mail server. DSM locates the generated certificates in a folder below `/usr/syno/etc/certificate/_archive/`.

Navigate to that folder and note the 6 character random folder name of the certificate you'd like to use. Then, add the following to your `docker-compose.yml` declaration file:

```yaml
volumes:
  - /usr/syno/etc/certificate/_archive/<your-folder>/:/tmp/ssl
environment:
  - SSL_TYPE=manual
  - SSL_CERT_PATH=/tmp/ssl/fullchain.pem
  - SSL_KEY_PATH=/tmp/ssl/privkey.pem
```

DSM-generated letsencrypt certificates get auto-renewed every three months.

## Caddy

If you are using Caddy to renew your certificates, please note that only RSA certificates work. Read [#1440][github-issue-1440] for details. In short for Caddy v1 the `Caddyfile` should look something like:

```caddyfile
https://mail.domain.com {
  tls yourcurrentemail@gmail.com {
    key_type rsa2048
  }
}
```

For Caddy v2 you can specify the `key_type` in your server's global settings, which would end up looking something like this if you're using a `Caddyfile`:

```caddyfile
{
  debug
  admin localhost:2019
  http_port 80
  https_port 443
  default_sni mywebserver.com
  key_type rsa4096
}
```

If you are instead using a json config for Caddy v2, you can set it in your site's TLS automation policies:

???+ example "Example Code"

    ```json
    {
      "apps": {
        "http": {
          "servers": {
            "srv0": {
              "listen": [
                ":443"
              ],
              "routes": [
                {
                  "match": [
                    {
                      "host": [
                        "mail.domain.com",
                      ]
                    }
                  ],
                  "handle": [
                    {
                      "handler": "subroute",
                      "routes": [
                        {
                          "handle": [
                            {
                              "body": "",
                              "handler": "static_response"
                            }
                          ]
                        }
                      ]
                    }
                  ],
                  "terminal": true
                },
              ]
            }
          }
        },
        "tls": {
          "automation": {
            "policies": [
              {
                "subjects": [
                  "mail.domain.com",
                ],
                "key_type": "rsa2048",
                "issuer": {
                  "email": "email@email.com",
                  "module": "acme"
                }
              },
              {
                "issuer": {
                  "email": "email@email.com",
                  "module": "acme"
                }
              }
            ]
          }
        }
      }
    }
    ```

The generated certificates can be mounted:

```yaml
volumes:
  - ${CADDY_DATA_DIR}/certificates/acme-v02.api.letsencrypt.org-directory/mail.domain.com/mail.domain.com.crt:/etc/letsencrypt/live/mail.domain.com/fullchain.pem
  - ${CADDY_DATA_DIR}/certificates/acme-v02.api.letsencrypt.org-directory/mail.domain.com/mail.domain.com.key:/etc/letsencrypt/live/mail.domain.com/privkey.pem
```

EC certificates fail in the TLS handshake:

```log
CONNECTED(00000003)
140342221178112:error:14094410:SSL routines:ssl3_read_bytes:sslv3 alert handshake failure:ssl/record/rec_layer_s3.c:1543:SSL alert number 40
no peer certificate available
No client certificate CA names sent
```

## Traefik

[Traefik](https://github.com/containous/traefik) is an open-source Edge Router which handles ACME protocol using [lego](https://github.com/go-acme/lego).

Traefik can request certificates for domains through the ACME protocol (see [Traefik's documentation about its ACME negotiation & storage mechanism](https://docs.traefik.io/https/acme/)). Traefik's router will take care of renewals, challenge negotiations, etc.

### Traefik v2

(For Traefik v1 see [next section](#traefik-v1))

Traefik's V2 storage format is natively supported if the `acme.json` store is mounted into the container at `/etc/letsencrypt/acme.json`. The file is also monitored for changes and will trigger a reload of the mail services. Lookup of the certificate domain happens in the following order:

1. `$SSL_DOMAIN`
2. `$HOSTNAME`
3. `$DOMAINNAME`

This allows for support of wild card certificates: `SSL_DOMAIN=*.example.com`. Here is an example setup for [`docker-compose`](https://docs.docker.com/compose/):

???+ example "Example Code"

    ```yaml
    version: '3.8'
    services:
      mail:
        image: mailserver/docker-mailserver:stable
        hostname: mail
        domainname: example.com
        volumes:
        - /etc/ssl/acme-v2.json:/etc/letsencrypt/acme.json:ro
        environment:
          SSL_TYPE: letsencrypt
          # SSL_DOMAIN: "*.example.com" 
      traefik:
        image: traefik:v2.2
        restart: always
        ports:
        - "80:80"
        - "443:443"
        command:
        - --providers.docker
        - --entrypoints.web.address=:80
        - --entrypoints.web.http.redirections.entryPoint.to=websecure
        - --entrypoints.web.http.redirections.entryPoint.scheme=https
        - --entrypoints.websecure.address=:443
        - --entrypoints.websecure.http.middlewares=hsts@docker
        - --entrypoints.websecure.http.tls.certResolver=le
        - --certificatesresolvers.le.acme.email=admin@example.net
        - --certificatesresolvers.le.acme.storage=/acme.json
        - --certificatesresolvers.le.acme.httpchallenge.entrypoint=web
        volumes:
        - /var/run/docker.sock:/var/run/docker.sock:ro
        - /etc/ssl/acme-v2.json:/acme.json

      whoami:
        image: containous/whoami
        labels:
        - "traefik.http.routers.whoami.rule=Host(`mail.example.com`)"
    ```

This setup only comes with one caveat: The domain has to be configured on another service for traefik to actually request it from lets-encrypt (`whoami` in this case).

### Traefik v1

If you are using Traefik v1, you might want to _push_ your Traefik-managed certificates to the mailserver container, in order to reuse them. Not an easy task, but fortunately, [`youtous/mailserver-traefik`][youtous-mailtraefik] is a certificate renewal service for `docker-mailserver`.

Depending of your Traefik configuration, certificates may be stored using a file or a KV Store (consul, etcd...) Either way, certificates will be renewed by Traefik, then automatically pushed to the mailserver thanks to the `cert-renewer` service. Finally, dovecot and postfix will be restarted.

## Self-Signed Certificates

!!! warning

    Use self-signed certificates only for testing purposes!

You can  generate a self-signed SSL certificate by using the following command:

```sh
docker run -it --rm -v "$(pwd)"/config/ssl:/tmp/docker-mailserver/ssl -h mail.my-domain.com -t mailserver/docker-mailserver generate-ssl-certificate

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
```

!!! note
    The certificate will be generate for the container `fqdn`, that is passed as `-h` argument.

    Check the following page for more information regarding [postfix and SSL/TLS configuration](http://www.mad-hacking.net/documentation/linux/applications/mail/using-ssl-tls-postfix-courier.xml).

To use the certificate:

- Add `SSL_TYPE=self-signed` to your container environment variables
- If a matching certificate (files listed above) is found in `config/ssl`, it will be automatically setup in postfix and dovecot. You just have to place them in `config/ssl` folder.

## Custom Certificate Files

You can also provide your own certificate files. Add these entries to your `docker-compose.yml`:

```yaml
volumes:
  - /etc/ssl:/tmp/ssl:ro
environment:
  - SSL_TYPE=manual
  - SSL_CERT_PATH=/tmp/ssl/cert/public.crt
  - SSL_KEY_PATH=/tmp/ssl/private/private.key
```

This will mount the path where your ssl certificates reside as read-only under `/tmp/ssl`. Then all you have to do is to specify the location of your private key and the certificate.

!!! info
    You may have to restart your mailserver once the certificates change.

## Testing a Certificate is Valid

- From your host:

    ```sh
    docker exec mail openssl s_client \
      -connect 0.0.0.0:25 \
      -starttls smtp \
      -CApath /etc/ssl/certs/
    ```

- Or:

    ```sh
    docker exec mail openssl s_client \
      -connect 0.0.0.0:143 \
      -starttls imap \
      -CApath /etc/ssl/certs/
    ```

And you should see the certificate chain, the server certificate and: `Verify return code: 0 (ok)`

In addition, to verify certificate dates:

```sh
docker exec mail openssl s_client \
  -connect 0.0.0.0:25 \
  -starttls smtp \
  -CApath /etc/ssl/certs/ \
  2>/dev/null | openssl x509 -noout -dates
```

## Plain-Text Access

!!! warning

    Not recommended for purposes other than testing.

Add this to `config/dovecot.cf`:

```cf
ssl = yes
disable_plaintext_auth=no
```

These options in conjunction mean:

- SSL/TLS is offered to the client, but the client isn't required to use it.
- The client is allowed to login with plaintext authentication even when SSL/TLS isn't enabled on the connection.
- **This is insecure**, because the plaintext password is exposed to the internet.

## Importing Certificates Obtained via Another Source

If you have another source for SSL/TLS certificates you can import them into the server via an external script. The external script can be found here: [external certificate import script][hanscees-renewcerts].

The steps to follow are these:

1. Transport the new certificates to `./config/ssl` (`/tmp/ssl` in the container)
2. You should provide `fullchain.key` and `privkey.pem`
3. Place the script in `./config/` (or `/tmp/docker-mailserver/` inside the container)
4. Make the script executable (`chmod +x tomav-renew-certs.sh`)
5. Run the script: `docker exec mail /tmp/docker-mailserver/tomav-renew-certs.sh`

If an error occurs the script will inform you. If not you will see both postfix and dovecot restart.

After the certificates have been loaded you can check the certificate:

```sh
openssl s_client \
  -servername mail.mydomain.net \
  -connect 192.168.0.72:465 \
  2>/dev/null | openssl x509

# or

openssl s_client \
  -servername mail.mydomain.net \
  -connect mail.mydomain.net:465 \
  2>/dev/null | openssl x509
```

Or you can check how long the new certificate is valid with commands like:

```sh
export SITE_URL="mail.mydomain.net"
export SITE_IP_URL="192.168.0.72" # can also be `mail.mydomain.net`
export SITE_SSL_PORT="993" # imap port dovecot

##works: check if certificate will expire in two weeks 
#2 weeks is 1209600 seconds
#3 weeks is 1814400
#12 weeks is 7257600
#15 weeks is 9072000

certcheck_2weeks=`openssl s_client -connect ${SITE_IP_URL}:${SITE_SSL_PORT} \
  -servername ${SITE_URL} 2> /dev/null | openssl x509 -noout -checkend 1209600`

####################################
#notes: output can be
#Certificate will not expire
#Certificate will expire
####################
```

What does the script that imports the certificates do:

1. Check if there are new certs in the `/tmp/ssl` folder.
2. Check with the ssl cert fingerprint if they differ from the current certificates.
3. If so it will copy the certs to the right places.
4. And restart postfix and dovecot.

You can of course run the script by cron once a week or something. In that way you could automate cert renewal. If you do so it is probably wise to run an automated check on certificate expiry as well. Such a check could look something like this:

```sh
## code below will alert if certificate expires in less than two weeks
## please adjust varables! 
## make sure the mail -s command works! Test!

export SITE_URL="mail.mydomain.net"
export SITE_IP_URL="192.168.2.72" # can also be `mail.mydomain.net`
export SITE_SSL_PORT="993" # imap port dovecot
export ALERT_EMAIL_ADDR="bill@gates321boom.com"

certcheck_2weeks=`openssl s_client -connect ${SITE_IP_URL}:${SITE_SSL_PORT} \
  -servername ${SITE_URL} 2> /dev/null | openssl x509 -noout -checkend 1209600`

####################################
#notes: output can be
#Certificate will not expire
#Certificate will expire
####################

#echo "certcheck 2 weeks gives $certcheck_2weeks"

##automated check you might run by cron or something
## does tls/ssl certificate expire within two weeks?

if [ "$certcheck_2weeks" = "Certificate will not expire" ]; then
  echo "all is well, certwatch 2 weeks says $certcheck_2weeks"
  else
    echo "Cert seems to be expiring pretty soon, within two weeks: $certcheck_2weeks"
    echo "we will send an alert email and log as well"
    logger Certwatch: cert $SITE_URL will expire in two weeks
    echo "Certwatch: cert $SITE_URL will expire in two weeks" | mail -s "cert $SITE_URL expires in two weeks " $ALERT_EMAIL_ADDR 
fi
```

[github-file-compose]: https://github.com/docker-mailserver/docker-mailserver/blob/master/docker-compose.yml
[github-issue-1440]: https://github.com/docker-mailserver/docker-mailserver/issues/1440
[hanscees-renewcerts]: https://github.com/hanscees/dockerscripts/blob/master/scripts/tomav-renew-certs
[youtous-mailtraefik]: https://github.com/youtous/docker-mailserver-traefik
