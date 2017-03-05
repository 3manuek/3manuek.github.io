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

The test was done exclusively on the same machine in different Postgres instances, for discarding any network biasing.

Keep also in mind, that `pgbench` does intensive transaction workload, which generally
is not suitable for foreign tables.


![TPS][1]{: class="bigger-image" }
<figcaption class="caption">TPS.</figcaption>

![TPS][2]{: class="bigger-image" }
<figcaption class="caption">Latency in ms.</figcaption>



## Reproducing the test

Populating _pgbench_ tables:
```sh
/usr/lib/postgresql/9.6/bin/pgbench -p5434 -i -s100 source
```

Creating the schema on the databases from which the FDW are called (external and localfdw):

```sql
CREATE SERVER source_server FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS(host '127.0.0.1',port '5434',dbname 'source');

CREATE USER MAPPING FOR postgres SERVER source_server OPTIONS(user 'postgres');

-- New 9.6 feature!
IMPORT FOREIGN SCHEMA public LIMIT TO (pgbench_accounts,pgbench_history,
pgbench_branches,pgbench_tellers) FROM SERVER source_server INTO public ;
```

Automating benchmarks and putting everything into CSV (Latency Average, TPS including connections
and TPS excluding connections):

```
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
```

Hope you ejoyed the article!


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
[10]: http://www.3manuek.com/assets/posts/dosequis.jpg
