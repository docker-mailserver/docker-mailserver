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

To enable Let's Encrypt for `docker-mailserver`, you have to:

- Get your certificate using [letsencrypt client](https://github.com/letsencrypt/letsencrypt)
- Add an environment variable `SSL_TYPE` with value `letsencrypt` (see [`docker-compose.yml`][github-file-compose])
- Mount your whole `letsencrypt` folder to `/etc/letsencrypt`
- The certs folder name located in `letsencrypt/live/` must be the `fqdn` of your container responding to the `hostname` command. The `fqdn` (full qualified domain name) inside the docker container is built combining the `hostname` and `domainname` values of the `docker-compose` file, eg:

    ```yaml
    services:
      mailserver:
        hostname: mail
        domainname: example.com
        fqdn: mail.example.com
    ```

You don't have anything else to do. Enjoy.

### Example using Docker for Let's Encrypt

1. Make a directory to store your letsencrypt logs and configs. In my case:

    ```sh
    mkdir -p /home/ubuntu/docker/letsencrypt 
    cd /home/ubuntu/docker/letsencrypt
    ```

2. Now get the certificate (modify `mail.example.com`) and following the certbot instructions.

3. This will need access to port 80 from the internet, adjust your firewall if needed:

    ```sh
    docker run --rm -it \
      -v $PWD/log/:/var/log/letsencrypt/ \
      -v $PWD/etc/:/etc/letsencrypt/ \
      -p 80:80 \
      certbot/certbot certonly --standalone -d mail.example.com
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

If you are running a web server already, it is non-trivial to generate a Let's Encrypt certificate for your `docker-mailserver` using `certbot`, because port 80 is already occupied. In the following example, we show how `docker-mailserver` can be run alongside the docker containers `nginx-proxy` and `letsencrypt-nginx-proxy-companion`.

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

Start another container for your `mail.example.com`. This will generate a Let's Encrypt certificate for your domain, which can be used by `docker-mailserver`. It will also run a web server on port 80 at that address:

```sh
docker run -d \
  --name webmail \
  -e "VIRTUAL_HOST=mail.example.com" \
  -e "LETSENCRYPT_HOST=mail.example.com" \
  -e "LETSENCRYPT_EMAIL=admin@example.com" \
  library/nginx
```

You may want to add `-e LETSENCRYPT_TEST=true` to the above while testing to avoid the Let's Encrypt certificate generation rate limits.

Make sure your mount path to the letsencrypt certificates is correct. Edit your `/path/to/mailserver/docker-compose.yml` for the `mailserver` service to have volumes added like the example below:

```yaml
volumes:
  - ./docker-data/dms/mail-data/:/var/mail/
  - ./docker-data/dms/mail-state/:/var/mail-state/
  - ./docker-data/dms/config/:/tmp/docker-mailserver/
  - /server/letsencrypt/etc:/etc/letsencrypt/live
```

Then from the `docker-compose.yml` directory, run: `docker-compose up -d mailserver`.

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

The second part of the setup is the `docker-mailserver` container. So, in another folder, create another `docker-compose.yml` with the following content (Removed all ENV variables for this example):

???+ example "Example Code"

    ```yaml
    version: '3.8'
    services:
      mailserver:
        image: docker.io/mailserver/docker-mailserver:latest
        container_name: mailserver
        hostname: mail
        domainname: example.com
        ports:
          - "25:25"
          - "143:143"
          - "465:465"
          - "587:587"
          - "993:993"
        volumes:
          - ./docker-data/dms/mail-data/:/var/mail/
          - ./docker-data/dms/mail-state/:/var/mail-state/
          - ./docker-data/dms/config/:/tmp/docker-mailserver/
          - ./docker-data/nginx-proxy/certs/:/etc/letsencrypt/live/:ro
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

`docker-mailserver` needs to have the letsencrypt certificate folder mounted as a volume. No further changes are needed. The second container is a dummy-sidecar we need, because the mail-container do not expose any web-ports. Set your ENV variables as you need. (`VIRTUAL_HOST` and `LETSENCRYPT_HOST` are mandandory, see documentation)

### Example using the Let's Encrypt Certificates on a Synology NAS

Version 6.2 and later of the Synology NAS DSM OS now come with an interface to generate and renew letencrypt certificates. Navigation into your DSM control panel and go to Security, then click on the tab Certificate to generate and manage letsencrypt certificates.

Amongst other things, you can use these to secure your mail-server. DSM locates the generated certificates in a folder below `/usr/syno/etc/certificate/_archive/`.

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
https://mail.example.com {
  tls admin@example.com {
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
  default_sni example.com
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
                        "mail.example.com",
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
                  "mail.example.com",
                ],
                "key_type": "rsa2048",
                "issuer": {
                  "email": "admin@example.com",
                  "module": "acme"
                }
              },
              {
                "issuer": {
                  "email": "admin@example.com",
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
  - ${CADDY_DATA_DIR}/certificates/acme-v02.api.letsencrypt.org-directory/mail.example.com/mail.example.com.crt:/etc/letsencrypt/live/mail.example.com/fullchain.pem
  - ${CADDY_DATA_DIR}/certificates/acme-v02.api.letsencrypt.org-directory/mail.example.com/mail.example.com.key:/etc/letsencrypt/live/mail.example.com/privkey.pem
```

EC certificates fail in the TLS handshake:

```log
CONNECTED(00000003)
140342221178112:error:14094410:SSL routines:ssl3_read_bytes:sslv3 alert handshake failure:ssl/record/rec_layer_s3.c:1543:SSL alert number 40
no peer certificate available
No client certificate CA names sent
```

## Traefik v2

[Traefik][traefik::github] is an open-source application proxy using the [ACME protocol][ietf::rfc::acme]. [Traefik][traefik::github] can request certificates for domains and subdomains, and it will take care of renewals, challenge negotiations, etc. We strongly recommend to use [Traefik][traefik::github]'s major version 2.

[Traefik][traefik::github]'s storage format is natively supported if the `acme.json` store is mounted into the container at `/etc/letsencrypt/acme.json`. The file is also monitored for changes and will trigger a reload of the mail services (Postfix and Dovecot). Wild card certificates issued for `*.example.com` are supported. You will then want to use `#!bash SSL_DOMAIN=example.com`. Lookup of the certificate domain happens in the following order:

1. `#!bash ${SSL_DOMAIN}`
2. `#!bash ${HOSTNAME}`
3. `#!bash ${DOMAINNAME}`

This setup only comes with one caveat: The domain has to be configured on another service for [Traefik][traefik::github] to actually request it from Let'sEncrypt, i.e. [Traefik][traefik::github] will not issue a certificate without a service / router demanding it.

???+ example "Example Code"
    Here is an example setup for [`docker-compose`](https://docs.docker.com/compose/):

    ```yaml
    version: '3.8'
    services:
      mailserver:
        image: docker.io/mailserver/docker-mailserver:latest
        container_name: mailserver
        hostname: mail
        domainname: example.com
        volumes:
           - ./docker-data/traefik/acme.json:/etc/letsencrypt/acme.json:ro
        environment:
          SSL_TYPE: letsencrypt
          SSL_DOMAIN: mail.example.com
          # for a wildcard certificate, use
          # SSL_DOMAIN: example.com

      reverse-proxy:
        image: docker.io/traefik:latest #v2.5
        container_name: docker-traefik
        ports:
           - "80:80"
           - "443:443"
        command:
           - --providers.docker
           - --entrypoints.http.address=:80
           - --entrypoints.http.http.redirections.entryPoint.to=https
           - --entrypoints.http.http.redirections.entryPoint.scheme=https
           - --entrypoints.https.address=:443
           - --entrypoints.https.http.tls.certResolver=letsencrypt
           - --certificatesresolvers.letsencrypt.acme.email=admin@example.com
           - --certificatesresolvers.letsencrypt.acme.storage=/acme.json
           - --certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=http
        volumes:
           - ./docker-data/traefik/acme.json:/acme.json
           - /var/run/docker.sock:/var/run/docker.sock:ro

      whoami:
        image: docker.io/traefik/whoami:latest
        labels:
           - "traefik.http.routers.whoami.rule=Host(`mail.example.com`)"
    ```

## Self-Signed Certificates

!!! warning

    Use self-signed certificates only for testing purposes!

This feature requires you to provide the following files into your [`docker-data/dms/config/ssl/` directory][docs-optional-config] (_internal location: `/tmp/docker-mailserver/ssl/`_):

- `<FQDN>-key.pem`
- `<FQDN>-cert.pem`
- `demoCA/cacert.pem`

Where `<FQDN>` is the [FQDN](https://en.wikipedia.org/wiki/Fully_qualified_domain_name) assigned to `docker-mailserver` (_eg: `mail.example.com` (FQDN) => `mail` (hostname) + `example.com` (domainname)_) via `docker run` command or `docker-compose.yml` config.

Add `SSL_TYPE=self-signed` to your `docker-mailserver` environment variables. Postfix and Dovecot will be configured to use the provided certificate (_`.pem` files above_) during container startup.

### Generating a self-signed certificate

!!! note

    Since `docker-mailserver` v10, support in `setup.sh` for generating a _self-signed SSL certificate_ internally was removed.

One way to generate self-signed certificates is with [Smallstep's `step` CLI](https://smallstep.com/docs/step-cli). This is exactly what [`docker-mailserver` does for creating test certificates][github-file::tls-readme].

For example with the FQDN `mail.example.test`, you can generate the required files by running:

```sh
#! /bin/sh
mkdir -p demoCA

step certificate create "Smallstep Root CA" "demoCA/cacert.pem" "demoCA/cakey.pem" \
  --no-password --insecure \
  --profile root-ca \
  --not-before "2021-01-01T00:00:00+00:00" \
  --not-after "2031-01-01T00:00:00+00:00" \
  --san "example.test" \
  --san "mail.example.test" \
  --kty RSA --size 2048

step certificate create "Smallstep Leaf" mail.example.test-cert.pem mail.example.test-key.pem \
  --no-password --insecure \
  --profile leaf \
  --ca "demoCA/cacert.pem" \
  --ca-key "demoCA/cakey.pem" \
  --not-before "2021-01-01T00:00:00+00:00" \
  --not-after "2031-01-01T00:00:00+00:00" \
  --san "example.test" \
  --san "mail.example.test" \
  --kty RSA --size 2048
```

If you'd rather not install the CLI tool locally to run the `step` commands above; you can save the script above to a file such as `generate-certs.sh` (_and make it executable `chmod +x generate-certs.sh`_) in a directory that you want the certs to be placed, then run that script with docker:

```sh
# '--user' is to keep ownership of the files written to
# the local volume to use your systems User and Group ID values.
docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  --volume "${PWD}:/tmp" \
  --workdir "/tmp" \
  --entrypoint "/tmp/generate-certs.sh" \
  smallstep/step-ca
```

## Bring Your Own Certificates

You can also provide your own certificate files. Add these entries to your `docker-compose.yml`:

```yaml
volumes:
  - ./docker-data/dms/config/ssl/:/tmp/ssl/:ro
environment:
  - SSL_TYPE=manual
  - SSL_CERT_PATH=/tmp/ssl/cert/public.crt
  - SSL_KEY_PATH=/tmp/ssl/private/private.key
```

This will mount the path where your ssl certificates reside as read-only under `/tmp/ssl`. Then all you have to do is to specify the location of your private key and the certificate.

!!! info
    You may have to restart `docker-mailserver` once the certificates change.

## Testing a Certificate is Valid

- From your host:

    ```sh
    docker exec mailserver openssl s_client \
      -connect 0.0.0.0:25 \
      -starttls smtp \
      -CApath /etc/ssl/certs/
    ```

- Or:

    ```sh
    docker exec mailserver openssl s_client \
      -connect 0.0.0.0:143 \
      -starttls imap \
      -CApath /etc/ssl/certs/
    ```

And you should see the certificate chain, the server certificate and: `Verify return code: 0 (ok)`

In addition, to verify certificate dates:

```sh
docker exec mailserver openssl s_client \
  -connect 0.0.0.0:25 \
  -starttls smtp \
  -CApath /etc/ssl/certs/ \
  2>/dev/null | openssl x509 -noout -dates
```

## Plain-Text Access

!!! warning

    Not recommended for purposes other than testing.

Add this to `docker-data/dms/config/dovecot.cf`:

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

1. Transfer the new certificates to `./docker-data/dms/config/ssl` (`/tmp/ssl` in the container)
2. You should provide `fullchain.key` and `privkey.pem`
3. Place the script in `./docker-data/dms/config/` (or `/tmp/docker-mailserver/` inside the container)
4. Make the script executable (`chmod +x tomav-renew-certs.sh`)
5. Run the script: `docker exec mailserver /tmp/docker-mailserver/tomav-renew-certs.sh`

If an error occurs the script will inform you. If not you will see both postfix and dovecot restart.

After the certificates have been loaded you can check the certificate:

```sh
openssl s_client \
  -servername mail.example.com \
  -connect 192.168.0.72:465 \
  2>/dev/null | openssl x509

# or

openssl s_client \
  -servername mail.example.com \
  -connect mail.example.com:465 \
  2>/dev/null | openssl x509
```

Or you can check how long the new certificate is valid with commands like:

```sh
export SITE_URL="mail.example.com"
export SITE_IP_URL="192.168.0.72" # can also use `mail.example.com`
export SITE_SSL_PORT="993" # imap port dovecot

##works: check if certificate will expire in two weeks 
#2 weeks is 1209600 seconds
#3 weeks is 1814400
#12 weeks is 7257600
#15 weeks is 9072000

certcheck_2weeks=`openssl s_client -connect ${SITE_IP_URL}:${SITE_SSL_PORT} \
  -servername ${SITE_URL} 2> /dev/null | openssl x509 -noout -checkend 1209600`

####################################
#notes: output could be either:
#Certificate will not expire
#Certificate will expire
####################
```

What does the script that imports the certificates do:

1. Check if there are new certs in the internal container folder: `/tmp/ssl`.
2. Check with the ssl cert fingerprint if they differ from the current certificates.
3. If so it will copy the certs to the right places.
4. And restart postfix and dovecot.

You can of course run the script by cron once a week or something. In that way you could automate cert renewal. If you do so it is probably wise to run an automated check on certificate expiry as well. Such a check could look something like this:

```sh
# This script is run inside docker-mailserver via 'docker exec ...', using the 'mail' command to send alerts.
## code below will alert if certificate expires in less than two weeks
## please adjust varables!
## make sure the 'mail -s' command works! Test!

export SITE_URL="mail.example.com"
export SITE_IP_URL="192.168.2.72" # can also use `mail.example.com`
export SITE_SSL_PORT="993" # imap port dovecot
# Below can be from a different domain; like your personal email, not handled by this docker-mailserver:
export ALERT_EMAIL_ADDR="external-account@gmail.com"

certcheck_2weeks=`openssl s_client -connect ${SITE_IP_URL}:${SITE_SSL_PORT} \
  -servername ${SITE_URL} 2> /dev/null | openssl x509 -noout -checkend 1209600`

####################################
#notes: output can be
#Certificate will not expire
#Certificate will expire
####################

#echo "certcheck 2 weeks gives $certcheck_2weeks"

##automated check you might run by cron or something
## does the certificate expire within two weeks?

if [ "$certcheck_2weeks" = "Certificate will not expire" ]; then
  echo "all is well, certwatch 2 weeks says $certcheck_2weeks"
  else
    echo "Cert seems to be expiring pretty soon, within two weeks: $certcheck_2weeks"
    echo "we will send an alert email and log as well"
    logger Certwatch: cert $SITE_URL will expire in two weeks
    echo "Certwatch: cert $SITE_URL will expire in two weeks" | mail -s "cert $SITE_URL expires in two weeks " $ALERT_EMAIL_ADDR 
fi
```

## Custom DH Parameters

By default `docker-mailserver` uses [`ffdhe4096`][ffdhe4096-src] from [IETF RFC 7919][ietf::rfc::ffdhe]. These are standardized pre-defined DH groups and the only available DH groups for TLS 1.3. It is [discouraged to generate your own DH parameters][dh-avoid-selfgenerated] as it is often less secure.

Despite this, if you must use non-standard DH parameters or you would like to swap `ffdhe4096` for a different group (eg `ffdhe2048`); Add your own PEM encoded DH params file via a volume to `/tmp/docker-mailserver/dhparams.pem`. This will replace DH params for both Dovecot and Postfix services during container startup.

[docs-optional-config]: ../advanced/optional-config.md

[github-file-compose]: https://github.com/docker-mailserver/docker-mailserver/blob/master/docker-compose.yml
[github-file::tls-readme]: https://github.com/docker-mailserver/docker-mailserver/blob/3b8059f2daca80d967635e04d8d81e9abb755a4d/test/test-files/ssl/example.test/README.md
[github-issue-1440]: https://github.com/docker-mailserver/docker-mailserver/issues/1440
[hanscees-renewcerts]: https://github.com/hanscees/dockerscripts/blob/master/scripts/tomav-renew-certs

[traefik::github]: https://github.com/containous/traefik
[ietf::rfc::acme]: https://datatracker.ietf.org/doc/html/rfc8555

[ietf::rfc::ffdhe]: https://datatracker.ietf.org/doc/html/rfc7919
[ffdhe4096-src]: https://github.com/internetstandards/dhe_groups
[dh-avoid-selfgenerated]: https://crypto.stackexchange.com/questions/29926/what-diffie-hellman-parameters-should-i-use
