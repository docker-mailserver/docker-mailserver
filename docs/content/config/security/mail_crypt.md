---
title: 'Security | mail_crypt (email/storage encryption)'
---

!!! info
 
    The Mail crypt plugin is used to secure email messages stored in a Dovecot system. Messages are encrypted before written to storage and decrypted after reading. Both operations are transparent to the user.

    In case of unauthorized access to the storage backend, the messages will, without access to the decryption keys, be unreadable to the offending party.

    There can be a single encryption key for the whole system or each user can have a key of their own. The used cryptographical methods are widely used standards and keys are stored in portable formats, when possible.

Official Dovecot documentation: https://doc.dovecot.org/configuration_manual/mail_crypt_plugin/

---

## Basic Setup

1. Before you can enable mail_crypt, you'll need to copy out several dovecot/conf.d files to the host (from a running container) and then take the container down:
    ```bash
    mkdir -p config/dovecot
    docker cp mailserver:/etc/dovecot/conf.d/20-lmtp.conf config/dovecot/
    docker cp mailserver:/etc/dovecot/conf.d/20-imap.conf config/dovecot/
    docker cp mailserver:/etc/dovecot/conf.d/20-pop3.conf config/dovecot/
    docker-compose down
    ```
2. You then need to [generate your global EC key](https://doc.dovecot.org/configuration_manual/mail_crypt_plugin/#ec-key).
3. The EC key needs to be available in the container. I prefer to mount a /certs directory into the container: 
    ```yaml
    services:
      mailserver:
        image: docker.io/mailserver/docker-mailserver:latest
        volumes:
        . . .
          - ./certs/:/certs
        . . .
    ```
4. While you're editing the docker-compose.yml, add the configuration files you copied out:
    ```yaml
    services:
      mailserver:
        image: docker.io/mailserver/docker-mailserver:latest
        volumes:
        . . .
          - ./config/dovecot/20-lmtp.conf:/etc/dovecot/conf.d/20-lmtp.conf
          - ./config/dovecot/20-imap.conf:/etc/dovecot/conf.d/20-imap.conf
          - ./config/dovecot/20-pop3.conf:/etc/dovecot/conf.d/20-pop3.conf
          - ./certs/:/certs
        . . .
    ```
5. The `mail_crypt` plugin, unless you're using a non-standard configuration of docker-mailserver, should be enabled on both `lmtp` and `imap`. You'll want to edit three different files:
    - `./config/dovecot/20-lmtp.conf`
      ```
      protocol lmtp {
        mail_plugins = $mail_plugins sieve mail_crypt
        plugin {
          mail_crypt_global_private_key = </certs/ecprivkey.pem
          mail_crypt_global_public_key = </certs/ecpubkey.pem
          mail_crypt_save_version = 2
        }
      }
      ```
    - `./config/dovecot/20-imap.conf`
      ```
      protocol imap {
        mail_plugins = $mail_plugins imap_quota mail_crypt
        plugin {
          mail_crypt_global_private_key = </certs/ecprivkey.pem
          mail_crypt_global_public_key = </certs/ecpubkey.pem
          mail_crypt_save_version = 2
        }
      }
      ```
    - If you use pop3, make the same changes in `20-pop3.conf`
6. Start the container and monitor the logs for any errors

This should be the minimum required for encryption of the mail while in storage.