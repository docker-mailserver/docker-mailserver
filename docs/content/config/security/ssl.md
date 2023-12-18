---
title: 'Security | TLS (aka SSL)'
---

There are multiple options to enable SSL (via [`SSL_TYPE`][docs-env::ssl-type]):

- Using [letsencrypt](#lets-encrypt-recommended) (recommended)
- Using [Caddy](#caddy)
- Using [Traefik](#traefik-v2)
- Using [self-signed certificates](#self-signed-certificates)
- Using [your own certificates](#bring-your-own-certificates)

After installation, you can test your setup with:

- [`checktls.com`](https://www.checktls.com/TestReceiver)
- [`testssl.sh`](https://github.com/drwetter/testssl.sh)

!!! warning "Exposure of DNS labels through Certificate Transparency"

    All public Certificate Authorities (CAs) are required to log certificates they issue publicly via [Certificate Transparency][certificate-transparency]. This helps to better establish trust.

    When using a public CA for certificates used in private networks, be aware that the associated DNS labels in the certificate are logged publicly and [easily searchable][ct-search]. These logs are _append only_, you **cannot** redact this information.

    You could use a [wildcard certificate][wildcard-cert]. This avoids accidentally leaking information to the internet, but keep in mind the [potential security risks][security::wildcard-cert] of wildcard certs.

## The FQDN

An [FQDN](https://en.wikipedia.org/wiki/Fully_qualified_domain_name) (_Fully Qualified Domain Name_) such as `mail.example.com` is required for DMS to function correctly, especially for looking up the correct SSL certificate to use.

- `mail.example.com` will still use `user@example.com` as the mail address. You do not need a bare domain for that.
- We usually discourage assigning a bare domain (_When your DNS MX record does not point to a subdomain_) to represent DMS. However, an FQDN of [just `example.com` is also supported][docs-faq-baredomain].
- Internally, `hostname -f` will be used to retrieve the FQDN as configured in the below examples.
- Wildcard certificates (eg: `*.example.com`) are supported for `SSL_TYPE=letsencrypt`. Your configured FQDN below may be `mail.example.com`, and your wildcard certificate provisioned to `/etc/letsencrypt/live/example.com` which will be checked as a fallback FQDN by DMS.

!!! example "Setting the hostname correctly"

    Change `mail.example.com` below to your own FQDN.

    ```sh
    # CLI:
    docker run --hostname mail.example.com
    ```

    or

    ```yml
    # compose.yaml
    services:
      mailserver:
        hostname: mail.example.com
    ```

## Provisioning methods

### Let's Encrypt (Recommended)

To enable _Let's Encrypt_ for DMS, you have to:

1. Get your certificate using the _Let's Encrypt_ client [Certbot][certbot::github].
2. For your DMS container:

    - Add the environment variable `SSL_TYPE=letsencrypt`.
    - Mount [your local `letsencrypt` folder][certbot::certs-storage] as a volume to `/etc/letsencrypt`.

You don't have to do anything else. Enjoy!

!!! note

    `/etc/letsencrypt/live` stores provisioned certificates in individual folders named by their FQDN.

    Make sure that the entire folder is mounted to DMS as there are typically symlinks from `/etc/letsencrypt/live/mail.example.com` to `/etc/letsencrypt/archive`.

!!! example

    Add these additions to the `mailserver` service in your [`compose.yaml`][github-file-compose]:

    ```yaml
    services:
      mailserver:
        hostname: mail.example.com
        environment:
          - SSL_TYPE=letsencrypt
        volumes:
          - /etc/letsencrypt:/etc/letsencrypt
    ```

#### Example using Docker for _Let's Encrypt_ { data-toc-label='Certbot with Docker' }

Certbot provisions certificates to `/etc/letsencrypt`. Add a volume to store these, so that they can later be accessed by DMS container. You may also want to persist Certbot [logs][certbot::log-rotation], just in case you need to troubleshoot.

1. Getting a certificate is this simple! (_Referencing: [Certbot docker instructions][certbot::docker] and [`certonly --standalone` mode][certbot::standalone]_):

    ```sh
    # Requires access to port 80 from the internet, adjust your firewall if needed.
    docker run --rm -it \
      -v "${PWD}/docker-data/certbot/certs/:/etc/letsencrypt/" \
      -v "${PWD}/docker-data/certbot/logs/:/var/log/letsencrypt/" \
      -p 80:80 \
      certbot/certbot certonly --standalone -d mail.example.com
    ```

2. Add a volume for DMS that maps the _local `certbot/certs/` folder_ to the container path `/etc/letsencrypt/`.

    !!! example

        Add these additions to the `mailserver` service in your [`compose.yaml`][github-file-compose]:

        ```yaml
        services:
          mailserver:
            hostname: mail.example.com
            environment:
              - SSL_TYPE=letsencrypt
            volumes:
              - ./docker-data/certbot/certs/:/etc/letsencrypt
        ```

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

#### Example using `certbot-dns-cloudflare` with Docker { data-toc-label='certbot-dns-cloudflare with Docker' }

If you are unable get a certificate via the `HTTP-01` (port 80) or `TLS-ALPN-01` (port 443) [challenge types](https://letsencrypt.org/docs/challenge-types/), the `DNS-01` challenge can be useful (_this challenge can additionally issue wildcard certificates_). This guide shows how to use the `DNS-01` challenge with Cloudflare as your DNS provider.

Obtain a Cloudflare API token:

1. Login into your Cloudflare dashboard.
2. Navigate to the [API Tokens page](https://dash.cloudflare.com/profile/api-tokens).
3. Click "Create Token", and choose the `Edit zone DNS` template (_Certbot [requires the `ZONE:DNS:Edit` permission](https://certbot-dns-cloudflare.readthedocs.io/en/stable/#credentials)_).

    !!! warning "Only include the necessary Zone resource configuration"

        Be sure to configure "Zone Resources" section on this page to `Include -> Specific zone -> <your zone here>`.

        This restricts the API token to only this zone (domain) which is an important security measure.

4. Store the _API token_ you received in a file `cloudflare.ini` with content:

    ```dosini
    dns_cloudflare_api_token = YOUR_CLOUDFLARE_TOKEN_HERE
    ```

    - As this is sensitive data, you should restrict access to it with `chmod 600` and `chown 0:0`.
    - Store the file in a folder if you like, such as `docker-data/certbot/secrets/`.

5. Your `compose.yaml` should include the following:

    ```yaml
    services:
      mailserver:
        environments:
          # Set SSL certificate type.
          - SSL_TYPE=letsencrypt
        volumes:
          # Mount the cert folder generated by Certbot:
          - ./docker-data/certbot/certs/:/etc/letsencrypt/:ro

      certbot-cloudflare:
        image: certbot/dns-cloudflare:latest
        command: certonly --dns-cloudflare --dns-cloudflare-credentials /run/secrets/cloudflare-api-token -d mail.example.com
        volumes:
          - ./docker-data/certbot/certs/:/etc/letsencrypt/
          - ./docker-data/certbot/logs/:/var/log/letsencrypt/
        secrets:
          - cloudflare-api-token

    # Docs: https://docs.docker.com/engine/swarm/secrets/#use-secrets-in-compose
    # WARNING: In compose configs without swarm, the long syntax options have no effect,
    # Ensure that you properly `chmod 600` and `chown 0:0` the file on disk. Effectively treated as a bind mount.
    secrets:
      cloudflare-api-token:
        file: ./docker-data/certbot/secrets/cloudflare.ini
    ```

    Alternative using the `docker run` command (`secrets` feature is not available):

      ```sh
      docker run \
        --volume "${PWD}/docker-data/certbot/certs/:/etc/letsencrypt/" \
        --volume "${PWD}/docker-data/certbot/logs/:/var/log/letsencrypt/" \
        --volume "${PWD}/docker-data/certbot/secrets/:/tmp/secrets/certbot/"
        certbot/dns-cloudflare \
        certonly --dns-cloudflare --dns-cloudflare-credentials /tmp/secrets/certbot/cloudflare.ini -d mail.example.com
      ```

6. Run the service to provision a certificate:

    ```sh
    docker compose run certbot-cloudflare
    ```

7. You should see the following log output:

    ```log
    Saving debug log to /var/log/letsencrypt/letsencrypt. log | Requesting a certificate for mail.example.com
    Waiting 10 seconds for DNS changes to propagate
    Successfully received certificate.
    Certificate is saved at: /etc/letsencrypt/live/mail.example.com/fullchain.pem
    Key is saved at: /etc/letsencrypt/live/mail.example.com/privkey.pem
    This certificate expires on YYYY-MM-DD.
    These files will be updated when the certificate renews.
    NEXT STEPS:
    - The certificate will need to be renewed before it expires. Certbot can automatically renew the certificate in background, but you may need to take steps to enable that functionality. See https://certbot.org/renewal instructions.
    ```

After completing the steps above, your certificate should be ready to use.

??? tip "Renewing a certificate (Optional)"

    We've only demonstrated how to provision a certificate, but it will expire in 90 days and need to be renewed before then.

    In the following example, add a new service (`certbot-cloudflare-renew`) into `compose.yaml` that will handle certificate renewals:

    ```yml
    services:
      certbot-cloudflare-renew:
        image: certbot/dns-cloudflare:latest
        command: renew --dns-cloudflare --dns-cloudflare-credentials /run/secrets/cloudflare-api-token
        volumes:
          - ./docker-data/certbot/certs/:/etc/letsencrtypt/
          - ./docker-data/certbot/logs/:/var/log/letsencrypt/
        secrets:
          - cloudflare-api-token

    ```

    You can manually run this service to renew the cert within 90 days:

    ```sh
    docker compose run certbot-cloudflare-renew
    ```

    You should see the following output
    (The following log was generated with `--dry-run` options)

    ```log
    Saving debug log to /var/log/letsencrypt/letsencrypt.log

    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Processing /etc/letsencrypt/renewal/mail.example.com.conf
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Account registered.
    Simulating renewal of an existing certificate for mail.example.com
    Waiting 10 seconds for DNS changes to propagate

    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    Congratulations, all simulated renewals succeeded:
      /etc/letsencrypt/live/mail.example.com/fullchain.pem (success)
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    ```

    It is recommended to automate this renewal via a task scheduler like a _systemd timer_ or in `crontab`
    (`crontab` example: Checks every day if the certificate should be renewed)

    ```sh
    0 0 * * * docker compose -f PATH_TO_YOUR_DOCKER_COMPOSE_YML up certbot-cloudflare-renew
    ```

#### Example using `nginx-proxy` and `acme-companion` with Docker { data-toc-label='nginx-proxy with Docker' }

If you are running a web server already, port 80 will be in use which Certbot requires. You could use the [Certbot `--webroot`][certbot::webroot] feature, but it is more common to leverage a _reverse proxy_ that manages the provisioning and renewal of certificates for your services automatically.

In the following example, we show how DMS can be run alongside the docker containers [`nginx-proxy`][nginx-proxy::github] and [`acme-companion`][acme-companion::github] (_Referencing: [`acme-companion` documentation][acme-companion::docs]_):

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

4. Start a _dummy container_ to provision certificates for your FQDN (eg: `mail.example.com`). `acme-companion` will detect the container and generate a _Let's Encrypt_ certificate for your domain, which can be used by DMS:

    ```sh
    docker run --detach \
      --name webmail \
      --env 'VIRTUAL_HOST=mail.example.com' \
      --env 'LETSENCRYPT_HOST=mail.example.com' \
      --env 'LETSENCRYPT_EMAIL=admin@example.com' \
      nginx
    ```

    You may want to add `--env LETSENCRYPT_TEST=true` to the above while testing, to avoid the _Let's Encrypt_ certificate generation rate limits.

5. Make sure your mount path to the `letsencrypt` certificates directory is correct. Edit your `compose.yaml` for the `mailserver` service to have volumes added like below:

    ```yaml
    volumes:
      - ./docker-data/dms/mail-data/:/var/mail/
      - ./docker-data/dms/mail-state/:/var/mail-state/
      - ./docker-data/dms/config/:/tmp/docker-mailserver/
      - ./docker-data/acme-companion/certs/:/etc/letsencrypt/live/:ro
    ```

6. Then from the `compose.yaml` project directory, run: `docker compose up -d mailserver`.

#### Example using `nginx-proxy` and `acme-companion` with `docker-compose` { data-toc-label='nginx-proxy with docker-compose' }

The following example is the [basic setup][acme-companion::basic-setup] you need for using `nginx-proxy` and `acme-companion` with DMS (_Referencing: [`acme-companion` documentation][acme-companion::docs]_):

???+ example "Example: `compose.yaml`"

    You should have an existing `compose.yaml` with a `mailserver` service. Below are the modifications to add for integrating with `nginx-proxy` and `acme-companion` services:

    ```yaml
    services:
      # Add the following `environment` and `volumes` to your existing `mailserver` service:
      mailserver:
        environment:
          # SSL_TYPE:         Uses the `letsencrypt` method to find mounted certificates.
          # VIRTUAL_HOST:     The FQDN that `nginx-proxy` will configure itself to handle for HTTP[S] connections.
          # LETSENCRYPT_HOST: The FQDN for a certificate that `acme-companion` will provision and renew.
          - SSL_TYPE=letsencrypt
          - VIRTUAL_HOST=mail.example.com
          - LETSENCRYPT_HOST=mail.example.com
        volumes:
          - ./docker-data/acme-companion/certs/:/etc/letsencrypt/live/:ro

      # If you don't yet have your own `nginx-proxy` and `acme-companion` setup,
      # here is an example you can use:
      reverse-proxy:
        image: nginxproxy/nginx-proxy
        container_name: nginx-proxy
        restart: always
        ports:
          # Port  80: Required for HTTP-01 challenges to `acme-companion`.
          # Port 443: Only required for containers that need access over HTTPS. TLS-ALPN-01 challenge not supported.
          - "80:80"
          - "443:443"
        volumes:
          # `certs/`:      Managed by the `acme-companion` container (_read-only_).
          # `docker.sock`: Required to interact with containers via the Docker API.
          - ./docker-data/nginx-proxy/html/:/usr/share/nginx/html/
          - ./docker-data/nginx-proxy/vhost.d/:/etc/nginx/vhost.d/
          - ./docker-data/acme-companion/certs/:/etc/nginx/certs/:ro
          - /var/run/docker.sock:/tmp/docker.sock:ro

      acme-companion:
        image: nginxproxy/acme-companion
        container_name: nginx-proxy-acme
        restart: always
        environment:
          # When `volumes_from: [nginx-proxy]` is not supported,
          # reference the _reverse-proxy_ `container_name` here:
          - NGINX_PROXY_CONTAINER=nginx-proxy
        volumes:
          # `html/`:       Write ACME HTTP-01 challenge files that `nginx-proxy` will serve.
          # `vhost.d/`:    To enable web access via `nginx-proxy` to HTTP-01 challenge files.
          # `certs/`:      To store certificates and private keys.
          # `acme-state/`: To persist config and state for the ACME provisioner (`acme.sh`).
          # `docker.sock`: Required to interact with containers via the Docker API.
          - ./docker-data/nginx-proxy/html/:/usr/share/nginx/html/
          - ./docker-data/nginx-proxy/vhost.d/:/etc/nginx/vhost.d/
          - ./docker-data/acme-companion/certs/:/etc/nginx/certs/:rw
          - ./docker-data/acme-companion/acme-state/:/etc/acme.sh/
          - /var/run/docker.sock:/var/run/docker.sock:ro
    ```

!!! tip "Optional ENV vars worth knowing about"

    [Per container ENV][acme-companion::env-container] that `acme-companion` will detect to override default provisioning settings:

    - `LETSENCRYPT_TEST=true`: _Recommended during initial setup_. Otherwise the default production endpoint has a [rate limit of 5 duplicate certificates per week][letsencrypt::limits]. Overrides `ACME_CA_URI` to use the _Let's Encrypt_ staging endpoint.
    - `LETSENCRYPT_EMAIL`: For when you don't use `DEFAULT_EMAIL` on `acme-companion`, or want to assign a different email contact for this container.
    - `LETSENCRYPT_KEYSIZE`: Allows you to configure the type (RSA or ECDSA) and size of the private key for your certificate. Default is RSA 4096.
    - `LETSENCRYPT_RESTART_CONTAINER=true`: When the certificate is renewed, the entire container will be restarted to ensure the new certificate is used.

    [`acme-companion` ENV for default settings][acme-companion::env-config] that apply to all containers using `LETSENCRYPT_HOST`:

    - `DEFAULT_EMAIL`: An email address that the CA (_eg: Let's Encrypt_) can contact you about expiring certificates, failed renewals, or for account recovery. You may want to use an email address not handled by your mail server to ensure deliverability in the event your mail server breaks.
    - `CERTS_UPDATE_INTERVAL`: If you need to adjust the frequency to check for renewals. 3600 seconds (1 hour) by default.
    - `DEBUG=1`: Should be helpful when [troubleshooting provisioning issues][acme-companion::troubleshooting] from `acme-companion` logs.
    - `ACME_CA_URI`: Useful in combination with `CA_BUNDLE` to use a private CA. To change the default _Let's Encrypt_ endpoint to the staging endpoint, use `https://acme-staging-v02.api.letsencrypt.org/directory`.
    - `CA_BUNDLE`: If you want to use a private CA instead of _Let's Encrypt_.

!!! tip "Alternative to required ENV on `mailserver` service"

    While you will still need both `nginx-proxy` and `acme-companion` containers, you can manage certificates without adding ENV vars to containers. Instead the ENV is moved into a file and uses the `acme-companion` feature [Standalone certificates][acme-companion::standalone].

    This requires adding another shared volume between `nginx-proxy` and `acme-companion`:

    ```yaml
    services:
      reverse-proxy:
        volumes:
          - ./docker-data/nginx-proxy/conf.d/:/etc/nginx/conf.d/

      acme-companion:
        volumes:
          - ./docker-data/nginx-proxy/conf.d/:/etc/nginx/conf.d/
          - ./docker-data/acme-companion/standalone.sh:/app/letsencrypt_user_data:ro
    ```

    `acme-companion` mounts a shell script (`standalone.sh`), which defines variables to customize certificate provisioning:

    ```sh
    # A list IDs for certificates to provision:
    LETSENCRYPT_STANDALONE_CERTS=('mail')

    # Each ID inserts itself into the standard `acme-companion` supported container ENV vars below.
    # The LETSENCRYPT_<ID>_HOST var is a list of FQDNs to provision a certificate for as the SAN field:
    LETSENCRYPT_mail_HOST=('mail.example.com')

    # Optional variables:
    LETSENCRYPT_mail_TEST=true
    LETSENCRYPT_mail_EMAIL='admin@example.com'
    # RSA-4096 => `4096`, ECDSA-256 => `ec-256`:
    LETSENCRYPT_mail_KEYSIZE=4096
    ```

    Unlike with the equivalent ENV for containers, [changes to this file will **not** be detected automatically][acme-companion::standalone-changes]. You would need to wait until the next renewal check by `acme-companion` (_every hour by default_), restart `acme-companion`, or [manually invoke the _service loop_][acme-companion::service-loop]:

    `#!bash docker exec nginx-proxy-acme /app/signal_le_service`

#### Example using _Let's Encrypt_ Certificates with a _Synology NAS_ { data-toc-label='Synology NAS' }

Version 6.2 and later of the Synology NAS DSM OS now come with an interface to generate and renew letencrypt certificates. Navigation into your DSM control panel and go to Security, then click on the tab Certificate to generate and manage letsencrypt certificates.

Amongst other things, you can use these to secure your mail server. DSM locates the generated certificates in a folder below `/usr/syno/etc/certificate/_archive/`.

Navigate to that folder and note the 6 character random folder name of the certificate you'd like to use. Then, add the following to your `compose.yaml` declaration file:

```yaml
volumes:
  - /usr/syno/etc/certificate/_archive/<your-folder>/:/tmp/dms/custom-certs/
environment:
  - SSL_TYPE=manual
  - SSL_CERT_PATH=/tmp/dms/custom-certs/fullchain.pem
  - SSL_KEY_PATH=/tmp/dms/custom-certs/privkey.pem
```

DSM-generated letsencrypt certificates get auto-renewed every three months.

### Caddy

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

??? example "Caddy v2 JSON example snippet"

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

The generated certificates can then be mounted:

```yaml
volumes:
  - ${CADDY_DATA_DIR}/certificates/acme-v02.api.letsencrypt.org-directory/mail.example.com/mail.example.com.crt:/etc/letsencrypt/live/mail.example.com/fullchain.pem
  - ${CADDY_DATA_DIR}/certificates/acme-v02.api.letsencrypt.org-directory/mail.example.com/mail.example.com.key:/etc/letsencrypt/live/mail.example.com/privkey.pem
```

### Traefik v2

[Traefik][traefik::github] is an open-source application proxy using the [ACME protocol][ietf::rfc::acme]. [Traefik][traefik::github] can request certificates for domains and subdomains, and it will take care of renewals, challenge negotiations, etc. We strongly recommend to use [Traefik][traefik::github]'s major version 2.

[Traefik][traefik::github]'s storage format is natively supported if the `acme.json` store is mounted into the container at `/etc/letsencrypt/acme.json`. The file is also monitored for changes and will trigger a reload of the mail services (Postfix and Dovecot).

Wildcard certificates are supported. If your FQDN is `mail.example.com` and your wildcard certificate is `*.example.com`, add the ENV: `#!bash SSL_DOMAIN=example.com`.

DMS will select it's certificate from `acme.json` checking these ENV for a matching FQDN (_in order of priority_):

1. `#!bash ${SSL_DOMAIN}`
2. `#!bash ${HOSTNAME}`
3. `#!bash ${DOMAINNAME}`

This setup only comes with one caveat: The domain has to be configured on another service for [Traefik][traefik::github] to actually request it from _Let's Encrypt_, i.e. [Traefik][traefik::github] will not issue a certificate without a service / router demanding it.

???+ example "Example Code"
    Here is an example setup for [`docker-compose`](https://docs.docker.com/compose/):

    ```yaml
    services:
      mailserver:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        container_name: mailserver
        hostname: mail.example.com
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

### Self-Signed Certificates

!!! warning

    Use self-signed certificates only for testing purposes!

This feature requires you to provide the following files into your [`docker-data/dms/config/ssl/` directory][docs-optional-config] (_internal location: `/tmp/docker-mailserver/ssl/`_):

- `<FQDN>-key.pem`
- `<FQDN>-cert.pem`
- `demoCA/cacert.pem`

Where `<FQDN>` is the FQDN you've configured for your DMS container.

Add `SSL_TYPE=self-signed` to your DMS environment variables. Postfix and Dovecot will be configured to use the provided certificate (_`.pem` files above_) during container startup.

#### Generating a self-signed certificate

One way to generate self-signed certificates is with [Smallstep's `step` CLI](https://smallstep.com/docs/step-cli). This is exactly what [DMS does for creating test certificates][github-file::tls-readme].

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

### Bring Your Own Certificates

You can also provide your own certificate files. Add these entries to your `compose.yaml`:

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

    You may have to restart DMS once the certificates change.

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

This is a community contributed script, and in most cases you will have better support via our _Change Detection_ service (_automatic for `SSL_TYPE` of `manual` and `letsencrypt`_) - Unless you're using LDAP which disables the service.

!!! warning "Script Compatibility"

    - Relies on private filepaths `/etc/dms/tls/cert` and `/etc/dms/tls/key` intended for internal use only.
    - Only supports hard-coded `fullchain.key` + `privkey.pem` as your mounted file names. That may not align with your provisioning method.
    - No support for `ALT` fallback certificates (_for supporting dual/hybrid, RSA + ECDSA_).

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
## please adjust variables!
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

By default DMS uses [`ffdhe4096`][ffdhe4096-src] from [IETF RFC 7919][ietf::rfc::ffdhe]. These are standardized pre-defined DH groups and the only available DH groups for TLS 1.3. It is [discouraged to generate your own DH parameters][dh-avoid-selfgenerated] as it is often less secure.

Despite this, if you must use non-standard DH parameters or you would like to swap `ffdhe4096` for a different group (eg `ffdhe2048`); Add your own PEM encoded DH params file via a volume to `/tmp/docker-mailserver/dhparams.pem`. This will replace DH params for both Dovecot and Postfix services during container startup.

[docs-env::ssl-type]: ../environment.md#ssl_type
[docs-optional-config]: ../advanced/optional-config.md
[docs-faq-baredomain]: ../../faq.md#can-i-use-a-nakedbare-domain-ie-no-hostname

[github-file-compose]: https://github.com/docker-mailserver/docker-mailserver/blob/master/compose.yaml
[github-file::tls-readme]: https://github.com/docker-mailserver/docker-mailserver/blob/3b8059f2daca80d967635e04d8d81e9abb755a4d/test/test-files/ssl/example.test/README.md
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
[letsencrypt::limits]: https://letsencrypt.org/docs/rate-limits/

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
[acme-companion::basic-setup]: https://github.com/nginx-proxy/acme-companion#basic-usage-with-the-nginx-proxy-container
[acme-companion::env-container]: https://github.com/nginx-proxy/acme-companion/blob/main/docs/Let's-Encrypt-and-ACME.md
[acme-companion::env-config]: https://github.com/nginx-proxy/acme-companion/blob/main/docs/Container-configuration.md
[acme-companion::troubleshooting]: https://github.com/nginx-proxy/acme-companion/blob/main/docs/Invalid-authorizations.md
[acme-companion::standalone]: https://github.com/nginx-proxy/acme-companion/blob/main/docs/Standalone-certificates.md
[acme-companion::standalone-changes]: https://github.com/nginx-proxy/acme-companion/blob/main/docs/Standalone-certificates.md#picking-up-changes-to-letsencrypt_user_data
[acme-companion::service-loop]: https://github.com/nginx-proxy/acme-companion/blob/main/docs/Container-utilities.md
