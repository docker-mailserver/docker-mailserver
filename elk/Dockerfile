FROM sebp/elk:720

RUN mkdir /etc/logstash/patterns.d
#postfix grok and filter
RUN curl -L https://raw.githubusercontent.com/whyscream/postfix-grok-patterns/master/postfix.grok > /etc/logstash/patterns.d/postfix.grok
RUN curl -L https://raw.githubusercontent.com/whyscream/postfix-grok-patterns/master/50-filter-postfix.conf > /etc/logstash/conf.d/15-filter-postfix.conf
# custom amavis grok and filter
COPY amavis.grok  /etc/logstash/patterns.d
COPY 16-amavis.conf /etc/logstash/conf.d
# dovecot grok and filter
RUN curl -L https://raw.githubusercontent.com/ninech/logstash-patterns/master/patterns.d/dovecot.grok > /etc/logstash/patterns.d/dovecot.grok
RUN curl -L https://raw.githubusercontent.com/ninech/logstash-patterns/master/exmples/50-filter-dovecot.conf > /etc/logstash/conf.d/17-filter-dovecot.conf
# FIXME: may be a cron job? 
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir  -p /usr/share/GeoIP && \
 curl -L http://geolite.maxmind.com/download/geoip/database/GeoLite2-City.mmdb.gz | gunzip -c - > /usr/share/GeoIP/GeoLiteCity.dat 

WORKDIR ${LOGSTASH_HOME}
RUN gosu logstash bin/logstash-plugin install --local --no-verify logstash-filter-geoip

# override beats input 
COPY 02-beats-input.conf /etc/logstash/conf.d/
# override syslog
COPY 10-syslog.conf /etc/logstash/conf.d/

# avoid Bootstrap Checks failure on production
RUN /bin/grep -q  -F 'transport.host' /etc/elasticsearch/elasticsearch.yml || echo "transport.host: 127.0.0.1" >> /etc/elasticsearch/elasticsearch.yml
