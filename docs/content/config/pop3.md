---
title: Mail Delivery with POP3
hide:
  - toc # Hide Table of Contents for this page
---

!!! warning

    **We do not recommend using POP3. Use IMAP instead.**

If you really want to have POP3 running add the ports 110 and 995 and the environment variable `ENABLE_POP3` to your `docker-compose.yml`: 

```yaml
mail:
  ports:
    - "25:25"
    - "143:143"
    - "587:587"
    - "993:993"
    - "110:110"
    - "995:995" 
  environment:
    - ENABLE_POP3=1
```
