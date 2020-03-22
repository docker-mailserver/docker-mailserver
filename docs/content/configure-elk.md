From [Wikipedia](https://en.wikipedia.org/wiki/Elasticsearch):
>Elasticsearch can be used to search all kinds of documents. It provides scalable search, has near real-time search, and supports multitenancy. "Elasticsearch is distributed, which means that indices can be divided into shards and each shard can have zero or more replicas. Each node hosts one or more shards, and acts as a coordinator to delegate operations to the correct shard(s). Rebalancing and routing are done automatically [...]"

This implements sending mail logs to a ELK stack via filebeat client.

:construction: In the next release (v7.0.0), Filebeat client will not be included inside mailserver container anymore. The recommended practice is to run Filebeat in its own container (documented [below](#filebeat-container)).

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
    - ./config/filebeat.yml:/etc/filebeat/filebeat.yml:ro
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

2. Go to Discover and filter by fields. 

---
---
:warning: The following documentation only apply for the next release (v7.0.0). 

# Filebeat container
Configuration for each container is mainly done through _Hints based autodiscover_ (following [Elastic](https://www.elastic.co/guide/en/beats/filebeat/current/configuration-autodiscover-hints.html) practice).
By default, filebeat will **not** retrieve logs from any containers, you must enable logging using Docker labels as documented below.

## Configuration
### (Method 1) Using existing ELK

Update `config/filebeat.docker.yml` with your existing logstash endpoint:
```
output.logstash:
    hosts: ["elk_host_or_ip:5044"]
```

Adapt your Docker Compose file or use the one provided:
```
cp docker-compose.filebeat.yml.dist docker-compose.yml
docker-compose up -d
```

### (Method 2) Run ELK embedded on the same host

Filebeat will use the configuration file `config/filebeat.docker.yml`. For basic needs, you don't need to update the file (logstash endpoint is `127.0.0.1:5044'`).

#### Maxmind GeoIP license

As of Dec 30 2019, Maxming GeoIP database is no more publicly available. You must first [sign-up](https://www.maxmind.com/en/geolite2/signup) (it's free) and request for a GeoLite2-City license.
Then update the ELK build environment variables:
```
cp elk/.env.dist elk/.env
```
With your license number:
```
MAXMIND_LICENSE=your_license_number
```

#### Run containers
Adapt your Docker Compose file or use the one provided:
```
cp docker-compose.elk.yml.dist docker-compose.yml
docker-compose up -d
```

#### Create Index on Kibana
Go http://localhost:5601. The first time needs create default index.
Steps: 

1. Create Index pattern

 - **Index  name or pattern** * 
 - Select **Time-field name** (refresh fields): @timestamp (appears until process some log)
 - Create

2. Go to Discover and filter by fields.

:bangbang: This ELK image is provided for testing purpose without any security measure. Please follow these [hardening procedures](https://elk-docker.readthedocs.io/#security-considerations).