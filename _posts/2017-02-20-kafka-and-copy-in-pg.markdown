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

*This article is WIP*

![POC Image][4]


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


Inside Postgres:

```sql
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o beginning  -p 0 | awk ''{print "P0\t" $0 }'' ';
```


Consuming the topic partitionins from the `beginning` and setting a limit of `100` documents:

```sh
bin/psql -p7777 -Upostgres master <<EOF
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o beginning  -p 0 | awk ''{print "P0\t" \$0 }'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o beginning  -p 1 | awk ''{print "P1\t" \$0 }'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o beginning  -p 2 | awk ''{print "P2\t" \$0 }'' ';
EOF
```

And then using `stored`, in order to consume from the last offset left by the consumer on the group:

```sh
bin/psql -p7777 -Upostgres master <<EOF
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o stored  -p 0 | awk ''{print "P0\t" \$0 }'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o stored  -p 1 | awk ''{print "P1\t" \$0 }'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o stored  -p 2 | awk ''{print "P2\t" \$0 }'' ';
EOF
```

### Producing messages with COPY

The same way is possible to consume changes, it is possible to do the same for producing
data to the broker.


```
master=# COPY (select row_to_json(row(now() ,group_id , count(*))) from main group by group_id) TO PROGRAM 'kafkacat -P -b localhost:9092 -qe  -t AGGREGATIONS';
COPY 3
```

If you have a farm of servers and want to search the topic contents using a key,
you can do the following tweak:

```
COPY (select inet_server_addr() || ';', row_to_json(row(now() ,group_id , count(*))) from main group by group_id) TO PROGRAM 'kafkacat -P -K '';'' -b localhost:9092 -qe  -t AGGREGATIONS';
```


Taking a look to the topic contents:


```
➜  PG10 kafkacat -C -b localhost:9092 -qeJ -t AGGREGATIONS -X group.id=1  -o beginning
{"topic":"AGGREGATIONS","partition":0,"offset":0,"key":"","payload":"{\"f1\":\"2017-02-24T12:34:13.711732-03:00\",\"f2\":\"P1\",\"f3\":172}"}
{"topic":"AGGREGATIONS","partition":0,"offset":1,"key":"","payload":"{\"f1\":\"2017-02-24T12:34:13.711732-03:00\",\"f2\":\"P0\",\"f3\":140}"}
{"topic":"AGGREGATIONS","partition":0,"offset":2,"key":"","payload":"{\"f1\":\"2017-02-24T12:34:13.711732-03:00\",\"f2\":\"P2\",\"f3\":155}"}
```

With key set:

```
{"topic":"AGGREGATIONS","partition":0,"offset":3,"key":"127.0.0.1/32","payload":"\t{\"f1\":\"2017-02-24T12:40:39.017644-03:00\",\"f2\":\"P1\",\"f3\":733}"}
{"topic":"AGGREGATIONS","partition":0,"offset":4,"key":"127.0.0.1/32","payload":"\t{\"f1\":\"2017-02-24T12:40:39.017644-03:00\",\"f2\":\"P0\",\"f3\":994}"}
{"topic":"AGGREGATIONS","partition":0,"offset":5,"key":"127.0.0.1/32","payload":"\t{\"f1\":\"2017-02-24T12:40:39.017644-03:00\",\"f2\":\"P2\",\"f3\":716}"}
```


### Basic topic manipulation

The bellow commands are useful when using a fresh intalled Apache Kafka version.

Starting everything:

```
bin/zookeeper-server-start.sh config/zookeeper.properties 2> zookeper.log &
bin/kafka-server-start.sh config/server.properties 2> kafka.log &
```

Creating topics and others:

```sh
bin/kafka-topics.sh --list --zookeeper localhost:2181
bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 3 --topic PGSHARD
bin/kafka-topics.sh --delete  --zookeeper localhost:2181 --topic PGSHARD
bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 1 --partitions 1 --topic AGGREGATIONS
bin/kafka-topics.sh --delete  --zookeeper localhost:2181 --topic AGGREGATIONS
```

> NOTE: For deleting topics, you need to enable the `delete.topic.enable=true` in
> server.properties file.

Consuming with `kafkacat`:

```sh
kafkacat -C -b localhost:9092 -qeJ -t PGSHARD -X group.id=1  -o beginning
```

There is something useul and is that you can format the output on the fly as needed
with the `-f` option instead the `-J` (JSON output format). This could be pretty
useful for generating rows with specific column definitions.


---

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
[4]: http://www.3manuek.com/assets/posts/dosequis.jpg
