The Postfix default configuration can easily be overridden providing a `config/postfix-main.cf` at postfix format.
This can be used to also add configuration that are not in out default configuration.
[Postfix documentation](http://www.postfix.org/documentation.html) remains the best place to find configuration options.

Each line in the provided line will be loaded into postfix.

Have a look to the code for more information: 
https://github.com/tomav/docker-mailserver/blob/master/target/start-mailserver.sh#L360-L367