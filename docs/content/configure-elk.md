From [Wikipedia](https://en.wikipedia.org/wiki/Elasticsearch):
>Elasticsearch can be used to search all kinds of documents. It provides scalable search, has near real-time search, and supports multitenancy. "Elasticsearch is distributed, which means that indices can be divided into shards and each shard can have zero or more replicas. Each node hosts one or more shards, and acts as a coordinator to delegate operations to the correct shard(s). Rebalancing and routing are done automatically [...]"

This implements sends mail logs to a ELK stack via filebeat client.

# Environment variables:
**ENABLE_ELK_FORWARDER**
* **empty** => disabled
* **1** => enables forwarder 

**ELK_HOST**
* elk (default)

**ELK_PORT** 
* 5044 (default)

# Configuration File:
the start-mailserver.sh scripts use `/etc/filebeat/filebeat.yml.tmpl` as a template to set HOST and PORT. 
You can override that template or set a custom config file as ro volume.

```
mail:
   ~ 
   volumes: 
    - config/filebeat.yml:/etc/filebeat/filebeat.yml:ro
```

## Run ELK embedded on mailserver stack.
you can run directly the embeeded ELK using docker compose. No needs config.
 
```
cp docker-compose.elk.yml.dist docker-compose.yml
docker-compose up
```

## Use a external ELK. 
you can be send logs to you own instance of ELK stack. 
needs set the environments variables.

```
mail:
   ~ 
   environment: 
    - ENABLE_ELK_FORWARDER=1
    - ELK_HOST=elk_host_or_ip
    - ELK_PORT= 5044
```
On you ELK stack should be create a logstash input 
```
#/etc/logstash/conf.d/02-beats-input.conf
input {
  beats {
    port => 5044
    ssl => false
  }
}
```



# Create Index on Kibana
Go http://localhost:5601. The first time needs create default index.
Steps: 

1. Create Index pattern

 - **Index  name or pattern** * 
 - Select **Time-field name** (refresh fields): @timestamp (appears until process some log)
 - Create

1. Go to Discover  and filter by fields. 
