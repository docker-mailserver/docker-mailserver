---
title: 'Override the Default Configs | Postfix'
---

[Our default Postfix configuration](https://github.com/docker-mailserver/docker-mailserver/blob/master/target/postfix/main.cf) can easily be extended to add parameters or modify existing ones by providing a `docker-data/dms/config/postfix-main.cf`. This file uses the same format as Postfix `main.cf` does ([See official docs](http://www.postfix.org/postconf.5.html) for all parameters and syntax rules).

!!! example "Example"

    One can easily increase the [backwards-compatibility level](http://www.postfix.org/postconf.5.html#compatibility_level) and set new Postscreen options:

    ```cf
    # increase the compatibility level from 2 (default) to 3
    compatibility_level = 3
    # set a threshold value for Spam detection
    postscreen_dnsbl_threshold = 4
    ```


!!! help "How are your changes applied?"

    The custom configuration you supply is appended to the default configuration located at `/etc/postfix/main.cf`, and then `postconf -nf` is run to remove earlier duplicate entries that have since been replaced. This happens early during container startup before Postfix is started.

---

Similarly, it is possible to add a custom `docker-data/dms/config/postfix-master.cf` file that will override the standard `master.cf`. **Note**: Each line in this file will be passed to `postconf -P`, i.e. **the file is not appended as a whole** to `/etc/postfix/master.cf` like `docker-data/dms/config/postfix-main.cf`! The expected format is `<service_name>/<type>/<parameter>`, for example:

```cf
# adjust the submission "reject_unlisted_recipient" option
submission/inet/smtpd_reject_unlisted_recipient=no
```

!!! attention
    There should be no space between the parameter and the value.

Run `postconf -Mf` in the container without arguments to see the active master options.
