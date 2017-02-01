---
layout: post
title:  "[Data on Weed] Poor's man sharding technique."
date:   2017-01-31
description: No tenes un peso para el sharding?.
tags : [PostgreSQL, Sharding, cosasAtadasConAlambre]
categories:
- PostgreSQL
permalink: poorsmansharding
---

## If you are sober, STOP

Data on Weed is a series of posts about data technologies with a twist. The twist is that you would never implement this in production
if you are sober or, if you really _fuching_ know what you are doing.  


## Concept 

The _Poor's man sharding technique_ is nothing more than a combination of two existing features (inheritance and foreign data wrappers)
and one extension (`postgres_fdw`).

It consists in a `proxy` database and `shard` or `data` databases. Gues what. Yeah, `proxy` database holds the entry points and the `shard`
databases the data itself.

## Warning

This is a POC, which I will suggest you think very well if you decide go into this way. It is mostly for didactic purposes or if you
want to drain your brain out of your ears. Still preferable this way other than space bugs. 


## How this "works"

You can have more than one `proxy` database, as it does not persist the data. The `proxy` database
can be placed in a stand alone instance or on each server. Or anywhere. It does not matter. This
is good as your entry points are not SPOF. 

The concept is very simple, proxy database holds the server definitions and user mappings, along 
with the entry point (table main,without data) and the inherited foreign data wrappers (which do not store data).
This leaves the proxy database with _metadata_ only. Most importantly, it stores the partition 
function and the trigger defition.

When an INSERT falls in, trigger executes the function and split the write to the inherited tables
according to the key. This is a fake, as the table is a foreign table which points to a remote database.

The real tables will be on each `shardXX` database, the location is up to the engineer. 


## No magic at all

As you expect, life sucks and sometimes one does not have time to dig into every crazy idea that prompts.
Special mention over those that come under doubtely states of consciousness. 

For HA, SERVERs can point to slaves, but beware of this as you must need to change the
FOREIGN TABLE definition and promote them, otherwise *writes won't work and reads will be stale*.

This technique is very simplistic, and it lacks of a lot of features provided for sharding tools.

Postgres 9.6 has a nice set of improvements on FDWs, specially related with condition pushdowns.
Being said, this kind of things will definitively a PITA under previous versions. 


## proxy database

I'm going to create two shards, because it's hard to code being stoned. Actually I'm just lazy,
but my friend Elrich Bachman told me that if it doesn't come in pairs, one is artificial.
 


```
CREATE EXTENSION postgres_fdw;
```

These definitions are thw ones you'll need to extend your shard:

```
CREATE SERVER shard1_main FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS(host '127.0.0.1',port '5434',dbname 'shard1');
CREATE SERVER shard2_main FOREIGN DATA WRAPPER postgres_fdw
  OPTIONS(host '127.0.0.1',port '5435',dbname 'shard2');

CREATE USER MAPPING FOR postgres SERVER shard1_main OPTIONS(user 'postgres');
CREATE USER MAPPING FOR postgres SERVER shard2_main OPTIONS(user 'postgres');
```

Create the tables, function and trigger. Obviously, you will need to create foreign tables as shards
you are planning to have:

```
CREATE TABLE main (shardKey char(2), key bigint, avalue text);
CREATE FOREIGN TABLE main_shard01 (CHECK (shardKey = '01'))INHERITS (main) SERVER shard1_main;
CREATE FOREIGN TABLE main_shard02 (CHECK (shardKey = '02'))INHERITS (main) SERVER shard2_main;

CREATE OR REPLACE FUNCTION f_main_part() RETURNS TRIGGER AS
$FMAINPART$
DECLARE
            partition_name text;
BEGIN
            partition_name := 'main_shard' || NEW.shardKey;
            EXECUTE  'INSERT INTO ' ||  quote_ident(partition_name) ||  ' SELECT ($1).*' USING NEW ;
            RETURN NULL;
END;
$FMAINPART$ LANGUAGE plpgsql;

CREATE TRIGGER t_main BEFORE INSERT ON main FOR EACH ROW EXECUTE PROCEDURE f_main_part();
```

## shards

On shards is easier:

```
CREATE TABLE main_shard01(shardKey char(2), key bigint, avalue text, CHECK(shardKey='01'));
CREATE INDEX ON main_shard01(key);
```


## TEST

```
INSERT INTO main VALUES ('01',1,'trololol'),('01',2,random()::text),('02',2,random()::text);
```


## _Grab them from the hidden columns_

The tableoid is the shard one, not the proxy foreign definition, this is important.

```
proxy=# select tableoid,* from main;
 tableoid | shardkey | key |      avalue       
----------+----------+-----+-------------------
    16422 | 01       |   1 | trololol
    16422 | 01       |   2 | 0.544912547804415
    16426 | 02       |   2 | 0.459446560591459
(3 rows)
```










