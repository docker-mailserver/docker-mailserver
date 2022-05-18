---
title: 'Override the Default Configs | Postfix'
---

The Postfix default configuration can easily be extended by providing a `docker-data/dms/config/postfix-main.cf` in Postfix-format. This can also be used to add configuration that is not in our default configuration. the official [Postfix documentation](http://www.postfix.org/documentation.html) remains the best place to find configuration options.

!!! example "Example"

    One can easily increase the compatibility level and set new Postscreen options:

    ```cf
    # increase the compatibility level from 2 (default) to 3
    compatibility_level = 3
    # set a threshold value for Spam detection
    postscreen_dnsbl_threshold = 4
    ```

    You can also completely override the default Postfix configuration with a custom configuration this way.

!!! note "How are your changes applied?"

    The custom configuration you supply is appended to the default configuration located at `/etc/postfix/main.cf` and then, `postconf -nf` is run to get rid of multiple lines specifying the same service name or parameter. Only the last seen services definitions and parameters are applied! As a consequence, you can supply a completely custom configuration and it will override everything defined in the default configuration. Postfix itself is started at a later point in time during startup, so all changes will definitely picked up.

---

Similarly, it is possible to add a custom `docker-data/dms/config/postfix-master.cf` file that will override the standard `master.cf`. **Note**: Each line in this file will be passed to `postconf -P`, i.e. **the file is not appended as a whole** to `/etc/postfix/master.cf` like `docker-data/dms/config/postfix-main.cf`! The expected format is `<service_name>/<type>/<parameter>`, for example:

```cf
# adjust the submission "reject_unlisted_recipient" option
submission/inet/smtpd_reject_unlisted_recipient=no
```

!!! attention
    There should be no space between the parameter and the value.

Run `postconf -P` in the container without arguments to see the active master options.
