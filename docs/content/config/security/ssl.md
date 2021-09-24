---
title: 'Security | TLS (aka SSL)'
---

There are multiple options to enable SSL (via [`SSL_TYPE`][docs-env::ssl-type]):

- Using [letsencrypt](#lets-encrypt-recommended) (recommended)
- Using [Caddy](#caddy)
- Using [Traefik](#traefik)
- Using [self-signed certificates](#self-signed-certificates-testing-only)
- Using [your own certificates](#custom-certificate-files)

After installation, you can test your setup with:

- [`checktls.com`](https://www.checktls.com/TestReceiver)
- [`testssl.sh`](https://github.com/drwetter/testssl.sh)

!!! warning "Exposure of DNS labels through Certificate Transparency"

    All public Certificate Authorities (CAs) are required to log certificates they issue publicly via [Certificate Transparency][certificate-transparency]. This helps to better establish trust.

    When using a public CA for certificates used in private networks, be aware that the associated DNS labels in the certificate are logged publicly and [easily searchable][ct-search]. These logs are _append only_, you **cannot** redact this information.

    You could use a [wildcard certificate][wildcard-cert]. This avoids accidentally leaking information to the internet, but keep in mind the [potential security risks][security::wildcard-cert] of wildcard certs.

## Let's Encrypt (Recommended)

To enable _Let's Encrypt_ for `docker-mailserver`, you have to:

1. Get your certificate using the _Let's Encrypt_ client [Certbot][certbot::github].
2. For your `docker-mailserver` container:

    1. Add the environment variable `SSL_TYPE=letsencrypt`.
    2. Mount [your local `letsencrypt` folder][certbot::certs-storage] as a volume to `/etc/letsencrypt`.

You don't have to do anything else. Enjoy!

!!! note

    `/etc/letsencrypt/live` stores provisioned certificates in individual folders named by their FQDN (_Fully Qualified Domain Name_). `docker-mailserver` looks for it's certificate folder via the `hostname` command. The FQDN inside the docker container is derived from the `--hostname` and `--domainname` options.

!!! example

    Add these additions to the `mailserver` service in your [`docker-compose.yml`][github-file-compose]:

    ```yaml
    services:
      mailserver:
        # For the FQDN 'mail.example.com':
        hostname: mail
        domainname: example.com
        environment:
          - SSL_TYPE=letsencrypt
        volumes:
          - /etc/letsencrypt:/etc/letsencrypt
    ```

### Example using Docker for _Let's Encrypt_

- Certbot provisions certificates to `/etc/letsencrypt`. Add a volume to store these, so that they can later be accessed by `docker-mailserver` container.
- You may also want to persist Certbot [logs][certbot::log-rotation], just in case you need to troubleshoot.

1. Getting a certificate is this simple! (_Referencing: [Certbot docker instructions][certbot::docker] and [`certonly --standalone` mode][certbot::standalone]_):

    ```sh
    # Change `mail.example.com` below to your own FQDN.
    # Requires access to port 80 from the internet, adjust your firewall if needed.
    docker run --rm -it \
      -v "${PWD}/docker-data/certbot/certs/:/etc/letsencrypt/" \
      -v "${PWD}/docker-data/certbot/logs/:/var/log/letsencrypt/" \
      -p 80:80 \
      certbot/certbot certonly --standalone -d mail.example.com
    ```

2. Add a volume for `docker-mailserver` that maps the _local `certbot/certs/` folder_ to the container path `/etc/letsencrypt/`.
3. The certificate setup is complete, but remember _it will expire_. Consider automating renewals.

!!! tip "Renewing Certificates"

    When running the above `certonly --standalone` snippet again, the existing certificate is renewed if it would expire within 30 days.

    Alternatively, Certbot can look at all the certificates it manages, and only renew those nearing their expiry via the [`renew` command][certbot::renew]:

    ```sh
    # This will need access to port 443 from the internet, adjust your firewall if needed.
    docker run --rm -it \
      -v "${PWD}/docker-data/certbot/certs/:/etc/letsencrypt/" \
      -v "${PWD}/docker-data/certbot/logs/:/var/log/letsencrypt/" \
      -p 80:80 \
      -p 443:443 \
      certbot/certbot renew
    ```

    This process can also be [automated via _cron_ or _systemd timers_][certbot::automated-renewal].

!!! note "Using a different ACME CA"

    Certbot does support [alternative certificate providers via the `--server`][certbot::custom-ca] option. In most cases you'll want to use the default _Let's Encrypt_.

### Example using `nginx-proxy` and `acme-companion` with Docker

If you are running a web server already, port 80 will be in use which Certbot requires. You could use the [Certbot `--webroot`][certbot::webroot] feature, but it is more common to leverage a _reverse proxy_ that manages the provisioning and renewal of certificates for your services automatically.

In the following example, we show how `docker-mailserver` can be run alongside the docker containers [`nginx-proxy`][nginx-proxy::github] and [`acme-companion`][acme-companion::github] (_Referencing: [`acme-companion` documentation][acme-companion::docs]_):

1. Start the _reverse proxy_ (`nginx-proxy`):

    ```sh
    docker run --detach \
      --name nginx-proxy \
      --restart always \
      --publish 80:80 \
      --publish 443:443 \
      --volume "${PWD}/docker-data/nginx-proxy/html/:/usr/share/nginx/html/" \
      --volume "${PWD}/docker-data/nginx-proxy/vhost.d/:/etc/nginx/vhost.d/" \
      --volume "${PWD}/docker-data/acme-companion/certs/:/etc/nginx/certs/:ro" \
      --volume '/var/run/docker.sock:/tmp/docker.sock:ro' \
      nginxproxy/nginx-proxy
    ```

2. Then start the _certificate provisioner_ (`acme-companion`), which will provide certificates to `nginx-proxy`:

    ```sh
    # Inherit `nginx-proxy` volumes via `--volumes-from`, but make `certs/` writeable:
    docker run --detach \
      --name nginx-proxy-acme \
      --restart always \
      --volumes-from nginx-proxy \
      --volume "${PWD}/docker-data/acme-companion/certs/:/etc/nginx/certs/:rw" \
      --volume "${PWD}/docker-data/acme-companion/acme-state/:/etc/acme.sh/" \
      --volume '/var/run/docker.sock:/var/run/docker.sock:ro' \
      --env 'DEFAULT_EMAIL=admin@example.com' \
      nginxproxy/acme-companion
    ```

3. Start the rest of your web server containers as usual.

4. Start a _dummy container_ to provision certificatess for your FQDN (eg: `mail.example.com`). `acme-companion` will detect the container and generate a _Let's Encrypt_ certificate for your domain, which can be used by `docker-mailserver`:

    ```sh
    docker run --detach \
      --name webmail \
      --env 'VIRTUAL_HOST=mail.example.com' \
      --env 'LETSENCRYPT_HOST=mail.example.com' \
      --env 'LETSENCRYPT_EMAIL=admin@example.com' \
      nginx
    ```

    You may want to add `--env LETSENCRYPT_TEST=true` to the above while testing, to avoid the _Let's Encrypt_ certificate generation rate limits.

5. Make sure your mount path to the `letsencrypt` certificates directory is correct. Edit your `docker-compose.yml` for the `mailserver` service to have volumes added like below:

    ```yaml
    volumes:
      - ./docker-data/dms/mail-data/:/var/mail/
      - ./docker-data/dms/mail-state/:/var/mail-state/
      - ./docker-data/dms/config/:/tmp/docker-mailserver/
      - ./docker-data/acme-companion/certs/:/etc/letsencrypt/live/:ro
    ```

6. Then from the `docker-compose.yml` project directory, run: `docker-compose up -d mailserver`.

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
# Note: If you have an existing setup that was working pre docker-mailserver v10.2,
# '/tmp/dms/custom-certs' below has replaced the previous '/tmp/ssl' container path.
volumes:
  - /usr/syno/etc/certificate/_archive/<your-folder>/:/tmp/dms/custom-certs/
environment:
  - SSL_TYPE=manual
  - SSL_CERT_PATH=/tmp/dms/custom-certs/fullchain.pem
  - SSL_KEY_PATH=/tmp/dms/custom-certs/privkey.pem
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

If you'd rather not install the CLI tool locally to run the `step` commands above; you can save the script above to a file such as `generate-certs.sh` (_and make it executable `chmod +x generate-certs.sh`_) in a directory that you want the certs to be placed (eg: `docker-data/dms/custom-certs/`), then use docker to run that script in a container:

```sh
# '--user' is to keep ownership of the files written to
# the local volume to use your systems User and Group ID values.
docker run --rm -it \
  --user "$(id -u):$(id -g)" \
  --volume "${PWD}/docker-data/dms/custom-certs/:/tmp/step-ca/" \
  --workdir "/tmp/step-ca/" \
  --entrypoint "/tmp/step-ca/generate-certs.sh" \
  smallstep/step-ca
```

## Bring Your Own Certificates

You can also provide your own certificate files. Add these entries to your `docker-compose.yml`:

```yaml
volumes:
  - ./docker-data/dms/custom-certs/:/tmp/dms/custom-certs/:ro
environment:
  - SSL_TYPE=manual
  # Values should match the file paths inside the container:
  - SSL_CERT_PATH=/tmp/dms/custom-certs/public.crt
  - SSL_KEY_PATH=/tmp/dms/custom-certs/private.key
```

This will mount the path where your certificate files reside locally into the _read-only_ container folder: `/tmp/dms/custom-certs`.

The local and internal paths may be whatever you prefer, so long as both `SSL_CERT_PATH` and `SSL_KEY_PATH` point to the correct internal file paths. The certificate files may also be named to your preference, but should be PEM encoded.

`SSL_ALT_CERT_PATH` and `SSL_ALT_KEY_PATH` are additional ENV vars to support a 2nd certificate as a fallback. Commonly known as hybrid or dual certificate support. This is useful for using a modern ECDSA as your primary certificate, and RSA as your fallback for older connections. They work in the same manner as the non-`ALT` versions.

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

!!! attention "Only compatible with `docker-mailserver` releases < `v10.2`"

    The script expects `/etc/postfix/ssl/cert` and `/etc/postfix/ssl/key` files to be configured paths for both Postfix and Dovecot to use.

    Since the `docker-mailserver` 10.2 release, certificate files have moved to `/etc/dms/tls/`, and the file name may differ depending on provisioning method.

    This third-party script also has `fullchain.pem` and `privkey.pem` as hard-coded, thus is incompatible with other filenames.

    Additionally it has never supported handling `ALT` fallback certificates (for supporting dual/hybrid, RSA + ECDSA).

The steps to follow are these:

1. Transfer the new certificates to `./docker-data/dms/custom-certs/` (volume mounted to: `/tmp/ssl/`)
2. You should provide `fullchain.key` and `privkey.pem`
3. Place the script in `./docker-data/dms/config/` (volume mounted to: `/tmp/docker-mailserver/`)
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

[docs-env::ssl-type]: ../environment.md#ssl_type
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

[certificate-transparency]: https://certificate.transparency.dev/
[ct-search]: https://crt.sh/
[wildcard-cert]: https://en.wikipedia.org/wiki/Wildcard_certificate#Examples
[security::wildcard-cert]: https://gist.github.com/joepie91/7e5cad8c0726fd6a5e90360a754fc568

[certbot::github]: https://github.com/certbot/certbot
[certbot::certs-storage]: https://certbot.eff.org/docs/using.html#where-are-my-certificates
[certbot::log-rotation]: https://certbot.eff.org/docs/using.html#log-rotation
[certbot::docker]: https://certbot.eff.org/docs/install.html#running-with-docker
[certbot::standalone]: https://certbot.eff.org/docs/using.html#standalone
[certbot::renew]: https://certbot.eff.org/docs/using.html#renewing-certificates
[certbot::automated-renewal]: https://certbot.eff.org/docs/using.html#automated-renewals
[certbot::custom-ca]: https://certbot.eff.org/docs/using.htmlchanging-the-acme-server
[certbot::webroot]: https://certbot.eff.org/docs/using.html#webroot

[nginx-proxy::github]: https://github.com/nginx-proxy/nginx-proxy
[acme-companion::github]: https://github.com/nginx-proxy/acme-companion
[acme-companion::docs]: https://github.com/nginx-proxy/acme-companion/blob/main/docs
