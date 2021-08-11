---
title: 'Security | mail_crypt (email/storage encryption)'
---

The [Mail crypt plugin](https://doc.dovecot.org/configuration_manual/mail_crypt_plugin/) is used to secure email messages stored in a Dovecot system. Messages are encrypted before written to storage and decrypted after reading. Both operations are transparent to the user.

In case of unauthorized access to the storage backend, the messages will, without access to the decryption keys, be unreadable to the offending party.

There can be a single encryption key for the whole system or each user can have a key of their own. The used cryptographical methods are widely used standards and keys are stored in portable formats, when possible.


!!! warning
 
    It's best to choose ONE of the options below early on and carefully, then stick with it. There is no guarantee that switching from Global to User keys or vice versa will be easy and not result in losing access to emails.

!!! warning

    Neither of the methods below will encrypt older/already existing emails on disk. Only emails received after enabling will be encrypted.

---

## Encrypted Per User Keys 

Enables per user storage encryption keys and password protects them.

1. Set `ENABLE_PER_USER_STORAGE_ENCRYPTION=1` in your `docker-compose.yml`.

2. Restart the docker-mailserver with `docker-compose down` and `docker-compose up`.

    !!! info
    
        Both the _curve_ and _scheme_ are configurable:

        - You can change the `mail_crypt_curve` from the default `secp521r1` by setting `PER_USER_STORAGE_ENCRYPTION_CURVE`.
        - You can change the `scheme` from the default `CRYPT` by setting `PER_USER_STORAGE_ENCRYPTION_SCHEME`.
        

    With `ENABLE_PER_USER_STORAGE_ENCRYPTION` enabled:

    - `email add` requests will automatically password protect the encryption keys.
    - `email update` requests will either:
        - Add the password protected keys if they aren't already there for a user.
        - Update the existing password for the encryption keys.

3. [Verify encryption is working](#verifying-encryption).


## Single Encryption Key / Global Method

Enables a single key for encryption (**not recommended**).

1. You then need to [generate your global EC key](https://doc.dovecot.org/configuration_manual/mail_crypt_plugin/#ec-key). We name them `/certs/ecprivkey.pem` and `/certs/ecpubkey.pem` in step #2 below.

2. Create `10-custom.conf` and populate it with the following:

    ```
    # Enables mail_crypt for all services (imap, pop3, etc)
    mail_plugins = $mail_plugins mail_crypt
    plugin {
      mail_crypt_global_private_key = </certs/ecprivkey.pem
      mail_crypt_global_public_key = </certs/ecpubkey.pem
      mail_crypt_save_version = 2
    }
    ```

3. Shutdown the `docker-mailserver` container with `docker-compose down`.

4. The EC keys and `10-custom.conf` need to be available in the container. I prefer to mount a `/certs` directory into the container:
    ```yaml
    services:
      mailserver:
        image: docker.io/mailserver/docker-mailserver:latest
        volumes:
        . . .
          - ./config/dovecot/10-custom.conf:/etc/dovecot/conf.d/10-custom.conf
          - ./certs/:/certs
        . . .
    ```

5. Start the `docker-mailserver` container with `docker-compose up -d`.
6. [Verify encryption is working](#verifying-encryption).

## Verifying Encryption

Once the container is running:

  1. Monitor the logs for any errors.
  2. Send yourself a message.
  3. Confirm the received email is encrypted on disk. Example using the `xxd` command on the host:
      ```
      [ec2-user@ip-xxx docker-mailserver]$ xxd /mnt/efs-us-west-2/maildata/mydomain.com/user1/cur/1626112488.M548380P8093.ip-xxx.us-west-2.compute.internal,S=128377,W=130314:2,S | grep CRYPTED
      00000000: 4352 5950 5445 4403 0702 0000 0002 0000  CRYPTED.........
      ```
      If you don't see any output, then encryption is not working properly.