---
title: 'Advanced | IPv6'
---

## Not Available
docker-mailserver doesn't currently support iPv6 networking! Trying to get mails using iPv6 will result with postfix not being able to find your hostname.

## Fix
To fix the issue, basicly remove the AAAA record for your mailserver. This will prevent email senders from using iPv6.

## Further Discussion
See [#1438][github-issue-1438] and [#2927][github-issue-2927]

[github-issue-1438]: https://github.com/docker-mailserver/docker-mailserver/issues/1438
[github-issue-2927]: https://github.com/docker-mailserver/docker-mailserver/issues/2927