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

There are certain scenarios where using certain features (LISTEN/NOTIFY [isn't cheap](http://johtopg.blogspot.com.ar/2015/11/listening-connections-arent-cheap.html)) and contribs (like pgcrypto due to encryption libraries) that consume an extra amount of CPU processing that you may want to be aware. Certainly, vertical processing scale-up isn't limited to CPUs (known as homogenous scaling): _heterogenous scaling up_ with GPUs is implemented in [PG-Strom](https://wiki.postgresql.org/wiki/PGStrom). So the [answer](http://dba.stackexchange.com/questions/17092/is-the-cpu-performance-relevant-for-a-database-server) will depend your requirements.


Hey there again! This post will be covering simple benchmarks for [PgCrypto](https://www.postgresql.org/docs/9.5/static/pgcrypto.html) under
Postgres 9.5.2. As a side note, here there are a few details about the test:

- I'm using [Docker image](https://hub.docker.com/_/postgres/) -- [Code](https://github.com/docker-library/postgres/blob/master/9.5/Dockerfile).
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

> Note 3:
> ALl the code is present at [pgCryptoBench](https://github.com/3manuek/pgCryptoBench)

> Note 4:
> Sar graphs done with ksar.

## Supported algorithms

[AES]()
[Blowfish]()
[3DES]()


## CPU basic benchmark

There is a way to do a quick benchmark using only encrypt/decrypt functions, without
incurring in the `pgbench` usage. This is easier as no previous data is required to
run it. [pgCryptoBench](https://github.com/3manuek/pgCryptoBench).

This test runs a process per core and times the execution, no disk activity, only
in-memory processing.


```
docker run -P postgres
```

```
|sync;
sysctrl -w vm.drop_caches=3;
```
