---
layout: post
title:  "[WIP] FDW overhead."
date:   2017-03-06
description: How much overhead is added by using Foreign Data Wrappers?
tags : [PostgreSQL, Sharding]
categories:
- PostgreSQL
category: blog
comments: true
permalink: fdwoverhead
author: 3manuek
---

*This article is WIP*

![Dosequis][10]


## Performance analysis of FDW overhead on intensive transaction workloads


Something to keep in mind is that the current implementation of `postgres_fdw`
under 9.6 (This was tested over **9.6.2** to be exact), has a considerable overhead
in the overall execution time.

The test was done exclusively on the same machine in two different instances,
for discarding any network biasing. One of the FDW connects from the same instance
(FDW_local) and the other from a different instance (FDW_external).

Keep also in mind, that `pgbench` does intensive transaction workload, which generally
is not well suitable for foreign tables.

From the tests taken, `postgres_fdw` show approximately a `.65x` of overhead compared with a
local table. Although, for read only transactions the overhead is higher, probably
related to the default transaction level used (`repeatable read`) as detailed in [FDW F.33.3][3].
For this reason, all the conducted tests have been done using this isolation level of
transaction, to make comparison fair (specially for read only workloads, wether
more scans are needed for keeping result consistency).

Also, I considered the TPS stats _including_ connections, as we are trying to consider
all the extension phases.


## RW overhead by TPS throughput

The estimated overhead between FDW and straight RW operations is a factor of `.65x`.
Considering that the tests were intensive, it is a very good number ([Fig. 1]).


## RO overhead by TPS throughput

The overhead for intensive read only workloads is significantly higher than RW: `6.7x`.

By executing FDW locally and externally, I observed that the external FDW had
more unstable TPS throughput, although the mean does no show a significant difference.

![TPS][1]{: class="bigger-image" }
<figcaption class="caption">[Fig. 1] TPS throughput.</figcaption>

`updatable` does not help at performance, as it only adds slightly more overhead
due the permissions check. `RO.FDW_ext_ro` adds the options at [Snippet 2] to each
FDW table.

![RO TPS][4]
<figcaption class="caption">[Fig. 1] RO TPS throughput with/without updatable option.</figcaption>


## Latency inspection

Is not a surprise to see a correlation when looking at the latency in milliseconds.
This can be seen clearly on the [Fig.2].

![TPS][2]
<figcaption class="caption">[Fig.2] Latency in ms.</figcaption>



## Aggregated data of the benchmarks

TPS:

|Bench  | Type   |    Target    |    Max   |     Min  |     Mean  
|-----|------|---|---|---|
|RO.FDW_external   |  RO |FDW_external | 1713.57 | 1387.70 | 1511.04
|RO.FDW_local   |  RO  |  FDW_local | 1557.38 | 1445.34 | 1482.65
|RO.local   |  RO    |   local |11717.88 |11131.27 | 11512.79
|RW.FDW_external   |  RW |FDW_external |  128.12 |  102.21  | 113.79
|RW.FDW_local  |   RW  |  FDW_local  | 146.00 |  135.73 |  139.72
|RW.local  |   RW     |   local  | 217.21|   203.58 |  209.49


Latency in ms:

|Bench  | Type   |    Target |  Max |  Min |  Mean
|---|---|---|---|---|
|RO.FDW_external   |  RO |FDW_external| 0.721 |0.584 |0.6642
|RO.FDW_local   |  RO  |  FDW_local| 0.692| 0.642 |0.6748
|RO.local  |   RO     |   local |0.090 |0.085 |0.0869
|RW.FDW_external  |   RW | FDW_external| 9.784 |7.805| 8.8521
|RW.FDW_local   |  RW  |  FDW_local |7.367 |6.849| 7.1598
|RW.local   |  RW  |      local |4.912 |4.604| 4.7748



## Reproducing the test

Populating _pgbench_ tables within an scale of 100:

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
