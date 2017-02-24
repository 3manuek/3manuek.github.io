---
layout: post
title:  "Playing with Postgres and Kafka."
date:   2017-02-20
description: Using the dirty way.
tags : [PostgreSQL, Kafka]
categories:
- PostgreSQL
category: blog
comments: true 
permalink: kafkaandcopypg
---


## COPY and kafkacat

Obviously, integrations as [bottlewater][3] allows a more elegant solution for
producing changes from a Postgres instance to a kafka broker.

Althuogh, the exposed technique in the current post could be used for more 
simplistic implementations. 


### kafkacat and librdkafka

[kafkacat][1] is a tool based on the same author's library [librdkafka][2] which
does exactly what its name propose: produce and consume from a Kafka broker.




### Producing to Kafka broker

Producing fake data to the Kafka broker, composed by `key` and `payload`:

```sh
randtext() {cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1}
while (true) ; 
  do
    for i in $(seq 1 50)  
      do echo "$(uuidgen);$(randtext)" 
     done  | kafkacat -P -b localhost:9092 -qe -K ';' -t PGSHARD 
     sleep 10
  done
```


### Consuming topics incrementally inside Postgres

Consuming the topic partitionins from the `beginning` and setting a limit of `100` documents:

```sh
bin/psql -p7777 -Upostgres master <<EOF
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o beginning  -p 0 | awk ''{print "P0\t\""$0"\""}'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o beginning  -p 1 | awk ''{print "P1\t\""$0"\""}'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o beginning  -p 2 | awk ''{print "P2\t\""$0"\""}'' ';
EOF
```

And then using `stored`, in order to consume from the last offset left by the consumer on the group:

```sh
bin/psql -p7777 -Upostgres master <<EOF
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o stored  -p 0 | awk ''{print "P0\t\""$0"\""}'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o stored  -p 1 | awk ''{print "P1\t\""$0"\""}'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o stored  -p 2 | awk ''{print "P2\t\""$0"\""}'' ';
EOF
```

### Producing messages from COPY

The same way is possible to consume changes, it is possible to do the same for producing 
data to the broker. In the bellow example, I'm using the server address as a key.

```sh
bin/psql -p7777 -Upostgres master <<EOF
COPY ( SELECT inet_server_add() || ';',group_id,payload FROM sourte_table) TO PROGRAM 'kafkacat -P -b localhost:9092 -qe -K ';' -t PGSHARD';
```

Hope this post its useful!


{% if page.comments %}
<div id="disqus_thread"></div>
<script>


var disqus_config = function () {
this.page.url = {{ site.url }};  // Replace PAGE_URL with your page's canonical URL variable
this.page.identifier = {{ page.title }}; // Replace PAGE_IDENTIFIER with your page's unique identifier variable
};

(function() { // DON'T EDIT BELOW THIS LINE
var d = document, s = d.createElement('script');
s.src = '//3manuek.disqus.com/embed.js';
s.setAttribute('data-timestamp', +new Date());
(d.head || d.body).appendChild(s);
})();
</script>
<noscript>Please enable JavaScript to view the <a href="https://disqus.com/?ref_noscript">comments powered by Disqus.</a></noscript>
{% endif %}

[1]: https://github.com/edenhill/kafkacat
[2]: https://github.com/edenhill/librdkafka
[3]: https://www.confluent.io/blog/bottled-water-real-time-integration-of-postgresql-and-kafka/