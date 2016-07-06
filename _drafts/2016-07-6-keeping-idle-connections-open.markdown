---
layout: post
title:  "Keeping persistent connections in Postgres."
date:   2016-06-22
description: And what do you need to start now.
tags : [PostgreSQL, Configuration]
categories:
- PostgreSQL
permalink: keeppersistentconnections
---


It sounds like a bad idea, I won't disagree,  however there is certainly usual that
some applications use persistent connections, withouth handling the `keepalive`.
Before to spit out the _partial workaround_ (assuming that you don't have any firewall
or network setup), you should read this [article](http://hans.io/blog/2014/02/19/postgresql_connection/) which actually shows how bad is
the idea of keeping connections open in certain scenarios.

The *potato* in Postgres is to play with the [_tcp options_](https://www.postgresql.org/docs/9.5/static/runtime-config-connection.html#GUC-TCP-KEEPALIVES-IDLE),
which I know, it isn't the most clear way to say _idle_ with _timeout_ together.

However it has a point, as it is actually how it works, and it allows you to play
with the same variables as most of the network solutions that follow the TCP protocol.

Let's explain the TCP keepalives in a _street lang_.

tcp_keepalives_idle server -> client each n seconds
tcp_keepalives_interval server's nap after the last NOT ACKED keepalive message from the client.
tcp_keepalives_count is basically, the server is asking himself "how many times should I ignore?".

What we don't want is to keep alive sessions that get closed by an abortion signal.


tcp_keepalives_interval
tcp_keepalives_idle en 36000. 10 horas.

tcp_keepalives_count = 1 (exacto 10 horas) , n (numero de counts,cada uno 10 horas)


## How to run a test with Docker

You have all you need to start [here](https://github.com/docker-library/docs/tree/master/postgres).

In that doc it is not mentioned, but you can pass variables when executing the run:

```
3laptop ~ # docker run --name postgres95 -e POSTGRES_PASSWORD=postgres -d postgres --tcp_keepalives_idle=3 --tcp_keepalives_interval=2 --tcp_keepalives_count=3
658e7f4e9bff6768dbcc3d3db1d22639d76f4c125e6e571423f23dac6fce031f
```

➜  ~ aws ecs run-task --task-definition postgres:latest
Could not connect to the endpoint URL: "https://ecs.sa-east-1.amazonaws.com/"
