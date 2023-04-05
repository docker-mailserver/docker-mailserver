---
title: 'Troubleshooting | Debugging'
hide:
    - toc
---

This page contains valuable information when it comes to resolving issues you encounter.

!!! info "Contributions Welcome!"

    Please consider contributing solutions to the [FAQ][docs-faq] :heart:

[docs-faq]: ../../faq.md

## Preliminary Information

1. **Sent mail is never received?** Some hosting provides have a stealth block on port 25. Make sure to check with your hosting provider that traffic on port 25 is allowed. Common hosting providers known to have this issue:
    - [Azure](https://docs.microsoft.com/en-us/azure/virtual-network/troubleshoot-outbound-smtp-connectivity)
    - [AWS EC2](https://aws.amazon.com/premiumsupport/knowledge-center/ec2-port-25-throttle/)

## Steps for Debugging DMS

1. **Enable verbose debugging output**: You may find it useful to increase the log verbosity (for startup logs) by setting the [`LOG_LEVEL`][docs-environment-log-level] environment variable to `debug` or `trace`.
2. **Use the mail server log and a search engine**: This may sound stupid, but the posting of many issues could have been avoided by watching the log and pasting the errors in your favorite search engine. 50% of the time, this is what maintainers do when issues are encountered, another 40% does not require the search because maintainers already did it in the past. **Use a search engine!** The mail server log can be acquired by running `docker log <CONTAINER NAME>` (or `docker logs -f <CONTAINER NAME>` if you want to follow the log).
3. **Make sure you know what you're doing**: Especially for beginners, make sure you read our [Introduction][docs-introduction] and [Usage][docs-usage] articles.
4. **Search the whole FAQ**: Our [FAQ][docs-faq] contains answers for common problems. Make sure you go through the list.
5. **Try the simplest setup first**: This is especially important for beginners! Some issues arise only in special configurations - make sure to start with a very simple setup and do not try to get everything to work at once.
6. **Try a clean install**: If you just started with DMS, and your setup just won't work, ry starting afresh.
7. **Debug a running container**: You may want to debug a running container. In this case, you want to go inside the container (using `docker exec -ti <CONTAINER NAME> bash`). In case you want to install software, you need to run `apt-get update` before using `apt-get install <PACKAGE>`! If you need an editor, install `vim` or `nano`. It is always a good idea to `tail` / `cat` as many logs as possible and search through them for issues - you do not need to install software for this.

[docs-environment-log-level]: ../environment.md#log_level
[docs-introduction]: ../introduction.md
[docs-usage]: ../usage.md
