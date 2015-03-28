# docker-mailserver

## installation

TODO when automatic build will be enabled.

## build

	docker build -t tvial/docker-mailserver .

## docker-compose template

	mail:
	  build: .
	  hostname: mail
	  domainname: my-domain.com
	  ports:
	  - "25:25"
	  - "143:143"
	  - "587:587"
	  - "993:993"
	  volumes:
	    - ./configs/courier:/etc/courier
	    - ./configs/postfix:/etc/postfix
	    - ./configs/spamassassin:/etc/spamassassin
	  environment:
	    docker_mail_domain: "my-domain.com"
	    docker_mail_users:
	      - "username1@my-domain.com|username1password"
	      - "username2@my-domain.com|username2password"