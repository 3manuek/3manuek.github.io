

OOM killer is a OS mechanism to avoid processes to consume more resources than the available in the host.
It may look as a good idea for avoid scenarios wether certain proceses behave unexpectely. 

swap configuration vm.swappiness=1 
overcommit memory, applies to MySQL ?

There is another mechanism wether the OS _scores_ processes. THe higher the score, the more likely to be killed
the process will be. I've been seeing fixes around by setting -20 or other numbers to the oom_score_adj. You may
be aware that this only applies an arithmetic operations to the current score, but it won't be a permanent fix,
as scores changes according to the process status. The best source is [the proc man page](http://man7.org/linux/man-pages/man5/proc.5.html).
However, oom_adj is deprecated in 2.6.36 in favor of oom_score_adj. 


http://www.oracle.com/technetwork/articles/servers-storage-dev/oom-killer-1911807.html


No consensus on an elegant way to do this:

https://groups.google.com/a/percona.com/forum/?hl=en#!msg/experts/78USb3jqJnA/3AlUYsLXEgAJ;context-place=forum/experts

Nor neiether Maria:
https://jira.mariadb.org/browse/MDEV-9264


persist in cron line:


*/1 * * * * root (pidof mysqld | while read PID; do echo -1000 > /proc/$PID/oom_score_adj; done) 

The -1000 has a reason, and it is explained clearly in the manpage:


> The value of oom_score_adj is added to the badness score
>              before it is used to determine which task to kill.  Acceptable
>              values range from -1000 (OOM_SCORE_ADJ_MIN) to +1000
>              (OOM_SCORE_ADJ_MAX).  This allows user space to control the
>              preference for OOM-killing, ranging from always preferring a
>              certain task or completely disabling it from OOM killing.  The
>              lowest possible value, -1000, is equivalent to disabling OOM-
>              killing entirely for that task, since it will always report a
>              badness score of 0.


As oom_score is a setting that can increase thourgh server acitivty, you may want to ensure that is
always 0.  

```
# cat /proc/$(pidof mysqld)/oom_score
0
```
 
What about overcommit:
https://www.kernel.org/doc/Documentation/vm/overcommit-accounting


