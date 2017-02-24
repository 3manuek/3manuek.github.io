---
layout: post
title:  "HOWTO Percona Server with docker"
date:   2016-07-2
description: Starting Percona 5.7 docker container and other tricks.
tags : [MySQL, docker]
categories:
- MySQL
category: blog
comments: true
tagline: A simple addition to current docs.
permalink: perconaserverbasichowto
---

## Before starting the container

This article is not an introductory explanation of docker,however it's scope if for docker's beginners. You can consider it as an extension of the well documented [Percona docker hub doc][1]. For the source code of the image, the repository is at [github][2].

Here is the all what you need to do for start:

```bash
docker run --name percona57 -e MYSQL_ROOT_PASSWORD=<a_password>  -d percona:5.7
```

For checking the container status log, you can execute `docker logs percona57`.

## Additional MySQL logs

To start the container is pretty easy, but if you are not very used to Docker, you will find a bit lost if you want to enable logging or other features.

For example, a full logging container will be started with this:

```bash
docker run --name percona57  -v /var/log/mysql:/var/log/mysql  -e MYSQL_ROOT_PASSWORD=mysql  -d percona:5.7 --general-log=1 --slow-query-log=1 --long-query-time=0  --log_slow_verbosity='full, profiling, profiling_use_getrusage'
```

Note that the `log_slow_verbosity` is only applicable for the Percona release, and adds extra output that turns very useful when doing complex query reviews. As you can appreciate, all the options are passed after the image name (percona:5.7).

Now, the question is: where are the logs? Generally, you can access the container using `docker exec -it percona57 bash` and view the logs inside it, although this is not the most comfortable way to do this.

In the example bellow, we'll use `jq` (a very handy json parser).

```bash
3laptop ~ # docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
cb740be0743c        percona:5.7         "docker-entrypoint.sh"   35 minutes ago      Up 35 minutes       3306/tcp            percona57

3laptop ~ # docker inspect percona57 | jq .[].Mounts
[
  {
    "Propagation": "rprivate",
    "RW": true,
    "Mode": "",
    "Destination": "/var/log/mysql",
    "Source": "/var/log/mysql"
  },
  {
    "Propagation": "",
    "RW": true,
    "Mode": "",
    "Driver": "local",
    "Destination": "/var/lib/mysql",
    "Source": "/var/lib/docker/volumes/ceda51de62dac317fcafe9dd9e8f9b6f1dc5d70874466b3faf7cdfbcbbc91154/_data",
    "Name": "ceda51de62dac317fcafe9dd9e8f9b6f1dc5d70874466b3faf7cdfbcbbc91154"
  }
]

3laptop ~ # ls -l /var/lib/docker/volumes/ceda51de62dac317fcafe9dd9e8f9b6f1dc5d70874466b3faf7cdfbcbbc91154/_data
...
-rw-r----- 1 maxscale docker  26886023 Jul  2 19:10 cb740be0743c.log
-rw-r----- 1 maxscale docker 268834670 Jul  2 19:10 cb740be0743c-slow.log
...
```

The logs (general and slow) are using the `container id` in the file name, which can be appreciated when executing `docker ps`.

## Access through network

Obviously, when using docker in production, you don't want to access it locally.  For getting the host of our container (and all the running containers), we can do the following commands:


```bash
3laptop ~ # docker network ls
NETWORK ID          NAME                DRIVER
5fddd2e1a80a        bridge              bridge              
e4e0c655e1aa        host                host                
565f4a23d95a        none                null  

3laptop ~ # docker network inspect 5fddd2e1a80a | jq .[].Containers
{
  "cb740be0743cd662c700f73586fe481dc25e4eb27ef94e075c4668a5421eca13": {
    "IPv6Address": "",
    "IPv4Address": "172.17.0.2/16",
    "MacAddress": "02:42:ac:11:00:02",
    "EndpointID": "6dbd28900efe2c6f6edffcbbec0ac7d6446b4336e6e31f018f18d00f1005a812",
    "Name": "percona57"
  }
}
```

We can see that our container `percona57` is running over `172.17.0.2` IP address. To access it, you only need to do as usual:

```bash
3laptop ~ # mysql -h 172.17.0.2 -p
....
mysql>
```



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

[1]: https://hub.docker.com/_/percona/
[2]: https://github.com/dockerfile/percona
