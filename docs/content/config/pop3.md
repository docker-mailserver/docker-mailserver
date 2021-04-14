---
title: Mail Delivery with POP3
hide:
  - toc # Hide Table of Contents for this page
---

If you want to use POP3(s), you have to add the ports 110 and/or 995 (TLS secured) and the environment variable `ENABLE_POP3` to your `docker-compose.yml`: 

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
