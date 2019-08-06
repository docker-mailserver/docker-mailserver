**We do not recommend using POP. Use IMAP instead.**

If you really want to have POP3 running, add 3 lines to the docker-compose.yml :  
Add the ports 110 and 995, and add environment variable ENABLE_POP : 

```
mail:
  [...]
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
