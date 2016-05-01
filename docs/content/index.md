## Usage

#### Get v2 image
 
    docker pull tvial/docker-mailserver:v2

#### Create a `docker-compose.yml`

Adapt this file with your FQDN.

    version: '2'

    services:
      mail:
        image: tvial/docker-mailserver:v2
        # build: .
        hostname: mail
        domainname: domain.com
        container_name: mail
        volumes:
        - maildata:/var/mail
        ports:
        - "25:25"
        - "143:143"
        - "587:587"
        - "993:993"
        volumes:
        - ./config/:/tmp/docker-mailserver/

    volumes:
      maildata:
        driver: local

#### Create your mail accounts

Don't forget to adapt MAIL_USER and MAIL_PASS to your needs

    mkdir -p config
    docker run --rm \
      -e MAIL_USER=user1@domain.tld \
      -e MAIL_PASS=mypassword \
      -ti tvial/docker-mailserver:v2 \
      /bin/sh -c 'echo "$MAIL_USER|$(doveadm pw -s CRAM-MD5 -u $MAIL_USER -p $MAIL_PASS)"' >> config/postfix-accounts.cf

#### Generate DKIM keys 

    docker run --rm \
      -v "$(pwd)/config":/tmp/docker-mailserver \
      -ti tvial/docker-mailserver:v2 generate-dkim-config

Now the keys are generated, you can configure your DNS server by just pasting the content of `config/opedkim/keys/domain.tld/mail.txt` in your `domain.tld.hosts` zone.

#### Start the container

    docker-compose up -d mail

You're done!
