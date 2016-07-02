---
layout: post
title:  "MySQL Slow query analysis tools and sources"
date:   2016-06-22
description: Additional usage and recommendations for pt-query-digest.
tags : [MySQL, SQL, tuning]
categories:
- MySQL
permalink: querydigestcomplements
---

## Objective of the article

This is not intended to be the ultimate guide for query analysis, it is just a simple starting guide for people that want to do so. If you want to start from something, I recommend you to start with [Effective MySQL: optimizing SQL Statements by Ronald Bradford](https://www.amazon.es/Effective-MySQL-Optimizing-Statements-Oracle/dp/0071782796). 

Query analysis is pretty much valuated for consultants, as a good query analysis and application can _save money_. I saw customers buying new hardware just because _the MySQL was too slow_.

And -the most important- is not only about performance. A good query profiling can be a good diagnostic of the entire software architecture. Sometimes RDBMS are being used for stuff that is not the best fit or, even NoSQLs were used when MySQL/Postgres can be a better fit.


## From scratch to something

Slow query analysis isn't black magic. We are lucky enough to have pretty good tools for it. However, I've seen people systematically failing to deliver a well understood analysis of a server profiling.
  

## The approach

First of all you need to know what the customer is literally doing in the server, which information and type of server they have online. This may be something pretty much _obvious_, but believe me, it is not trivial to repeat this. 

A server could or not, be part of a sharded cluster, could be a report server, could be a BI server, could be a web OLTP server, test, and I can continue with the infinite combinations that the market can need.

Now, you know what you need to get and how think your analysis. Is not the same to profile a sharded server than a reporting server, ie. Beyond query complexity, sometimes you need to know which solution can be applied or not when you rewrite the query or provide suggestions.

Generally, queries can be slow due to:

- Missing indexes
- Bad cardinality and not useful filters
- Inner joins with outer order using different keys
- File sorting  
 
## `long_query_time` 0 or 

For a query analysis you want:

- general query log
- `long_query_time` = 0

Using others will lead to non-complete profiling when processing. However, there are cases where is not possible to have the `long_query_time = 0` due to the high amount of queries and activity. You can set it to `0.5` or higher. The closer to 0, the better.

You will collect the whole set of queries. You are not hunting _slow queries_ but also  _very frequent queries_. I did have cases where the issue was not regarding any slow query, but an application bug doing 2x the same query.


## [pt-query-digest](https://www.percona.com/doc/percona-toolkit/2.2/pt-query-digest.html#cmdoption-pt-query-digest--review) is your friend


## Examining the query results

- Rows examined vs. rows returned
- The order of the result
- Does the application uses the full set of rows? Limit the number of rows as much as possible


## Rewriting a query



How to execute the SHOWS in the `pt-query-digest`:

```bash
egrep "SHOW.[TABLE|CREATE].*" /tmp/report.txt | sed 's/^#\s*//' | sed 's/\\/\\\\/g' | sort | uniq | sed "s/'/\\\'/g" | xargs -i mysql --user=mysql --password=SHADOW -e {} > /tmp/SHOW.txt
```


## Other complementary tools 

### [Anemometer](https://github.com/box/Anemometer)

If you have a large fleet of MySQL servers and you usually do query analysis, the _next tool_ you want to look is [Anemometer](https://github.com/3manuek/Anemometer).Originally, this project has been made by Box, however if you want to test the vagrant machine, I suggest to use the fork linked above. The project looks like stable and they are not merging new pull requests. It just works. 

The idea was to have available in a single glance the slow logs, which can become very handy when scaling complex boxes. Also it improves proactive monitoring and partial trending.


### [binlogEventStats](https://github.com/pythian/binlogEventStats) 

The idea is to do a _top style_ metrics of the  streamed transactions from the replication flow in a more detailed way, so you can see the writes from a master (ideally to trace/debug slave lags). This is not entirely related with Query Reviews generally, however it could be a detection tool when some unexpected floods happen.

> Note: Is still in development.



## Comparing the before and after

Finally, once changes have been made (any change)

- Same interval of time and day. --since and --until options will help you to speficy this. --review option will help you to do incremental analysis.
- TPS
- Execution time
- Same `long_query_time`.


## References

I used to MySQL Sandbox for testing, but this time I ran into issues with the last Percona 5.7.12 version when starting the instance. So, I used the Docker version. 

Here is the all what you need to do:

```bash
docker run --name percona57 -e MYSQL_ROOT_PASSWORD=mysql  -d percona:5.7 --general-log=1 --slow-query-log=1 --long-query-time=0 
```

--log-driver=syslog --log-opt syslog-address=/var/lib/mysql/4f1e1ad06dac-slow.log

docker run --name percona57  -v /var/log/mysql:/var/log/mysql  -e MYSQL_ROOT_PASSWORD=mysql  -d percona:5.7 --general-log=1 --slow-query-log=1 --long-query-time=0 

```
3laptop ~ # ls /var/lib/docker/volumes/21038cd30471474ece3e10b25293491d0acfd990c23d825711378c7ac0d4c311/_data
35334e3ece57.log       auto.cnf    ca.pem           client-key.pem  ibdata1      ib_logfile1  mysql               private_key.pem  server-cert.pem  sys
35334e3ece57-slow.log  ca-key.pem  client-cert.pem  ib_buffer_pool  ib_logfile0  ibtmp1       performance_schema  public_key.pem   server-key.pem   xb_doublewrite
3laptop ~ # docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED              STATUS              PORTS               NAMES
35334e3ece57        percona:5.7         "docker-entrypoint.sh"   About a minute ago   Up About a minute   3306/tcp            percona57
```

Get mounts:

```
3laptop ~ # docker inspect percona57 | jq .[].Mounts
[
  {
    "Propagation": "",
    "RW": true,
    "Mode": "",
    "Driver": "local",
    "Destination": "/var/lib/mysql",
    "Source": "/var/lib/docker/volumes/21038cd30471474ece3e10b25293491d0acfd990c23d825711378c7ac0d4c311/_data",
    "Name": "21038cd30471474ece3e10b25293491d0acfd990c23d825711378c7ac0d4c311"
  },
  {
    "Propagation": "rprivate",
    "RW": true,
    "Mode": "",
    "Destination": "/var/log/mysql",
    "Source": "/var/log/mysql"
  }
]

```


More information [here](https://hub.docker.com/_/percona/).

```bash
3laptop ~ # docker network ls
NETWORK ID          NAME                DRIVER
5fddd2e1a80a        bridge              bridge              
e4e0c655e1aa        host                host                
565f4a23d95a        none                null    

3laptop ~ # docker network inspect 5fddd2e1a80a
[
    {
        "Name": "bridge",
...
        "Containers": {
            "118b5dc41e7e693c65b407e0c2636e5024859ec28c96f165673d3e7bffe8475d": {
                "Name": "percona57",
                "EndpointID": "cf09eb5ee7edf298813729cd5323b84eb5c307a6feae67a51d260ae5d6c9366a",
                "MacAddress": "02:42:ac:11:00:02",
                "IPv4Address": "172.17.0.2/16",
                "IPv6Address": ""
            }


3laptop ~ # mysql -h 172.17.0.2 -p
....
mysql> 

```

Logs:

```
root@4f1e1ad06dac:/# ls /var/lib/mysql/4f1e1ad06dac*
/var/lib/mysql/4f1e1ad06dac-slow.log  /var/lib/mysql/4f1e1ad06dac.log
```

