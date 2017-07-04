---
layout: post
title:  "Clickhouse sampling on MergeTree engine."
date:   2017-07-01
description: What you need to know about.
tags : [Clickhouse]
categories:
- Clickhouse
- Analytics
- Sampling
category: blog
comments: true
permalink: clickhousesample
author: 3manuek
---

## Why sampling is important and what you need to be aware of?

When dealing with very large amount of data, you probably want to run your 
queries only for a smaller dataset in your current tables. Specially if your dataset
is not fitting in RAM.

`MergeTree` is the first and more advanced engine on Clickhouse that you want to try.
It supports indexing by Primary Key and it is mandatory to have a column of `Date`
type (used for automatic partitioning).

Is the only engine that supports sampling, and only _if the sampling expression was defined
at table creation_. So, the rul of the thumb is that **if the dataset does not fit in RAM you will prefer to
create the table with sampling support**. Otherwise, **there is no performance gain by using sampling
on relatively small tables that fit in RAM**.

Sampling expression uses a hash function over a chosen column in order to generate pseudo randomly
data on each of the selected columns defined in the primary key. Then you can enable this feature by accesing
the data using the SAMPLE clause in the query. 

Values of aggregate functions are not corrected automatically, so to get an approximate result, 
the value ‘count()’ is manually multiplied by the factor of the sample. For instance, a sample
of 0.1 (10%) will need to be multiplied by 10, 0.2 will need to be multiplied by 5.

Suppose we have the 96MM rows in a distributed table, split in 2 shards:

```sql
SELECT count(*)
FROM database_report.stats_table_distributed

┌──count()─┐
│ 96414151 │
└──────────┘
1 rows in set. Elapsed: 0.026 sec. Processed 96.41 million rows, 192.83 MB (3.68 billion rows/s., 7.36 GB/s.)
```

If you use `SAMPLE > 100`, you'll probably get some dirty results, specially if you execute over
a distributed umbrella. In the bellow example is possible to see that the SAMPLE is over each
local table and aggregated later locally (there are 2 shards):

```sql
SELECT count(*)
FROM database_report.stats_table_local
SAMPLE 1000
┌─count()─┐
│    1015 │
└─────────┘
1 rows in set. Elapsed: 1.296 sec. Processed 48.21 million rows, 2.07 GB (37.18 million rows/s., 1.60 GB/s.)


SELECT count(*)
FROM database_report.stats_table_distributed
SAMPLE 1000
┌─count()─┐
│    2032 │
└─────────┘
1 rows in set. Elapsed: 1.256 sec. Processed 96.41 million rows, 4.15 GB (76.75 million rows/s., 3.30 GB/s.)
```

Instead, by using the relative coefficient format, the aggregations are more accurate/consistent in terms of total rows
gathered, although you'll need to fix the estimation depending on the coefficient:

```sql

SELECT 
    count(*) AS count_over_sample,   -- Without fixing, we have x10 less rows
    count(*) * 10 AS count_estimated -- By 10 as we are sampling 10% of the table
FROM database_report.stats_table_distributed
SAMPLE 1 / 10

┌─count_over_sample─┬─count_estimated─┐
│           9641965 │        96419650 │
└───────────────────┴─────────────────┘
1 rows in set. Elapsed: 1.442 sec. Processed 96.41 million rows, 4.15 GB (66.84 million rows/s., 2.87 GB/s.)
```

The path of the execution on sampling can be seen in the following animation:


<div style="position:relative;height:0;padding-bottom:75.0%"><iframe src="https://www.youtube.com/embed/ah9sXSnMTcQ?ecver=2" width="480" height="360" frameborder="0" style="position:absolute;width:100%;height:100%;left:0" allowfullscreen></iframe></div>


## Hasing functions for sampling Int and Strings

You have several hashing functions (intHash32 for integers and cityHash64 for strings) although
you may stick with those non-cryptographic in order to don't affect the performance.

Example without sampling support: `MergeTree(EventDate, (CounterID, EventDate), 8192)`

Example with sampling support: `MergeTree(EventDate, intHash32(UserID), (CounterID, EventDate, intHash32(UserID)), 8192)`

The examples on this article use cityHash64, as the id is a `String`. Also the distribution
is random, in order to warrante the parallelization of the queries:

```sql
CREATE TABLE database_report.stats_table_local ( ...)
ENGINE = MergeTree(normdate, cityHash64(id), (created_at, id, cityHash64(id)), 8192);   

CREATE TABLE database_report.stats_table_distributed AS database_report.stats_table_local 
ENGINE = Distributed(database_report, database_report, stats_table_local, rand());
```

## Handling accuracy properly

Here is another example when gathering aggregations over sampling. The bellow statement 
is a non-sampled query:


