---
layout: post
title:  "Import data from Redshift into Clickhouse in a single command."
date:   2017-03-06
description: Importing and explaning the process
tags : [Redshift, Clickhouse]
categories:
- Redshift
- Clickhouse
- Analytics
category: blog
comments: true
permalink: redshiftclickhouse
author: 3manuek
---


## Scope 

If you heard about Clickhouse and you are wondering how
to test with your residing data in Redshift, here is a command
that will show you a few tips to make you speed up.

The standard wat to move your data out of Redshift is by using [UNLOAD](http://docs.aws.amazon.com/redshift/latest/dg/r_UNLOAD.html) command,
which pushes the output into S3 files. Not surprisingly, Redshift does not support
`COPY (<query>) TO STDOUT`, which could make life easier (as it 
Postgres version 8.0.2 based, quite ol'). Info about this, [here](http://docs.aws.amazon.com/redshift/latest/dg/r_COPY.html).

Clickhouse supports several engines but so far, you will for
sure start with MergeTree. The supported types are more finite,
although they should be enough for plain analytics. At table
creation, I will recommend to add sampling support which is added 
in the engine parameters through any hash function returning unsigned integers after the key definition.
In this case I've choosen cityHash64 as it is not cryptographic 
, it has a decent accuracy and better performance.  

The table in CH is the following:

```sql
CREATE TABLE thenewdb.thetable (
normdate Date,
id String,
datefield DateTime,
(... many others ...)
data String
)
ENGINE = MergeTree(normdate,cityHash64(id), (datefield, id,cityHash64(id)),8192);
```

> NOTE: The engine parameters are: a date column, the optional sampling expression (cityHash64)
> the primary key (datefield,id) and the index granularity.


The table in Redshift is:

```sql
     Column     |            Type             | Modifiers
----------------+-----------------------------+-----------
 id             | character varying(32)       | not null
 datefield      | timestamp without time zone | not null
 (... other columns...)
  data           | character varying(8192)     |
Indexes:
    "thetable_pkey1" PRIMARY KEY, btree (id)
```

As you may see, there is an additional column in CH. The reason
is that in Clickhouse is a requirement to have a Date column
defined as explained in the note above. For more information,
check out the [MergeTree doc](https://clickhouse.yandex/reference_en.html#MergeTree).


## The magic

- Open a screen/ tmux session.

- Execute the command:

```bash
time psql -h rs1.garbagestring.redshift.amazonaws.com \
          -p 5439 -U redshift thedatabase \
          -Antq --variable="FETCH_COUNT=1000000" -F $'\t' <<EOF | \
          clickhouse-client --database thenewdb --query="INSERT INTO thenewdb.thetable FORMAT TabSeparated"
select trunc(datefield),
  id,
  datefield::timestamp(0) ,
  store_id ,
(... many columns more ... )
  regexp_replace(data,'\\t|\\n','') 
from theoriginaltable
EOF
```

## Amount of RAM needed and calculation 

`MergeTree` engine is indeed an interesting implementation. Is not an LSM as it
does not process in _memtables_. It already process the data in batches and write
directly to the file system. This consumes a significant amount of RAM at the cost
of saving disk operations by background workers that do the merges.


A common error when you run out of memory due to this merge processes eating RAM is:

```
Code: 240. DB::Exception: Allocator: 
Cannot mremap., errno: 12, strerror: Cannot allocate memory
```

The reason on why this happens is due to the RAM consumed on background merges.
There are five elements to have in mind to calculate the needed memory:

- `background_pool_size` is 6, determining the maximum number of background merges.
- Maximum number of merge pieces during merge (default 100)
- block size for the merger (8192 rows)
- average size of row uncompressed
- maximum overhead memory allocation for buffers (2)

You can assume a row size of 1024 bytes and multiply all of the above
together. i.e. `SELECT formatReadableSize( 2* 6 * 100 * 8192 * 1024);`

The current issue is that the merge algorithm process by row instead each
column separately, and is expected to have a performance gain. 

So, guessing that you get a row size of `13557 bytes (14k)` using query 1),
you can get an approximate of RAM needed for the block of operations 2).

1)

