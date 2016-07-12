
Read  https://aphyr.com/posts/294-jepsen-cassandra

https://aphyr.com/posts/293-call-me-maybe-kafka

➜  ccm git:(master) ✗ ccm create test -v 2.2.7 -n 3 -s
17:53:45,633 ccm INFO Downloading http://archive.apache.org/dist/cassandra/2.2.7/apache-cassandra-2.2.7-bin.tar.gz to /tmp/ccm-mORIZf.tar.gz (28.229MB)
  29401088  [9917:56:29,230 ccm INFO Extracting /tmp/ccm-mORIZf.tar.gz as version 2.2.7 ...
  29600429  [100.00%]Current cluster is now: test

  ➜  ccm git:(master) ✗ sudo ifconfig lo:2 127.0.0.3

  ➜  ccm git:(master) ✗ ccm node1 start
  Traceback (most recent call last):
    File "/usr/local/bin/ccm", line 5, in <module>
      pkg_resources.run_script('ccm==2.1.11', 'ccm')
    File "/usr/local/lib/python2.7/dist-packages/pkg_resources/__init__.py", line 726, in run_script
      self.require(requires)[0].run_script(script_name, ns)
    File "/usr/local/lib/python2.7/dist-packages/pkg_resources/__init__.py", line 1491, in run_script
      exec(script_code, namespace, namespace)
    File "/usr/local/lib/python2.7/dist-packages/ccm-2.1.11-py2.7.egg/EGG-INFO/scripts/ccm", line 86, in <module>

    File "build/bdist.linux-x86_64/egg/ccmlib/cmds/node_cmds.py", line 206, in run
    File "build/bdist.linux-x86_64/egg/ccmlib/node.py", line 542, in start
    File "build/bdist.linux-x86_64/egg/ccmlib/common.py", line 442, in check_socket_available
  ccmlib.common.UnavailableSocketError: Inet address 127.0.0.1:9042 is not available: [Errno 98] Address already in use


  ➜  ccm git:(master) ✗ ccm node1 show
  node1: DOWN (Not initialized)
         cluster=test
         auto_bootstrap=False
         thrift=('127.0.0.1', 9160)
         binary=('127.0.0.1', 9042)
         storage=('127.0.0.1', 7000)
         jmx_port=7100
         remote_debug_port=0
         byteman_port=0
         initial_token=-9223372036854775808

https://github.com/pcmanus/ccm/issues/87
cat ~/bin/loop_alias.sh
#!/bin/bash

sudo ifconfig lo0 alias 127.0.0.2 up
sudo ifconfig lo0 alias 127.0.0.3 up
sudo ifconfig lo0 alias 127.0.0.4 up
sudo ifconfig lo0 alias 127.0.0.5 up
sudo ifconfig lo0 alias 127.0.0.6 up

sudo ifconfig lo0 alias 127.0.1.1 up
sudo ifconfig lo0 alias 127.0.1.2 up
sudo ifconfig lo0 alias 127.0.1.3 up
sudo ifconfig lo0 alias 127.0.1.4 up
sudo ifconfig lo0 alias 127.0.1.5 up
sudo ifconfig lo0 alias 127.0.1.6 up


➜  ccm git:(master) ✗ ps -ef | grep java
emanuel  11317     1  2 17:56 pts/9    00:00:31 java -ea -javaagent:/home/emanuel/.ccm/repository/2.2.7/lib/jamm-0.3.0.jar -XX:+CMSClassUnloadingEnabled -XX:+UseThreadPriorities -XX:ThreadPriorityPolicy=42 -Xms500M -Xmx500M -Xmn50M -XX:+HeapDumpOnOutOfMemoryError -Xss256k -XX:StringTableSize=1000003 -XX:+UseParNewGC -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:SurvivorRatio=8 -XX:MaxTenuringThreshold=1 -XX:CMSInitiatingOccupancyFraction=75 -XX:+UseCMSInitiatingOccupancyOnly -XX:+UseTLAB -XX:+PerfDisableSharedMem -XX:CompileCommandFile=/home/emanuel/.ccm/test/node1/conf/hotspot_compiler -XX:CMSWaitDuration=10000 -XX:+CMSParallelInitialMarkEnabled -XX:+CMSEdenChunksRecordAlways -XX:CMSWaitDuration=10000 -XX:+UseCondCardMark -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintHeapAtGC -XX:+PrintTenuringDistribution -XX:+PrintGCApplicationStoppedTime -XX:+PrintPromotionFailure -Xloggc:/home/emanuel/.ccm/test/node1/logs/gc.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=10 -XX:GCLogFileSize=10M -Xloggc:/home/emanuel/.ccm/test/node1/logs/gc.log -Djava.net.preferIPv4Stack=true -Dcassandra.jmx.local.port=7100 -XX:+DisableExplicitGC -Djava.library.path=/home/emanuel/.ccm/repository/2.2.7/lib/sigar-bin -Dcassandra.libjemalloc=/usr/lib/x86_64-linux-gnu/libjemalloc.so.1 -Dlogback.configurationFile=logback.xml -Dcassandra.logdir=/home/emanuel/.ccm/repository/2.2.7/logs -Dcassandra.storagedir=/home/emanuel/.ccm/repository/2.2.7/data -Dcassandra-pidfile=/home/emanuel/.ccm/test/node1/cassandra.pid -cp /home/emanuel/.ccm/test/node1/conf:/home/emanuel/.ccm/repository/2.2.7/build/classes/main:/home/emanuel/.ccm/repository/2.2.7/build/classes/thrift:/home/emanuel/.ccm/repository/2.2.7/lib/ST4-4.0.8.jar:/home/emanuel/.ccm/repository/2.2.7/lib/airline-0.6.jar:/home/emanuel/.ccm/repository/2.2.7/lib/antlr-runtime-3.5.2.jar:/home/emanuel/.ccm/repository/2.2.7/lib/apache-cassandra-2.2.7.jar:/home/emanuel/.ccm/repository/2.2.7/lib/apache-cassandra-clientutil-2.2.7.jar:/home/emanuel/.ccm/repository/2.2.7/lib/apache-cassandra-thrift-2.2.7.jar:/home/emanuel/.ccm/repository/2.2.7/lib/cassandra-driver-core-2.2.0-rc2-SNAPSHOT-20150617-shaded.jar:/home/emanuel/.ccm/repository/2.2.7/lib/commons-cli-1.1.jar:/home/emanuel/.ccm/repository/2.2.7/lib/commons-codec-1.2.jar:/home/emanuel/.ccm/repository/2.2.7/lib/commons-lang3-3.1.jar:/home/emanuel/.ccm/repository/2.2.7/lib/commons-math3-3.2.jar:/home/emanuel/.ccm/repository/2.2.7/lib/compress-lzf-0.8.4.jar:/home/emanuel/.ccm/repository/2.2.7/lib/concurrentlinkedhashmap-lru-1.4.jar:/home/emanuel/.ccm/repository/2.2.7/lib/crc32ex-0.1.1.jar:/home/emanuel/.ccm/repository/2.2.7/lib/disruptor-3.0.1.jar:/home/emanuel/.ccm/repository/2.2.7/lib/ecj-4.4.2.jar:/home/emanuel/.ccm/repository/2.2.7/lib/guava-16.0.jar:/home/emanuel/.ccm/repository/2.2.7/lib/high-scale-lib-1.0.6.jar:/home/emanuel/.ccm/repository/2.2.7/lib/jackson-core-asl-1.9.2.jar:/home/emanuel/.ccm/repository/2.2.7/lib/jackson-mapper-asl-1.9.2.jar:/home/emanuel/.ccm/repository/2.2.7/lib/jamm-0.3.0.jar:/home/emanuel/.ccm/repository/2.2.7/lib/javax.inject.jar:/home/emanuel/.ccm/repository/2.2.7/lib/jbcrypt-0.3m.jar:/home/emanuel/.ccm/repository/2.2.7/lib/jcl-over-slf4j-1.7.7.jar:/home/emanuel/.ccm/repository/2.2.7/lib/jna-4.0.0.jar:/home/emanuel/.ccm/repository/2.2.7/lib/joda-time-2.4.jar:/home/emanuel/.ccm/repository/2.2.7/lib/json-simple-1.1.jar:/home/emanuel/.ccm/repository/2.2.7/lib/libthrift-0.9.2.jar:/home/emanuel/.ccm/repository/2.2.7/lib/log4j-over-slf4j-1.7.7.jar:/home/emanuel/.ccm/repository/2.2.7/lib/logback-classic-1.1.3.jar:/home/emanuel/.ccm/repository/2.2.7/lib/logback-core-1.1.3.jar:/home/emanuel/.ccm/repository/2.2.7/lib/lz4-1.3.0.jar:/home/emanuel/.ccm/repository/2.2.7/lib/metrics-core-3.1.0.jar:/home/emanuel/.ccm/repository/2.2.7/lib/metrics-logback-3.1.0.jar:/home/emanuel/.ccm/repository/2.2.7/lib/netty-all-4.0.23.Final.jar:/home/emanuel/.ccm/repository/2.2.7/lib/ohc-core-0.3.4.jar:/home/emanuel/.ccm/repository/2.2.7/lib/ohc-core-j8-0.3.4.jar:/home/emanuel/.ccm/repository/2.2.7/lib/reporter-config-base-3.0.0.jar:/home/emanuel/.ccm/repository/2.2.7/lib/reporter-config3
emanuel  12645 10860  0 18:15 pts/9    00:00:00 grep --color=auto --exclude-dir=.bzr --exclude-dir=CVS --exclude-dir=.git --exclude-dir=.hg --exclude-dir=.svn java
➜  ccm git:(master) ✗ kill -9 11317

➜  ccm git:(master) ✗ ccm status
Cluster: 'test'
---------------
node1: UP
node3: UP
node2: UP


➜  ccm git:(master) ✗ ccm node1 ring


Datacenter: datacenter1
==========
Address    Rack        Status State   Load            Owns                Token                                       
                                                                          3074457345618258602                         
127.0.0.1  rack1       Up     Normal  121.87 KB       66.67%              -9223372036854775808                        
127.0.0.2  rack1       Up     Normal  95.01 KB        66.67%              -3074457345618258603                        
127.0.0.3  rack1       Up     Normal  115.57 KB       66.67%              3074457345618258602                         


➜  ccm git:(master) ✗ ccm node2 cqlsh
Connected to test at 127.0.0.2:9042.
[cqlsh 5.0.1 | Cassandra 2.2.7 | CQL spec 3.3.1 | Native protocol v4]
Use HELP for help.
cqlsh> help

Documented shell commands:
===========================
CAPTURE  CLS          COPY  DESCRIBE  EXPAND  LOGIN   SERIAL  SOURCE   UNICODE
CLEAR    CONSISTENCY  DESC  EXIT      HELP    PAGING  SHOW    TRACING

CQL help topics:
================
AGGREGATES        CREATE_COLUMNFAMILY  DROP_INDEX     LIST_PERMISSIONS  UUID
ALTER_KEYSPACE    CREATE_FUNCTION      DROP_KEYSPACE  LIST_USERS      
ALTER_TABLE       CREATE_INDEX         DROP_TABLE     PERMISSIONS     
ALTER_TYPE        CREATE_KEYSPACE      DROP_TRIGGER   REVOKE          
ALTER_USER        CREATE_TABLE         DROP_TYPE      SELECT          
APPLY             CREATE_TRIGGER       DROP_USER      SELECT_JSON     
ASCII             CREATE_TYPE          FUNCTIONS      TEXT            
BATCH             CREATE_USER          GRANT          TIME            
BEGIN             DATE                 INSERT         TIMESTAMP       
BLOB              DELETE               INSERT_JSON    TRUNCATE        
BOOLEAN           DROP_AGGREGATE       INT            TYPES           
COUNTER           DROP_COLUMNFAMILY    JSON           UPDATE          
CREATE_AGGREGATE  DROP_FUNCTION        KEYWORDS       USE             

cqlsh> CREATE KEYSPACE mykeyspace
   ... WITH REPLICATION = { 'class' : 'SimpleStrategy', 'replication_factor' : 3 };
cqlsh> USE mykeyspave
   ... ;
InvalidRequest: code=2200 [Invalid query] message="Keyspace 'mykeyspave' does not exist"
cqlsh> USE mykeyspace
   ...
   ... ;
cqlsh:mykeyspace> CREATE TABLE users (
              ...   user_id int PRIMARY KEY,
              ...   fname text,
              ...   lname text
              ... );
cqlsh:mykeyspace> INSERT INTO users (user_id,  fname, lname)
              ...   VALUES (1745, 'john', 'smith');
cqlsh:mykeyspace> INSERT INTO users (user_id,  fname, lname)
              ...   VALUES (1744, 'john', 'doe');
cqlsh:mykeyspace> INSERT INTO users (user_id,  fname, lname)
              ...   VALUES (1746, 'john', 'smith');
cqlsh:mykeyspace> select * from users;

 user_id | fname | lname
---------+-------+-------
    1745 |  john | smith
    1744 |  john |   doe
    1746 |  john | smith

(3 rows)
cqlsh:mykeyspace> quit
➜  ccm git:(master) ✗ ccm node2 nodetool status

Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address    Load       Tokens       Owns (effective)  Host ID                               Rack
UN  127.0.0.1  126.42 KB  1            100.0%            801233ec-95e3-44ce-a009-1cac60a983aa  rack1
UN  127.0.0.2  160.72 KB  1            100.0%            26dd7a0c-6d54-403c-91db-9c09bd5f1988  rack1
UN  127.0.0.3  118.03 KB  1            100.0%            16c35fa9-26e5-4e82-b2fd-c9d22a4f944e  rack1


➜  ccm git:(master) ✗ ccm node1 nodetool status

Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address    Load       Tokens       Owns (effective)  Host ID                               Rack
UN  127.0.0.1  126.42 KB  1            100.0%            801233ec-95e3-44ce-a009-1cac60a983aa  rack1
UN  127.0.0.2  160.72 KB  1            100.0%            26dd7a0c-6d54-403c-91db-9c09bd5f1988  rack1
UN  127.0.0.3  118.03 KB  1            100.0%            16c35fa9-26e5-4e82-b2fd-c9d22a4f944e  rack1
