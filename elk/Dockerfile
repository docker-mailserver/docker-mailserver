FROM sebp/elk

RUN mkdir /etc/logstash/patterns.d
RUN curl -L https://raw.githubusercontent.com/whyscream/postfix-grok-patterns/master/postfix.grok > /etc/logstash/patterns.d/postfix.grok
RUN curl -L https://raw.githubusercontent.com/whyscream/postfix-grok-patterns/master/50-filter-postfix.conf > /etc/logstash/conf.d/15-filter-postfix.conf

# add mailserver listen
ADD 01-mailserver.conf /etc/logstash/conf.d/
# override syslog
ADD 10-syslog.conf /etc/logstash/conf.d/

