---
layout: post
title:  "How you can start MySQL Slow query analysis."
date:   2016-06-22
description: Tools and resources.
tags : [MySQL, SQL, tuning]
categories:
- MySQL
permalink: querydigestcomplements
---

## Objective of the article

This is not intended to be the ultimate guide for query analysis, it is just a simple starting guide for people that want to do so. If you want to start from something, I recommend you to start with [Effective MySQL: optimizing SQL Statements by Ronald Bradford](https://www.amazon.es/Effective-MySQL-Optimizing-Statements-Oracle/dp/0071782796).

Query analysis is pretty much valuated for consultants, as a good query analysis and application can _save money_. I saw customers buying new hardware just because _the MySQL was too slow_.

And -the most important- is not only about performance. A good query profiling can be a good diagnostic of the entire software architecture. Sometimes RDBMS are used for stuff that are not the best fit or, even NoSQLs were used when MySQL/Postgres can be a better fit.

Also, this article is not focus on SQL tricks or neither how to understand MySQL
explain, which I assume you already have some knowledge to continue the reading. A
very nice library to enjoy can be found at [Use the index, Luke!](http://use-the-index-luke.com/).


## The approach

First of all you need to know what the customer is literally doing in the server, which information and type of server they have online. This may be something pretty much _obvious_, but believe me, it is not trivial to repeat this.

A server could be part of a sharded cluster, a report server, a BI server, a web OLTP server, test server, and so on. Market impose those infinite combinations, however there are a few rules for good practice when writing queries. And those good practices will depend on the RDBMS you are working on (in this particular case, we will focus on MySQL).

Now, you know what you need to get and how think your analysis. Beyond query complexity, sometimes you need to know which solution can be applied or not when you rewrite the query or provide suggestions.

Generally, queries can be slow due to:

- Missing indexes
- Bad cardinality and not useful filters
- Inner joins with outer order using different keys
- File sorting  
- Bad writing queries (large subqueries, large IN clauses, non targeted bugs, i.e.)

Check the latest [bugs reported](https://bugs.mysql.com/search.php?cmd=display&status=Active&severity=-5&search_for=query&os=0&bug_age=0&order_by=bug_type&direction=ASC&limit=10&mine=0&reorder_by=bug_type).

## How much do you need to collect?

For a query analysis you want to collect _as much as you can_:

- general query log, or
- `long_query_time` = 0 or,
- tcpdump

Using others will lead to non-complete profiling when processing. However, there are cases where is not possible to have the `long_query_time = 0` due to the high amount of TPS (_Transactions Per Second_). You can set it to `0.5` or higher. The closer to 0, the better.

You will collect the whole set of queries. You are not hunting _slow queries_ but also _very frequent queries_. I did have cases where the issue was not regarding any slow query, but an application bug doing 2x the same query. Also you will be probably hunting buggy queries, with unnecessary large result sets, suspicious orders, bad FTS usage, slow procedures, etc.

Generally, when analyzing BI or reporting servers, it is accepted to have a large `long_query_time`, as you will probably focusing on slow queries.

### Percona enhancements to be aware of

[Slow log extended](https://www.percona.com/doc/percona-server/5.7/diagnostics/slow_extended.html) options add extra verbosity to the slow log.

The option is `log_slow_verbosity` and it has several options. Just keep in mind that `full` does not include `profiling` neither `profiling_use_getrusage`. I assume that you don't need to enable profiling just the first time you run a query review. It will interesting to enable the full query collection if using [Percona Playback](https://www.percona.com/doc/percona-playback/index.html).

## [pt-query-digest](https://www.percona.com/doc/percona-toolkit/2.2/pt-query-digest.html#cmdoption-pt-query-digest--review) is your friend

`pt-query-digest` can be used with an impressive set of options. Before you use it, I encourage the reader to do a quick read over its documentation.

For example, you can gather not only the report but also the explains of the queries safely (that is, if a query has a subquery, it won't execute the query on the master).

```
pt-query-digest --type=slowlog --report-all --explain h=172.17.0.2 --user=root --password=mysql /var/lib/docker/volumes/ceda51de62dac317fcafe9dd9e8f9b6f1dc5d70874466b3faf7cdfbcbbc91154/_data/cb740be0743c-slow.log > /tmp/report.txt
```


## Examining the query results

- Rows examined vs. rows returned
- The order of the result
- Does the application uses the full set of rows? Limit the number of rows as much as possible



## Other complementary tools

### [Anemometer](https://github.com/box/Anemometer)

If you have a large fleet of MySQL servers and you usually do query analysis, the _next tool_ you want to look is [Anemometer](https://github.com/3manuek/Anemometer).Originally, this project has been made by Box, however if you want to test the vagrant machine, I suggest to use the fork linked above. The project looks like stable and they are not merging new pull requests. It just works.

The idea was to have available in a single glance the slow logs, which can become very handy when scaling complex boxes. Also it improves proactive monitoring and partial trending.


### [binlogEventStats](https://github.com/pythian/binlogEventStats)

The idea is to do a _top style_ metrics of the  streamed transactions from the replication flow in a more detailed way, so you can see the writes from a master (ideally to trace/debug slave lags). This is not entirely related with Query Reviews generally, however it could be a detection tool when some unexpected floods happen.

> Note: Is still in development.


## The main parts of the `pt-query-digest`

- Overall stats (useful for general comparisons)
- Profile: Query by ranking in terms of execution time.
- Queries: Each query with execution details.

### Where do I start analyzing?

The general rule of the thumb is start by the heaviest down to the others. I would
say that it depends on how much time you want to waste and the complexity of the queries.

My recommendation is to do the queries that consume more than 40-50% of accumulated execution time on BI servers
and 50-70% when it is an OLTP workload.

Once you do a first query review, the subsequent analysis will not be very useful if no
changes are applied on the queries.  

### Get the table details

How to execute the SHOWS in the `pt-query-digest`:

```bash
egrep "SHOW.[TABLE|CREATE].*" /tmp/report.txt | sed 's/^#\s*//' | sed 's/\\/\\\\/g' | sort | uniq | sed "s/'/\\\'/g" | xargs -i mysql --user=mysql --password=SHADOW -e {} > /tmp/SHOW.txt
```

As a rule, the rewritten query should return the same amount of records and order, unless
your recommendation specifies that the current result set size or order are not
convenient. i.e. very large result sets with a lot of discarded rows from the application,
a query that is returning an incorrect order, etc.


## Comparing the before and after

Finally, once changes have been made (any change)

- Same interval of time and day use ( `--since` and `--until` options ).
- `--review` option will help you to do incremental analysis.
- TPS before and after.
- Overall Execution time make easier the job of comparing the effectiveness of the changes.
- Use always the same `long_query_time` on both.
