---
layout: post
title:  "Playing with Postgres and Kafka."
date:   2017-02-28
description: Using the dirty way.
tags : [PostgreSQL, Kafka]
categories:
- PostgreSQL
- Kafka
category: blog
comments: true
permalink: kafkacatandcopypg
author: 3manuek
---



## Apache Kafka and Postgres: Transaction and reporting capabilities


[Apache Kafka][5] is a well known distributed streaming platform for data processing
and consistent messaging. It allows you to consistently centralize data streams for
several purposes by consuming and producing them. 

One of the examples of a nice implementation, is the [Mozilla's Data pipeline implementation][6],
particularly as it shows Kafka as an entry point of the data flow. This allows you to plug
new data stores bellow its stream, making it easy to use different data store formats (
such as DRBMS or Document, etc. ) for retrieving and writing data efficiently. 

[Postgres Bottled water][3] is a different approach that deserves a mention. In this
case, Postgres instances are the producers, brokers consume the streams and keep the message
store available for any action. The advantage here is the well known Postgres'
ACID capabilities, combined with advanced SQL features. This project is an extension,
meaning that is possible to use new upcoming Postgres features easily portable.

It is possible also, to consume and produce data to a broker by using a new feature
that extended the COPY tool for executing shell commands for input/output operations.
A nice highlight of this feature can be read [here][7].


![POC Image][9]
<figcaption class="caption">Apache Kafka logo.</figcaption>


## kafkacat and librdkafka

[kafkacat][1] is a tool based on the same author's library [librdkafka][2] which
does exactly what its name says: produce and consume from a Kafka broker like `cat`
command.


## Producing to Kafka broker

Producing fake data to the Kafka broker, composed by `key` and `payload`:

```sh

# Random text
randtext() {cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1}
while (true) ;
  do
    for i in $(seq 1 50)  
      do echo "$(uuidgen);$(randtext)"
     done  | kafkacat -P -b localhost:9092 -qe -K ';' -t PGSHARD
     sleep 10
  done
```

`-K` option defines the delimiter between the _key_ and the _payload_, `-t` defines
the topic you want to produce for. Originally, this topic has been created with 3
partitions (0-2), which will allow us to consume data in different channels, opening
the door for parallelization.  

_Keys_ aren't mandatory when producing to a broker, and actually for certain solutions
you can omit it.

## Consuming and Producing inside a Postgres instance

The general syntax will be something close as:

```sql
COPY main(group_id,payload)
  FROM PROGRAM
  'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o beginning  -p 0 | awk ''{print "P0\t" $0 }'' ';
```

Code piping to an `awk` is not strictly necessary and it is only for showing the
flexibility of the feature. When using the option `-J`, the output will be printed
in json format, containing all the message information, including partition, key and
message.

`-c` option will limit the amount of rows in the operation. As COPY is transactional,
be aware that the higher is the amount of rows, the larger will be the transaction and
COMMIT times will be affected.


### Consuming topics incrementally


Consuming the topic partitions from the `beginning` and setting a limit of `100`
documents is easy as:

```sh
bin/psql -p7777 -Upostgres master <<EOF
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o beginning  -p 0 | awk ''{print "P0\t" \$0 }'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o beginning  -p 1 | awk ''{print "P1\t" \$0 }'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o beginning  -p 2 | awk ''{print "P2\t" \$0 }'' ';
EOF
```

And then using `stored`, in order to consume from the last offset consumed by the
consumer on the group:

```sh
bin/psql -p7777 -Upostgres master <<EOF
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o stored  -p 0 | awk ''{print "P0\t" \$0 }'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o stored  -p 1 | awk ''{print "P1\t" \$0 }'' ';
COPY main(group_id,payload) FROM PROGRAM 'kafkacat -C -b localhost:9092 -c100 -qeJ -t PGSHARD  -X group.id=1  -o stored  -p 2 | awk ''{print "P2\t" \$0 }'' ';
EOF
```

Each COPY line, can be executed in parallel in different Postgres instances, making
this approach flexible and easy scalable across a board of servers.

This is not entirely consistent, as once the offset is consumed, will be marked
in the broker, wether if transaction fails at Postgres side can potentially lead
to data missing.


### Producing messages out the Postgres instances

The same way is possible to consume changes, it is possible to do the same for producing
data to the broker. This can be incredibly useful for micro aggregations, done over the
consumed raw data from the broker.

The bellow example shows how to run a simple query with a very simplistic aggregation
and publish it in JSON format to the broker:


```
master=# COPY (select row_to_json(row(now() ,group_id , count(*))) from main group by group_id)
         TO PROGRAM 'kafkacat -P -b localhost:9092 -qe  -t AGGREGATIONS';
COPY 3
```

If you have a farm of servers and want to search the topic contents using a key,
you can do the following tweak:

```
COPY (select inet_server_addr() || ';', row_to_json(row(now() ,group_id , count(*))) from main group by group_id)
   TO PROGRAM 'kafkacat -P -K '';'' -b localhost:9092 -qe  -t AGGREGATIONS';
```


This is how the published payloads look like (without _key_):

```
➜  PG10 kafkacat -C -b localhost:9092 -qeJ -t AGGREGATIONS -X group.id=1  -o beginning
{"topic":"AGGREGATIONS","partition":0,"offset":0,"key":"","payload":"{\"f1\":\"2017-02-24T12:34:13.711732-03:00\",\"f2\":\"P1\",\"f3\":172}"}
{"topic":"AGGREGATIONS","partition":0,"offset":1,"key":"","payload":"{\"f1\":\"2017-02-24T12:34:13.711732-03:00\",\"f2\":\"P0\",\"f3\":140}"}
{"topic":"AGGREGATIONS","partition":0,"offset":2,"key":"","payload":"{\"f1\":\"2017-02-24T12:34:13.711732-03:00\",\"f2\":\"P2\",\"f3\":155}"}
```

... and with _key_:

```
{"topic":"AGGREGATIONS","partition":0,"offset":3,"key":"127.0.0.1/32","payload":"\t{\"f1\":\"2017-02-24T12:40:39.017644-03:00\",\"f2\":\"P1\",\"f3\":733}"}
{"topic":"AGGREGATIONS","partition":0,"offset":4,"key":"127.0.0.1/32","payload":"\t{\"f1\":\"2017-02-24T12:40:39.017644-03:00\",\"f2\":\"P0\",\"f3\":994}"}
{"topic":"AGGREGATIONS","partition":0,"offset":5,"key":"127.0.0.1/32","payload":"\t{\"f1\":\"2017-02-24T12:40:39.017644-03:00\",\"f2\":\"P2\",\"f3\":716}"}
```


## Basic topic manipulation

If you are new into Kafka, you will find useful to count with a few command examples
to play with your local broker.

Starting everything:

```sh
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


Hope you find this useful!


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
[5]: https://kafka.apache.org/
[6]: https://robertovitillo.com/2017/01/23/an-overview-of-mozillas-data-pipeline/
[7]: http://paquier.xyz/postgresql-2/postgres-9-6-feature-highlight-copy-dml-statements/
[9]: http://www.3manuek.com/assets/posts/kafka.jpg
