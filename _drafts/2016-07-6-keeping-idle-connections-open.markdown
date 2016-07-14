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
some applications use persistent connections, without handling the `keepalive`.
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


```
root@658e7f4e9bff:/var/lib/postgresql/data# sysctl -A |grep -i tcp                 
fs.nfs.nlm_tcpport = 0
net.ipv4.tcp_ecn = 2
net.ipv4.tcp_fwmark_accept = 0
net.netfilter.nf_conntrack_tcp_be_liberal = 0
net.netfilter.nf_conntrack_tcp_loose = 1
net.netfilter.nf_conntrack_tcp_max_retrans = 3
net.netfilter.nf_conntrack_tcp_timeout_close = 10
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 60
net.netfilter.nf_conntrack_tcp_timeout_established = 432000
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_last_ack = 30
net.netfilter.nf_conntrack_tcp_timeout_max_retrans = 300
net.netfilter.nf_conntrack_tcp_timeout_syn_recv = 60
net.netfilter.nf_conntrack_tcp_timeout_syn_sent = 120
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 120
net.netfilter.nf_conntrack_tcp_timeout_unacknowledged = 300
sunrpc.tcp_fin_timeout = 15
sunrpc.tcp_max_slot_table_entries = 65536
sunrpc.tcp_slot_table_entries = 2
sunrpc.transports = tcp 1048576
sunrpc.transports = tcp-bc 1048576


root@658e7f4e9bff:/var/lib/postgresql/data# cat /proc/net/tcp
  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode                                                     
   0: 00000000:1538 00000000:0000 0A 00000000:00000000 00:00000000 00000000   999        0 24653 1 0000000000000000 100 0 0 10 0                     
   1: 020011AC:1538 010011AC:D814 01 00000000:00000000 02:0000003F 00000000   999        0 29752 2 0000000000000000 20 4 1 10 -1                     
root@658e7f4e9bff:/var/lib/postgresql/data# cat /proc/net/sockstat
sockets: used 544
TCP: inuse 2 orphan 0 tw 2 alloc 30 mem 1
UDP: inuse 0 mem 10
UDPLITE: inuse 0
RAW: inuse 0
FRAG: inuse 0 memory 0
root@658e7f4e9bff:/var/lib/postgresql/data# cat /proc/net/tcp     
  sl  local_address rem_address   st tx_queue rx_queue tr tm->when retrnsmt   uid  timeout inode                                                     
   0: 00000000:1538 00000000:0000 0A 00000000:00000000 00:00000000 00000000   999        0 24653 1 0000000000000000 100 0 0 10 0                     
   1: 020011AC:1538 010011AC:D814 01 00000000:00000000 02:0000001A 00000000   999        0 29752 2 0000000000000000 20 4 1 10 -1                     
   2: 020011AC:1538 010011AC:D840 01 00000000:00000000 02:0000002C 00000000   999        0 37341 2 0000000000000000 20 4 23 10 -1                    
root@658e7f4e9bff:/var/lib/postgresql/data# cat /proc/net/sockstat
sockets: used 546
TCP: inuse 3 orphan 0 tw 3 alloc 32 mem 1
UDP: inuse 0 mem 10
UDPLITE: inuse 0
RAW: inuse 0
FRAG: inuse 0 memory 0

root@658e7f4e9bff:/var/lib/postgresql/data# sysctl -A |grep -i ^net.ipv4.conf                
net.ipv4.conf.all.accept_local = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.arp_accept = 0
net.ipv4.conf.all.arp_announce = 0
net.ipv4.conf.all.arp_filter = 0
net.ipv4.conf.all.arp_ignore = 0
net.ipv4.conf.all.arp_notify = 0
net.ipv4.conf.all.bootp_relay = 0
net.ipv4.conf.all.disable_policy = 0
net.ipv4.conf.all.disable_xfrm = 0
net.ipv4.conf.all.force_igmp_version = 0
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.all.igmpv2_unsolicited_report_interval = 10000
net.ipv4.conf.all.igmpv3_unsolicited_report_interval = 1000
net.ipv4.conf.all.log_martians = 0
net.ipv4.conf.all.mc_forwarding = 0
net.ipv4.conf.all.medium_id = 0
net.ipv4.conf.all.promote_secondaries = 0
net.ipv4.conf.all.proxy_arp = 0
net.ipv4.conf.all.proxy_arp_pvlan = 0
net.ipv4.conf.all.route_localnet = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.secure_redirects = 1
net.ipv4.conf.all.send_redirects = 1
net.ipv4.conf.all.shared_media = 1
net.ipv4.conf.all.src_valid_mark = 0
net.ipv4.conf.all.tag = 0
net.ipv4.conf.default.accept_local = 0
net.ipv4.conf.default.accept_redirects = 1
net.ipv4.conf.default.accept_source_route = 1
net.ipv4.conf.default.arp_accept = 0
net.ipv4.conf.default.arp_announce = 0
net.ipv4.conf.default.arp_filter = 0
net.ipv4.conf.default.arp_ignore = 0
net.ipv4.conf.default.arp_notify = 0
net.ipv4.conf.default.bootp_relay = 0
net.ipv4.conf.default.disable_policy = 0
net.ipv4.conf.default.disable_xfrm = 0
net.ipv4.conf.default.force_igmp_version = 0
net.ipv4.conf.default.forwarding = 1
net.ipv4.conf.default.igmpv2_unsolicited_report_interval = 10000
net.ipv4.conf.default.igmpv3_unsolicited_report_interval = 1000
net.ipv4.conf.default.log_martians = 0
net.ipv4.conf.default.mc_forwarding = 0
net.ipv4.conf.default.medium_id = 0
net.ipv4.conf.default.promote_secondaries = 0
net.ipv4.conf.default.proxy_arp = 0
net.ipv4.conf.default.proxy_arp_pvlan = 0
net.ipv4.conf.default.route_localnet = 0
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.secure_redirects = 1
net.ipv4.conf.default.send_redirects = 1
net.ipv4.conf.default.shared_media = 1
net.ipv4.conf.default.src_valid_mark = 0
net.ipv4.conf.default.tag = 0
net.ipv4.conf.eth0.accept_local = 0
net.ipv4.conf.eth0.accept_redirects = 1
net.ipv4.conf.eth0.accept_source_route = 1
net.ipv4.conf.eth0.arp_accept = 0
net.ipv4.conf.eth0.arp_announce = 0
net.ipv4.conf.eth0.arp_filter = 0
net.ipv4.conf.eth0.arp_ignore = 0
net.ipv4.conf.eth0.arp_notify = 0
net.ipv4.conf.eth0.bootp_relay = 0
net.ipv4.conf.eth0.disable_policy = 0
net.ipv4.conf.eth0.disable_xfrm = 0
net.ipv4.conf.eth0.force_igmp_version = 0
net.ipv4.conf.eth0.forwarding = 1
net.ipv4.conf.eth0.igmpv2_unsolicited_report_interval = 10000
net.ipv4.conf.eth0.igmpv3_unsolicited_report_interval = 1000
net.ipv4.conf.eth0.log_martians = 0
net.ipv4.conf.eth0.mc_forwarding = 0
net.ipv4.conf.eth0.medium_id = 0
net.ipv4.conf.eth0.promote_secondaries = 0
net.ipv4.conf.eth0.proxy_arp = 0
net.ipv4.conf.eth0.proxy_arp_pvlan = 0
net.ipv4.conf.eth0.route_localnet = 0
net.ipv4.conf.eth0.rp_filter = 1
net.ipv4.conf.eth0.secure_redirects = 1
net.ipv4.conf.eth0.send_redirects = 1
net.ipv4.conf.eth0.shared_media = 1
net.ipv4.conf.eth0.src_valid_mark = 0
net.ipv4.conf.eth0.tag = 0
net.ipv4.conf.lo.accept_local = 0
net.ipv4.conf.lo.accept_redirects = 1
net.ipv4.conf.lo.accept_source_route = 1
net.ipv4.conf.lo.arp_accept = 0
net.ipv4.conf.lo.arp_announce = 0
net.ipv4.conf.lo.arp_filter = 0
net.ipv4.conf.lo.arp_ignore = 0
net.ipv4.conf.lo.arp_notify = 0
net.ipv4.conf.lo.bootp_relay = 0
net.ipv4.conf.lo.disable_policy = 1
net.ipv4.conf.lo.disable_xfrm = 1
net.ipv4.conf.lo.force_igmp_version = 0
net.ipv4.conf.lo.forwarding = 1
net.ipv4.conf.lo.igmpv2_unsolicited_report_interval = 10000
net.ipv4.conf.lo.igmpv3_unsolicited_report_interval = 1000
net.ipv4.conf.lo.log_martians = 0
net.ipv4.conf.lo.mc_forwarding = 0
net.ipv4.conf.lo.medium_id = 0
net.ipv4.conf.lo.promote_secondaries = 0
net.ipv4.conf.lo.proxy_arp = 0
net.ipv4.conf.lo.proxy_arp_pvlan = 0
net.ipv4.conf.lo.route_localnet = 0
net.ipv4.conf.lo.rp_filter = 1
net.ipv4.conf.lo.secure_redirects = 1
net.ipv4.conf.lo.send_redirects = 1
net.ipv4.conf.lo.shared_media = 1
net.ipv4.conf.lo.src_valid_mark = 0
net.ipv4.conf.lo.tag = 0

3laptop ~ # docker network inspect bridge | jq .[].Options
{
  "com.docker.network.driver.mtu": "1500",
  "com.docker.network.bridge.name": "docker0",
  "com.docker.network.bridge.host_binding_ipv4": "0.0.0.0",
  "com.docker.network.bridge.enable_ip_masquerade": "true",
  "com.docker.network.bridge.enable_icc": "true",
  "com.docker.network.bridge.default_bridge": "true"
}


```


## How to run a test with Docker

You have all you need to start [here](https://github.com/docker-library/docs/tree/master/postgres).

In that doc it is not mentioned, but you can pass variables when executing the run:

```
3laptop ~ # docker run --name postgres95 -e POSTGRES_PASSWORD=postgres -d postgres --tcp_keepalives_idle=3 --tcp_keepalives_interval=2 --tcp_keepalives_count=3
658e7f4e9bff6768dbcc3d3db1d22639d76f4c125e6e571423f23dac6fce031f
```
```
➜  ~ aws --region=us-east-1 ecs run-task --task-definition postgres:latest
Could not connect to the endpoint URL: "https://ecs.sa-east-1.amazonaws.com/"
```
