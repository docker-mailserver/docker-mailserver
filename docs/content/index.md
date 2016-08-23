## Usage

#### Get latest image
 
    docker pull tvial/docker-mailserver:latest

#### Create a `docker-compose.yml`

Adapt this file with your FQDN. Install [docker-compose](https://docs.docker.com/compose/) in the version `1.6` or higher.

    version: '2'

    services:
      mail:
        image: tvial/docker-mailserver:latest
        # build: .
        hostname: mail
        domainname: domain.com
        container_name: mail
        ports:
        - "25:25"
        - "143:143"
        - "587:587"
        - "993:993"
        volumes:
        - maildata:/var/mail
        - ./config/:/tmp/docker-mailserver/

    volumes:
      maildata:
        driver: local

#### Create your mail accounts

Don't forget to adapt MAIL_USER and MAIL_PASS to your needs

    mkdir -p config
    touch config/postfix-accounts.cf
    docker run --rm \
      -e MAIL_USER=user1@domain.tld \
      -e MAIL_PASS=mypassword \
      -ti tvial/docker-mailserver:latest \
      /bin/sh -c 'echo "$MAIL_USER|$(doveadm pw -s SHA512-CRYPT -u $MAIL_USER -p $MAIL_PASS)"' >> config/postfix-accounts.cf

#### Generate DKIM keys 

    docker run --rm \
      -v "$(pwd)/config":/tmp/docker-mailserver \
      -ti tvial/docker-mailserver:latest generate-dkim-config

Now the keys are generated, you can configure your DNS server by just pasting the content of `config/opendkim/keys/domain.tld/mail.txt` in your `domain.tld.hosts` zone.

#### Start the container

    docker-compose up -d mail

You're done!

## Environment variables

Please check [how the container starts](https://github.com/tomav/docker-mailserver/blob/master/target/start-mailserver.sh) to understand what's expected.

Value in **bold** is the default value.

##### ENABLE_POP3

  - **empty** => POP3 service disabled
  - 1 => Enables POP3 service

##### ENABLE_FAIL2BAN

  - **empty** => fail2ban service disabled
  - 1 => Enables fail2ban service

If you enable Fail2Ban, don't forget to add the following lines to your `docker-compose.yml`:

    cap_add:
      - NET_ADMIN

Otherwise, `iptables` won't be able to ban IPs.

##### ENABLE_MANAGESIEVE

  - **empty** => Managesieve service disabled
  - 1 => Enables Managesieve on port 4190

##### SA_TAG

  - **2.0** => add spam info headers if at, or above that level

##### SA_TAG2

  - **6.31** => add 'spam detected' headers at that level

##### SA_KILL

  - **6.31** => triggers spam evasive actions

##### SASL_PASSWD

  - **empty** => No sasl_passwd will be created
  - string => `/etc/postfix/sasl_passwd` will be created with the string as password

##### SMTP_ONLY

  - **empty** => all daemons start
  - 1 => only launch postfix smtp

##### SSL_TYPE

  - **empty** => SSL disabled
  - letsencrypt => Enables Let's Encrypt certificates
  - custom => Enables custom certificates
  - self-signed => Enables self-signed certificates

Please read [the SSL page in the wiki](https://github.com/tomav/docker-mailserver/wiki/Configure-SSL) for more information.

##### PERMIT_DOCKER

Set different options for mynetworks option (can be overwrite in postfix-main.cf)
  - **empty** => localhost only
  - host => Add docker host (ipv4 only)
  - network => Add all docker containers (ipv4 only)