---
title: 'Security | mail_crypt (email/storage encryption)'
---

!!! info

    The Mail crypt plugin is used to secure email messages stored in a Dovecot system. Messages are encrypted before written to storage and decrypted after reading. Both operations are transparent to the user.

    In case of unauthorized access to the storage backend, the messages will, without access to the decryption keys, be unreadable to the offending party.

    There can be a single encryption key for the whole system or each user can have a key of their own. The used cryptographical methods are widely used standards and keys are stored in portable formats, when possible.



Official Dovecot documentation: https://doc.dovecot.org/configuration_manual/mail_crypt_plugin/

---

## Single Encryption Key / Global Method

1. Create `10-custom.conf` and populate it with the following:

    ```
    # Enables mail_crypt for all services (imap, pop3, etc)
    mail_plugins = $mail_plugins mail_crypt
    plugin {
      mail_crypt_global_private_key = </certs/ecprivkey.pem
      mail_crypt_global_public_key = </certs/ecpubkey.pem
      mail_crypt_save_version = 2
    }
    ```

2. Shutdown your mailserver (`docker compose down`)

3. You then need to [generate your global EC key](https://doc.dovecot.org/configuration_manual/mail_crypt_plugin/#ec-key). We named them `/certs/ecprivkey.pem` and `/certs/ecpubkey.pem` in step #1.

4. The EC key needs to be available in the container. I prefer to mount a /certs directory into the container:
    ```yaml
    services:
      mailserver:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        volumes:
        . . .
          - ./certs/:/certs
        . . .
    ```

5. While you're editing the `compose.yaml`, add the configuration file:
    ```yaml
    services:
      mailserver:
        image: ghcr.io/docker-mailserver/docker-mailserver:latest
        volumes:
        . . .
          - ./config/dovecot/10-custom.conf:/etc/dovecot/conf.d/10-custom.conf
          - ./certs/:/certs
        . . .
    ```

6. Start the container, monitor the logs for any errors, send yourself a message, and then confirm the file on disk is encrypted:
    ```
    [root@ip-XXXXXXXXXX ~]# cat -A /mnt/efs-us-west-2/maildata/awesomesite.com/me/cur/1623989305.M6v�z�@�� m}��,��9����B*�247.us-west-2.compute.inE��\Ck*�@7795,W=7947:2,
    T�9�8t�6�� t���e�W��S   `�H��C�ڤ �yeY��XZ��^�d�/��+�A
    ```

This should be the minimum required for encryption of the mail while in storage.
