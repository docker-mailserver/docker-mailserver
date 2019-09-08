This setup allows sending notifications/alerts, with TLS setups and spoof protection. This can also be a beginner's guide to get a feeling about how the setup works.

First, get your TLS certificate from [Letsencrypt](https://letsencrypt.org) or follow a docker example [here](https://www.humankode.com/ssl/how-to-set-up-free-ssl-certificates-from-lets-encrypt-using-docker-and-nginx). Do not forget to also add your subdomain `mail.mydomain.org` to the list of domains during creating the certificate.

Then, use the following `docker-compose.yml` file (edit with your own domain name) instead of the default one to re-create your mailserver following the instructions on the main page (or simply re-run `sudo docker-compose up -d mail`).

```
version: '2'
services:
  mail:
    image: tvial/docker-mailserver:latest
    hostname: mail
    domainname: mydomain.org   ## adapt to your own domain
    container_name: mail
    ports:
    - "25:25"
    - "143:143"
    - "587:587"
    - "993:993"
    volumes:
    - maildata:/var/mail
    - mailstate:/var/mail-state
    - ./config/:/tmp/docker-mailserver/
    - /path_to_letsencrypt/live/mydomain.org/fullchain.pem:/etc/letsencrypt/live/mail.mydomain.org/fullchain.pem:ro ## adapt to your own domain
    - /path_to_letsencrypt/live/mydomain.org/privkey.pem:/etc/letsencrypt/live/mail.mydomain.org/privkey.pem:ro ## adapt to your own domain
    environment:
    - ONE_DIR=1
    - SSL_TYPE=letsencrypt
    - SPOOF_PROTECTION=1
    - ENABLE_SRS=1
    cap_add:
    - NET_ADMIN
    - SYS_PTRACE
    restart: always
volumes:
  maildata:
    driver: local
  mailstate:
    driver: local

```
Then you can use the following Python code or other methods to send email with your own domains!
```
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

s = smtplib.SMTP(host='localhost', port=587)
s.starttls()
s.login('notify@mydomain.org', 'pswd1112')

msg = MIMEMultipart()       # create a message
msg['From']='notify@mydomain.org'
msg['To']='MyOtherEmailName@qq.com'
msg['Subject']="This is TEST"
msg.attach(MIMEText('Test message from Python. ', 'plain')) # or 'html'
s.send_message(msg)
```
Note that some mail servers may have blocked your IP address for spam protection, especially your dynamically allocated home IP address. 
