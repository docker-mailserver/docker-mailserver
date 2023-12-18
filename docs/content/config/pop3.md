---
title: Mail Delivery with POP3
hide:
  - toc # Hide Table of Contents for this page
---

If you want to use POP3(S), you have to add the ports 110 and/or 995 (TLS secured) and the environment variable `ENABLE_POP3` to your `compose.yaml`:

```yaml
mailserver:
  ports:
    - "25:25"    # SMTP  (explicit TLS => STARTTLS)
    - "143:143"  # IMAP4 (explicit TLS => STARTTLS)
    - "465:465"  # ESMTP (implicit TLS)
    - "587:587"  # ESMTP (explicit TLS => STARTTLS)
    - "993:993"  # IMAP4 (implicit TLS)
    - "110:110"  # POP3
    - "995:995"  # POP3 (with TLS)
  environment:
    - ENABLE_POP3=1
```