```sql
SELECT DISTINCT 
    address,
    count(*)
FROM database_report.stats_table_distributed
GROUP BY address
HAVING count(*) > 500000
ORDER BY count(*) DESC

┌─address─────────┬─count()─┐
│ 10.0.1.222      │ 7431672 │
│ 1.3.2.1         │ 4727411 │
│ 104.123.123.198 │ 2377910 │
│ 10.0.20.110     │ 2366481 │
│ 10.0.5.6        │ 1852113 │
│ 12.1.2.4        │ 1413009 │
│ 54.84.210.50    │ 1141153 │
│ 63.138.62.1     │  950598 │
│ 10.1.0.11       │  738150 │
│ 10.0.1.15       │  709582 │
│ 90.110.131.100  │  601535 │
│ 65.30.67.32     │  584043 │
└─────────────────┴─────────┘
12 rows in set. Elapsed: 1.668 sec. Processed 96.41 million rows, 2.04 GB (57.79 million rows/s., 1.23 GB/s.)
```

But, if we sample without fixing the aggregations: 

```sql
SELECT DISTINCT 
    address,
    count(*)
FROM database_report.stats_table_distributed
SAMPLE 1 / 10
GROUP BY address
HAVING count(*) > 500000
ORDER BY count(*) DESC

┌─address────────┬─count()─┐
│ 10.0.0.222     │  744235 │
└────────────────┴─────────┘
1 rows in set. Elapsed: 2.127 sec. Processed 96.41 million rows, 6.00 GB (45.32 million rows/s., 2.82 GB/s.)
```

You can add some fixing around and increase the sample in order to get more accurate results:

```sql
SELECT DISTINCT 
    address,
    count(*) * 10
FROM database_report.stats_table_distributed
SAMPLE 1 / 10
GROUP BY address
HAVING (count(*) * 10) > 500000
ORDER BY count(*) DESC

┌─address─────────┬─multiply(count(), 10)─┐
│ 10.0.1.222      │               7442350 │
│ 1.3.2.1         │               4725650 │
│ 104.123.123.198 │               2381920 │
│ 10.0.20.110     │               2363170 │
│ 10.0.5.6        │               1856500 │
│ 12.1.2.4        │               1413860 │
│ 54.84.210.50    │               1141190 │
│ 63.138.62.1     │                954630 │
│ 10.1.0.11       │                739530 │
│ 10.0.1.15       │                712970 │
│ 90.110.131.100  │                604510 │
│ 65.30.67.32     │                583320 │
└─────────────────┴───────────────────────┘
12 rows in set. Elapsed: 2.134 sec. Processed 96.41 million rows, 6.00 GB (45.17 million rows/s., 2.81 GB/s.)

SELECT DISTINCT 
    address,
    count(*) * 5
FROM database_report.stats_table_distributed
SAMPLE 2 / 10
GROUP BY address
HAVING (count(*) * 5) > 500000
ORDER BY count(*) DESC

┌─address─────────┬─multiply(count(), 5)─┐
│ 10.0.1.222      │              7430545 │
│ 1.3.2.1         │              4730535 │
│ 104.123.123.198 │              2378665 │
│ 10.0.20.110     │              2364765 │
│ 10.0.5.6        │              1854600 │
│ 12.1.2.4        │              1412980 │
│ 54.84.210.50    │              1142130 │
│ 63.138.62.1     │               952105 │
│ 10.1.0.11       │               740335 │
│ 10.0.1.15       │               709805 │
│ 90.110.131.100  │               603960 │
│ 65.30.67.32     │               582545 │
└─────────────────┴──────────────────────┘
12 rows in set. Elapsed: 2.344 sec. Processed 96.41 million rows, 6.00 GB (41.13 million rows/s., 2.56 GB/s.)
```

## Performance heads up

If the dataset is smaller than the amount of RAM, sampling won't help in terms of performance.
The bellow is an example of a bigger result set using no-sampling and sampling. 

```sql
SELECT 
    some_type,
    count(*)
FROM database_report.stats_table_distributed
GROUP BY some_type
HAVING count(*) > 1000000
ORDER BY count(*) DESC
[...]
15 rows in set. Elapsed: 1.534 sec. Processed 96.41 million rows, 1.95 GB (62.84 million rows/s., 1.27 GB/s.)

SELECT 
    some_type,
    count(*) * 10
FROM database_report.stats_table_distributed
SAMPLE 1 / 10
GROUP BY some_type
HAVING (count(*) * 10) > 1000000
ORDER BY count(*) DESC
[...]
15 rows in set. Elapsed: 2.123 sec. Processed 96.41 million rows, 5.90 GB (45.41 million rows/s., 2.78 GB/s.)
```


[1]: http://www.3manuek.com/assets/posts/clickhouse_sample.gif