```
time psql -h rs-clusterandhash.us-east-1.redshift.amazonaws.com           -p 5439 -U redshift reportdb  -Antq --variable="FETCH_COUNT=1000000" -F $'\t' <<EOF | wc -c
select
  *
from big_table
LIMIT 1
EOF
13835
```

2) 
```
SELECT formatReadableSize((((2 * 6) * 100) * 8192) * 13557)
┌─formatReadableSize(multiply(multiply(multiply(multiply(2, 6), 100), 8192), 13557))─┐
│ 124.12 GiB                                                                         │
└────────────────────────────────────────────────────────────────────────────────────┘
```
 
More information on this [google groups thread](https://groups.google.com/forum/#!topic/clickhouse/SLlMNwIOtmY).


Unfortunately, client can't handle this properly yet. Even limiting the memory usage
with `--max_memory_usage 5GB` (i.e), you will get a different error like this:

```
Code: 241. DB::Exception: 
Received from localhost:9000, 127.0.0.1. 
DB::Exception: Memory limit (for query) exceeded: 
would use 1.00 MiB (attempt to allocate chunk of 1048576 bytes), maximum: 5.00 B.
```

If the necessary RAM is very close to your current resource, a possible solution would be using `ReplacingMergeTree` engine, 
but deduplication is not warranted and indeed you will play in very small limits (you should be 
very close to the above calculation).
Also, there are several settings at engine level for tuning the mergetree engine through configuration
at [MergeTreeSettings.h](https://github.com/yandex/ClickHouse/blob/9de4d8facb412fa178cd8380a4411c30da43acc7/dbms/src/Storages/MergeTree/MergeTreeSettings.h)

i.e., the bellow will reduce the RAM consumption considerably:
 
```
    <merge_tree>
        <max_suspicious_broken_parts>20</max_suspicious_broken_parts>
        <enable_vertical_merge_algorithm>1</enable_vertical_merge_algorithm>
        <max_delay_to_insert>5</max_delay_to_insert>
        <parts_to_delay_insert>100</parts_to_delay_insert>
    </merge_tree>
```


## The explanation

- Why TabSeparated?

Clickhouse offers several [formats](https://clickhouse.yandex/reference_en.html#Formats), a lot.
Even tho, the tab in this case seemed enough for importing plain
texts (until a magic JSON with tabs and newlines broke the import).

- Why casting with no microseconds `::timestamp(0)`?

CH does not support microseconds.  

- Why doing replace `regexp_replace(data,'\\t|\\n','')`?

We are importing using TSV, which by standard it does not
support newlines and obviously, tabs. Unfortunately, is 
not possible at the moment to use enconding/decoding using
base64 for inserting without replacing (by inserting the
data encoded). 

- Why `--variable="FETCH_COUNT=1000000"`?

This is the sauce. `psql` will try to place the whole result
set in memory, making the box explode within a few minutes
after start running. Within this, it creates a server-side cursor, allowing us to import result set bigger than the client
machine.

- Why `-F $'\t'`?

Depending on your shell, you may consider [this](https://www.postgresql.org/message-id/455C54FE.5090902@numerixtechnology.de). You need to use a _literal tab_, 
which means that it needs to be the character itself. On UNIX
`Ctrl-V tab` should do the thing.

You can do a small try abuot this with `echo`. The option `-e`
_enables the interpretation of backslash escapes_.


```bash
ubuntu@host:~$ echo $'\n'


ubuntu@host:~$ echo '\n'
\n
ubuntu@host:~$ echo -e '\n'


```

## Rogue numbers

The process itself is consirably fast: it moved a 150GB
table into a Clickhouse MergeTree of around 11GB (_wow
such compression much wow_ ) in 20 minutes. 

Instance details for RS: dc1.large 15GB RAM, vCPU 2, 2 nodes
Instance CH: single EC2 r4.2xlarge, volume 3000 iops EBS

I hope you find this tip  useful!
