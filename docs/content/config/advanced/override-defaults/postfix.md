---
title: 'Override the Default Configs | Postfix'
---

The Postfix default configuration can easily be extended by providing a `config/postfix-main.cf` in postfix format.
This can also be used to add configuration that is not in our default configuration.

For example, one common use of this file is for increasing the default maximum message size:

```cf
# increase maximum message size
message_size_limit = 52428800
```

That specific example is now supported and can be handled by setting `POSTFIX_MESSAGE_SIZE_LIMIT`.

!!! seealso

    [Postfix documentation](http://www.postfix.org/documentation.html) remains the best place to find configuration options.

Each line in the provided file will be loaded into postfix.

In the same way it is possible to add a custom `config/postfix-master.cf` file that will override the standard `master.cf`. Each line in the file will be passed to `postconf -P`. The expected format is `<service_name>/<type>/<parameter>`, for example:

```cf
submission/inet/smtpd_reject_unlisted_recipient=no
```

Run `postconf -P` in the container without arguments to see the active master options.

!!! note
    There should be no space between the parameter and the value.

Have a look at the code for more information.
