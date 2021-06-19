---
title: 'Best Practices | Folders'
hide:
  - toc # Hide Table of Contents for this page
---

## Add a folder

Please refer to `target/dovecot/15-mailboxes.conf` for existing folders definition and potential folders creation.
More detail available on [Upstream example config](https://github.com/dovecot/core/blob/master/doc/example-config/conf.d/15-mailboxes.conf).

## Consideration

### Create folder needed as soon as possible. 

Different mail clients have different way of handling folders. Users might experience issues such like archived emails are only available in local environment. And if the folders are available / created later, users shall need to move quite a few emails between exising and newly created folders.


### Tag v.s. Folder name

Certain email clients simply ignore the tag defined in `RFC 6154` and look of the exact name instead. So it might be necessary to create folder with name the same as tag. 

### i18n 

Users and email clients might want to have folder names in local language instead of English. Please test carefully. This might need to find a balance with the tag v.s. folder name issue.

