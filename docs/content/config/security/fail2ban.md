Fail2ban is installed automatically and bans IP addresses for 3 hours after 3 failed attempts in 10 minutes by default. If you want to change this, you can easily edit [config/fail2ban-jail.cf](https://github.com/tomav/docker-mailserver/blob/master/config/fail2ban-jail.cf).

__Important__: The mail container must be launched with the NET_ADMIN capability in order to be able to install the iptable rules that actually ban IP addresses. Thus either include `--cap-add=NET_ADMIN` in the docker run commandline or the equivalent docker-compose.yml:
```
   cap_add:
     - NET_ADMIN
```
If you don't you will see errors of the form
```
iptables -w -X f2b-postfix -- stderr: "getsockopt failed strangely: Operation not permitted\niptables v1.4.21: can't initialize iptabl
es table `filter': Permission denied (you must be root)\nPerhaps iptables or your kernel needs to be upgraded.\niptables v1.4.21: can'
t initialize iptables table `filter': Permission denied (you must be root)\nPerhaps iptables or your kernel needs to be upgraded.\n"
2016-06-01 00:53:51,284 fail2ban.action         [678]: ERROR   iptables -w -D INPUT -p tcp -m multiport --dports smtp,465,submission -
j f2b-postfix
```