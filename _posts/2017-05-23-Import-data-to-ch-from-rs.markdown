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

If you heard about CLickhouse and you are wondering how
to test your data residing on Redshift, here is a command
that will show you a few tips to make you speed up.

The standard wat to move your data out of Redshift is by using [UNLOAD](http://docs.aws.amazon.com/redshift/latest/dg/r_UNLOAD.html) command,
which pushes the output into S3 files. Not surprisingly, Redshift does not support
`COPY (<query>) TO STDOUT`, which could make life easier (as it 
Postgres version 8.0.2 based, quite ol'). Info about this, [here](http://docs.aws.amazon.com/redshift/latest/dg/r_COPY.html).


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

