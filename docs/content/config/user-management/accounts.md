Users (email accounts) are managed in `config/postfix-accounts.cf`.
Just add the full email address and its encrypted password separated by a pipe.

Example:

    user1@domain.tld|{SHA512-CRYPT}$6$2YpW1nYtPBs2yLYS$z.5PGH1OEzsHHNhl3gJrc3D.YMZkvKw/vp.r5WIiwya6z7P/CQ9GDEJDr2G2V0cAfjDFeAQPUoopsuWPXLk3u1
    user2@otherdomain.tld|{SHA512-CRYPT}$6$2YpW1nYtPBs2yLYS$z.5PGH1OEzsHHNhl3gJrc3D.YMZkvKw/vp.r5WIiwya6z7P/CQ9GDEJDr2G2V0cAfjDFeAQPUoopsuWPXLk3u1

In the previous example, we added 2 mail accounts for 2 different domains.
This is will automagically configure the mail-server as multi-domain.

To generate a new mail account entry in your configuration, you could run for example the following:

    docker run --rm \
      -e MAIL_USER=user1@domain.tld \
      -e MAIL_PASS=mypassword \
      -ti tvial/docker-mailserver:latest \
      /bin/sh -c 'echo "$MAIL_USER|$(doveadm pw -s SHA512-CRYPT -u $MAIL_USER -p $MAIL_PASS)"' >> config/postfix-accounts.cf

You will be asked for a password. Just copy all the output string in the file `config/postfix-accounts.cf`.

The `doveadm pw` command let you choose between several encryption schemes for the password.
Use doveadm pw -l to get a list of the currently supported encryption schemes.