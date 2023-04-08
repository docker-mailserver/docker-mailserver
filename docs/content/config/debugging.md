---
title: 'Debugging'
hide:
    - toc
---

This page contains valuable information when it comes to resolving issues you encounter.

!!! info "Contributions Welcome!"

    Please consider contributing solutions to the [FAQ][docs-faq] :heart:

## Preliminary Information

### Mail sent from DMS does not arrive at destination

Some service providers block outbound traffic on port 25. Common hosting providers known to have this issue:

- [Azure](https://docs.microsoft.com/en-us/azure/virtual-network/troubleshoot-outbound-smtp-connectivity)
- [AWS EC2](https://aws.amazon.com/premiumsupport/knowledge-center/ec2-port-25-throttle/)
- [Vultr](https://www.vultr.com/docs/what-ports-are-blocked/)

These links may advise how the provider can unblock the port through additional services offered, or via a support ticket request.

## Steps for Debugging DMS

1. **Increase log verbosity**: Very helpful for troubleshooting problems during container startup. Set the environment variable [`LOG_LEVEL`][docs-environment-log-level] to `debug` or `trace`.
2. **Use error logs as a search query**: Try finding an _existing issue_ or _search engine result_ from any errors in your container log output. Often you'll find answers or more insights. If you still need to open an issue, sharing links from your search may help us assist you. The mail server log can be acquired by running `docker log <CONTAINER NAME>` (_or `docker logs -f <CONTAINER NAME>` if you want to follow the log_).
3. **Understand the basics of mail servers**: Especially for beginners, make sure you read our [Introduction][docs-introduction] and [Usage][docs-usage] articles.
4. **Search the whole FAQ**: Our [FAQ][docs-faq] contains answers for common problems. Make sure you go through the list.
5. **Reduce the scope**: Ensure that you can run a basic setup of DMS first. Then incrementally restore parts of your original configuration until the problem is reproduced again. If you're new to DMS, it is common to find the cause is misunderstanding how to configure a minimal setup.

### Debug a running container

To get a shell inside the container run: `docker exec -it <CONTAINER NAME> bash`.

If you need more flexibility than `docker logs` offers, within the container `/var/log/mail/mail.log` and `/var/log/supervisor/` are the most useful locations to get relevant DMS logs. Use the `tail` or `cat` commands to view their contents.

To install additional software:

- `apt-get update` is needed to update repository metadata.
- `apt-get install <PACKAGE>`
- For example if you need a text editor, `nano` is a good package choice for beginners.

[docs-faq]: ../faq.md
[docs-environment-log-level]: ./environment.md#log_level
[docs-introduction]: ../introduction.md
[docs-usage]: ../usage.md
