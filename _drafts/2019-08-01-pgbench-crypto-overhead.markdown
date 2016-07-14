---
layout: post
title:  "PgCrypto overhead comparison with pgbench."
date:   2016-08-01
description: A full overview.
tags : [PostgreSQL, Benchmark]
categories:
- PostgreSQL
permalink: pgcryptoppgbench
---

Hey there again! This post will be covering simple benchmarks for PgCrypto under
Postgres 9.5.2. As a side note, here there are a few details about the test:

- I'm using [Docker image](https://github.com/docker-library/postgres/blob/master/9.5/Dockerfile).
- All the tests are in a local machine, and I'll be focusing in the performance difference
   between algorithms.
- The test is intended to calculate before hand, the encryption overhead inside
  a Postgres instance.
- I'll be using custom pgbench scripts in order to have a standard measurement. This
  means that in order to  reproduce the tests, you don't need any additional tool
  outside the Postgres ecosystem.

> Note 1:
> As Docker is a new technology, I'll be covering some basic aspects for those people
> whom never played with it before. You can skip those if you already have hands on.

> Note 2:
> Contribs are included in the Docker image. If you want to run tests over a custom
> installation, be aware to ahve installed the contrib packages.

## CPU basic benchmark

There is a way to do a quick benchmark using only encrypt/decrypt functions, without
incurring in the `pgbench` usage. This is easier as no previous data is required to
run it.

### Why I use `time`?



```
➜  pgCryptoBench git:(master) ✗ psql -h172.17.0.2 -Upostgres
psql (9.5.3)
Type "help" for help.

postgres=# \timing
Timing is on.
postgres=# select 1;
 ?column?
----------
        1
(1 row)

Time: 0,354 ms
postgres=# \o /dev/null
postgres=# select 1;
Time: 0,260 ms
postgres=# \q
```

psql -h172.17.0.2 -Upostgres --pset=timing --o /dev/null <<EOF
\timing
select 1
EOF



Looks like
➜  pgCryptoBench git:(master) ✗ psql -h172.17.0.2 -Upostgres --set=timing=on --o /dev/null -c 'select 1'



```
|sync;
sysctrl -w vm.drop_caches=3;
```




https://github.com/3manuek/pgCryptoBench
