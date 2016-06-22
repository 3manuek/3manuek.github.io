---
layout: post
title:  "Query digest complements"
date:   2016-06-22
description: Additional usage and recommendations for pt-query-digest.
tags : [MySQL, SQL, tuning]
categories:
- MySQL
permalink: querydigestcomplements
---


I would recommend 1 book, probably available online : Effective MySQL: optimizing SQL Statements from Ronald Bradford. Is not an advanced book and actually there are some considerations that you need to be aware in newer MySQL versions. However is a good kickstart. I do recommend to have it in the e-library and take a look, don't need a full read.




```
/tmp/report.txt
```


How to execute the SHOWS in the `pt-query-digest`:

```bash
egrep "SHOW.[TABLE|CREATE].*" /tmp/report.txt | sed 's/^#\s*//' | sed 's/\\/\\\\/g' | sort | uniq | sed "s/'/\\\'/g" | xargs -i mysql --user=mysql --password=SHADOW -e {} > /tmp/SHOW.txt
```

The idea is to streamed transactions in a more detailed way, so you can see the write flow from a master (ideally to trace/debug slave lags). This is not entirely related with Query Reviews generally, however it could be a detection tool when some unexpected floods happen.

https://github.com/pythian/binlogEventStats

The idea was to have available in a single glance the slow logs, which can become very handy when scaling complex boxes. Also it improves proactive monitoring and partial trending.

Fixed Vagrant for Anemometer:
https://github.com/3manuek/Anemometer
