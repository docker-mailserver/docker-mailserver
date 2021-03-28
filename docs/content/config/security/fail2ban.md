---
title: 'Security | Fail2Ban'
hide:
  - toc # Hide Table of Contents for this page
---

Fail2Ban is installed automatically and bans IP addresses for 3 hours after 3 failed attempts in 10 minutes by default. If you want to change this, you can easily edit [`config/fail2ban-jail.cf`][github-file-f2bjail].

You can do the same with the values from `fail2ban.conf`, e.g `dbpurgeage`. In that case you need to edit [`config/fail2ban-fail2ban.cf`][github-file-f2bconfig].

!!! attention
    The mail container must be launched with the `NET_ADMIN` capability in order to be able to install the iptable rules that actually ban IP addresses.

    Thus either include `--cap-add=NET_ADMIN` in the docker run commandline or the equivalent `docker-compose.yml`:

    ```yaml
    cap_add:
      - NET_ADMIN
    ```

If you don't you will see errors the form of:

```log
iptables -w -X f2b-postfix -- stderr: "getsockopt failed strangely: Operation not permitted\niptables v1.4.21: can't initialize iptabl
es table `filter': Permission denied (you must be root)\nPerhaps iptables or your kernel needs to be upgraded.\niptables v1.4.21: can'
t initialize iptables table `filter': Permission denied (you must be root)\nPerhaps iptables or your kernel needs to be upgraded.\n"
2016-06-01 00:53:51,284 fail2ban.action         [678]: ERROR   iptables -w -D INPUT -p tcp -m multiport --dports smtp,465,submission -
j f2b-postfix
```

You can also manage and list the banned IPs with the [`setup.sh`][docs-setupsh] script.

[docs-setupsh]: ../setup.sh.md
[github-file-f2bjail]: https://github.com/docker-mailserver/docker-mailserver/blob/master/config/fail2ban-jail.cf
[github-file-f2bconfig]: https://github.com/docker-mailserver/docker-mailserver/blob/master/config/fail2ban-fail2ban.cf
