Users are managed in `config/postfix-accounts.cf`.
Just add the full email address and its encrypted password separated by a pipe.

Example:

    user1@domain.tld|{CRAM-MD5}mypassword-cram-md5-encrypted
    user2@otherdomain.tld|{CRAM-MD5}myotherpassword-cram-md5-encrypted

To generate the password you could run for example the following:

    docker run --rm \
      -e MAIL_USER=user1@domain.tld \
      -e MAIL_PASS=mypassword \
      -ti tvial/docker-mailserver:v2 \
      /bin/sh -c 'echo "$MAIL_USER|$(doveadm pw -s CRAM-MD5 -u $MAIL_USER -p $MAIL_PASS)"' >> config/postfix-accounts.cf

You will be asked for a password. Just copy all the output string in the file `config/postfix-accounts.cf`.

The `doveadm pw` command let you choose between several encryption schemes for the password.
Use doveadm pw -l to get a list of the currently supported encryption schemes.
