*Dovecot full text search using solr backend*

Dovecot can use several fts backends to support efficient and fast full text searching of e-mails directly from the imap server. Especially if you have one or more large mail folders this can make a huge difference, since the alternative is dovecot searching through each and every email all by itself on the spot, agian and again. The latter most times means one cannot search through a large pile off emails with clients that don't store all imap mail locally, for example mobile clients like Gmail or webmail clients.
One of these is Apache SOLR, an fast and efficient multi-purpose search indexer.

Firstly you need a working solr container, for this the official docker container will do:

```
---
version: "3.3"

services:
  solr:
    image: solr:latest
    environment:
      SOLR_JAVA_MEM: "-Xms2g -Xmx2g"
    volumes:
      - <local folder>:/var/solr
    restart: always
```

We'll assume dms will connect internally to solr, so either append the above docker composer snippet to your dms compose.yml or make sure both containers use the same docker network.
The enviroment setting SOLR_JAVA_MEM is optional, but solr can be quite resource hungry so the default of 512MB can be exhausted rather quickly.

Once started you need to configure a solr core for dovecot:
```
docker exec -it solr_solr_1 /bin/sh
solr create -c dovecot
cp -R /opt/solr/contrib/analysis-extras/lib /var/solr/data/dovecot
```

Stop the container, you should now have a data/dovecot folder. All that is needed on the solr part is a schema that is tailored specifically for dovecot fts. Luckally dovecot provides these:
https://github.com/dovecot/core/tree/main/doc

As of writing of this guide solr 9 is current, so you need the 2 solr 9 config files:
- solr-config-9.xml
- solr-schema-9.xml

Copy solr-config-9.xml to the data/dovecot folder and name it: solrconfig.xml
Copy solr-schema-9.xml to the data/dovecot folder and name it: schema.xml, remove managed-schema.xml
Both files should be owned by uid and gid 8983.

Start the solr container once again, you should now have a working dovecot fts specific solr core. All that is left is to connect dms dovecot to this solr core:

Create a 10-plugin.conf file in your config/dovecot folder and link it in your compose.yml like so:
```
volumes:
  ...
  <local dms folder>/config/dovecot/10-plugin.conf:/etc/dovecot/conf.d/10-plugin.conf:ro
  ...
```

It's content should be:
```
mail_plugins = $mail_plugins fts fts_solr

plugin {
  fts = solr
  fts_autoindex = yes
  fts_solr = url=http://solr_solr_1:8983/solr/dovecot/
}
```

Once you restarted your dms instance, you have to tell dovecot it should reindex all mail: `docker compose exec mailserver doveadm fts rescan -A`

Indexing will take a while depending on how large your mail folders are, but in general after 15 minutes or so you should be able to search your mail using dovecot fts feature!
