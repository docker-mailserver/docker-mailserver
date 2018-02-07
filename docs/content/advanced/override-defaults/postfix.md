The Postfix default configuration can easily be extended by providing a `config/postfix-main.cf` in postfix format.
This can also be used to add configuration that is not in our default configuration.

For example, one common use of this file is for increasing the default maximum message size:
```
# increase maximum message size
   message_size_limit = 52428800
```

[Postfix documentation](http://www.postfix.org/documentation.html) remains the best place to find configuration options.

Each line in the provided file will be loaded into postfix.

Have a look at the code for more information.