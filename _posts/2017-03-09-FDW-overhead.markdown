---
layout: post
title:  "postgres_fdw estimated overhead."
date:   2017-03-06
description: How much overhead is added by using postgres_fdw Foreign Data Wrappers?
tags : [PostgreSQL, Sharding]
categories:
- PostgreSQL
category: blog
comments: true
permalink: fdwoverhead
author: 3manuek
---


## Performance analysis of FDW overhead on intensive transaction workloads

The current benchmarks were run under PostgreSQL 9.6.2, in order to persuit an
estimation of the overhead of the `postgres_fdw` extension. For doing so I'd set
four databases in two different schemas in which `source` is the only database
storing pgbench's the data. Rest of the databases only hold the DDL of the foreign tables.
Both instances reside on the same machine in order to discard any network biasing
on the final results. One of the FDW connects from the same instance
(FDW_local) and the others from a different instance (FDW_external and FDW_ext_ro),
description at  the [reference anex](#Benchmark-reference).

Keep also in mind, that `pgbench` does intensive transaction workload, which generally
is not well suitable for foreign tables. So, the overhead is something expected
at this point.

From the tests taken, `postgres_fdw` show approximately a `.70x` of overhead compared with a
local table. Although, for read only transactions the overhead is much higher,
probably due to the effects of the forced transaction isolation used (`repeatable read`)
on FDW as detailed in [FDW F.33.3][3]. For this reason, **all the conducted tests have been
done using REPEATABLE READ isolation**, to make comparison fair (specially for read only workloads, wether
more scans are needed for keeping result consistency).

Also, I considered the TPS stats _including_ connections, as we are trying to consider
all the execution phases. It is important to note that `postgres_fdw` recycles connections
over the same session for each user mapping.  

## Notes

- If you are going to have intensive reads for key lookups, you may prefer to connect directly to
  the nodes.
- Consider the limitations at transaction isolation, as using FDW has a different
  behavior than the standard Postgres default (read committed).
- Network can add a considerable latency. If possible, database servers should
  communicate in fast and closed networks, in order to avoid any other extra noise.


## RW overhead by TPS throughput

The estimated overhead between FDW and straight RW operations is a factor of `.70x`.
Considering that the tests were intensive, it is a very good number ([Fig. 1]).


## RO overhead by TPS throughput

The overhead for intensive read only workloads is significantly higher than RW: `6.5x`.

By executing FDW locally and externally, I observed that the external FDW had
more unstable TPS throughput, although the mean does not show a significant difference.
In fact, through all the benchmarks I've done, there is a slightly more throughput
in the TPS mean when using FDW on a different instance over using the FDW locally.

![TPS][1]{: class="bigger-image" }
<figcaption class="caption">[Fig. 1] TPS throughput.</figcaption>

`updatable` does not help at performance, as it only adds slightly more overhead
due the permissions check. `RO.FDW_ext_ro` adds the options shown at [Snippet 2] to each
FDW table.

![RO TPS][4]
<figcaption class="caption">[Fig. 1] RO TPS throughput with/without updatable option.</figcaption>


## Latency inspection

Is not a surprise to see a correlation when looking at the latency in milliseconds.
This can be seen clearly on the [Fig.2].

![TPS][2]
<figcaption class="caption">[Fig.2] Latency in ms.</figcaption>


## Aggregated data of the benchmarks

TPS by RO and RW:

```
> subset(byBenchTPS, Type == "RO")
            Bench   Type       Target       Max       Min      Mean
1   RO.FDW_ext_ro     RO   FDW_ext_ro  1637.314  1402.255  1507.400
2 RO.FDW_external     RO FDW_external  1596.900  1413.704  1519.091
3    RO.FDW_local     RO    FDW_local  1570.985  1310.034  1476.397
4        RO.local     RO        local 11670.959 10981.858 11475.249

> subset(byBenchTPS, Type == "RW")
            Bench   Type       Target      Max      Min     Mean
1 RW.FDW_external     RW FDW_external 136.4827 110.6894 124.5781
2    RW.FDW_local     RW    FDW_local 145.5167 125.2096 133.1675
3        RW.local     RW        local 240.8039 205.6248 219.2062
```


## Reproducing the test

Populating _pgbench_ tables within a scale of 100:

```sh
/usr/lib/postgresql/9.6/bin/pgbench -p5434 -i -s100 source
```

Creating the schema on the databases from which the FDW are called (external, external_ro and localfdw):

[Snippet 1]

```sql
CREATE SERVER source_server FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS(host '127.0.0.1',port '5434',dbname 'source');

CREATE USER MAPPING FOR postgres SERVER source_server OPTIONS(user 'postgres');

-- New 9.6 feature!
IMPORT FOREIGN SCHEMA public LIMIT TO (pgbench_accounts,pgbench_history,
pgbench_branches,pgbench_tellers) FROM SERVER source_server INTO public ;
```

[Snippet 2] applied into `external_ro` database:

```sql
ALTER FOREIGN TABLE pgbench_accounts OPTIONS (updatable 'false');
ALTER FOREIGN TABLE pgbench_branches OPTIONS (updatable 'false');
ALTER FOREIGN TABLE pgbench_history OPTIONS (updatable 'false');
ALTER FOREIGN TABLE pgbench_tellers OPTIONS (updatable 'false');
```

Automating benchmarks and putting everything into CSV (Latency Average, TPS including connections
and TPS excluding connections):

```sh
PGBENCHBIN="/usr/lib/postgresql/9.6/bin/pgbench"
PGVACUUM="/usr/lib/postgresql/9.6/bin/vacuumdb -p5434 source"
$PGVACUUM
{ for i in $(seq 1 10) ; do  $PGBENCHBIN -p5434  -n -T10 source     | grep -Po '= \K[\d]+\.[\d]+' | paste -sd "," - ; done } > benchRW.local
$PGVACUUM
{ for i in $(seq 1 10) ; do  $PGBENCHBIN -p5434  -n -T10 localfdw   | grep -Po '= \K[\d]+\.[\d]+' | paste -sd "," - ; done } > benchRW.FDW_local
$PGVACUUM
{ for i in $(seq 1 10) ; do  $PGBENCHBIN -p5435  -n -T10 external   | grep -Po '= \K[\d]+\.[\d]+' | paste -sd "," - ; done } > benchRW.FDW_external
{ for i in $(seq 1 10) ; do  $PGBENCHBIN -p5434 -Sn -T10 source     | grep -Po '= \K[\d]+\.[\d]+' | paste -sd "," - ; done } > benchRO.local
{ for i in $(seq 1 10) ; do  $PGBENCHBIN -p5434 -Sn -T10 localfdw   | grep -Po '= \K[\d]+\.[\d]+' | paste -sd "," - ; done } > benchRO.FDW_local
{ for i in $(seq 1 10) ; do  $PGBENCHBIN -p5435 -Sn -T10 external   | grep -Po '= \K[\d]+\.[\d]+' | paste -sd "," - ; done } > benchRO.FDW_external
{ for i in $(seq 1 10) ; do  $PGBENCHBIN -p5435 -Sn -T10 external_ro   | grep -Po '= \K[\d]+\.[\d]+' | paste -sd "," - ; done } > benchRO.FDW_ext_ro
```

Hope you enjoyed the article!



## Benchmark reference

| Keyword | Description
|-----|-----
|RO | Read only tests
|RW | Read/writes tests
|FDW_ext_ro | External Foreign tables with `updatable` option.
|FDW_external | External Foreign tables
|FDW_local  | Local Foreign Tables (same postgres instance)





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

[1]: http://www.3manuek.com/assets/posts/tpsfdw.png
[2]: http://www.3manuek.com/assets/posts/latfdw.png
[3]: https://www.postgresql.org/docs/9.6/static/postgres-fdw.html
[4]: http://www.3manuek.com/assets/posts/tpsfdwro.png
[10]: http://www.3manuek.com/assets/posts/dosequis.jpg
