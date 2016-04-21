---
layout: post
title:  "Multi source data injection to Postgres RDS with encryption and FTS support"
date:   2016-03-23
description: "Multi source data injection to [Postgres RDS]() with encryption and FTS support."
categories:
- blog
permalink: rds-hipaa-fts
---


> Note 1:
> All the of this presentation is published in this [repository](). You will find a lot of folders and information, probably part of a blog series.

> Note 2:
> All the work on this article is a **POC** (Proof of concept).

> Note 3:
> This is something that is related for [HIPAA](https://en.wikipedia.org/wiki/Health_Insurance_Portability_and_Accountability_Act) compliant.


## [KMS](http://aws.amazon.com/kms/)/[RDS](https://aws.amazon.com/rds/postgresql/)

The POC on this article was developed before the releasing of the Key Management service
for RDS.

I totally discourage to use the current approach for encrypting data. _Use REST._


## Introduction

I've been dealing with an issue that came into my desktop from people of the
community, regarding RDS and HIPAA rules. There was a confusing scenario whether
PostgreSQL was using FTS and encryption on RDS. There are a lot of details regarding
the architecture, however I think it won't be necessary to dig into
very deeply to understand the basics of the present article moto.

[HIPAA](https://en.wikipedia.org/wiki/Health_Insurance_Portability_and_Accountability_Act)
rules are complex and if you need to deal with them, you'll probably need to go
through a careful read.

`tl;dr`? they tell us to store data encrypted on servers that are not in the premises.
And that's the case of RDS. However, all the communications are encrypted using
SSL protocol, but is not enough to compliant with HIPAA rules.

CPU resources in RDS are expensive and not stable sometimes, which makes encryption and
FTS features not very well suited for this kind of service. I not saying that you
can't implement them, just keep in mind that a standard CPU against vCPU could
have a lot difference. If you want to benchmark your local CPU against RDS vCPU,
you can run the following query inside `psql` on both instances:

```
\o /dev/null
\timing
SELECT convert_from(
          pgp_sym_decrypt_bytea(
              pgp_sym_encrypt_bytea('Text to be encrypted using pgp_sym_decrypt_bytea' || gen_random_uuid()::text::bytea,'key', 'compress-algo=2'),
          'key'),
        'SQL-ASCII')
FROM generate_series(1,10000);
```

There are a lot of things and functions you can combine from the `pgcrypto` package
(you will see that the repostory contemplates all of them).
I will try to post another blog post regarding this kind of benchmarks. In the
meantime, this query should be enough to have a rough idea of the performance difference
between RDS instance vCPU and your server CPUs.

## Architecture basics

For this POC we are going to store FTS and GPG keys locally, in a simple PostgreSQL
instance and, using a trigger, encrypt and upload transparently to RDS using the
standard FDW (Foreign Data Wrappers).

Have in mind that RDS communication is already encrypted via SSL when data flows
between server/client. It's important to clarify this, to avoid confusions between
communication encryption and storing data encrypted.

The simple trigger will split the unencrypted data between a local table storing
in a `tsvector` column (jsonb in the TODO), it will encrypt and push the encrypted
data into RDS using FDW (the standard postgres_fdw package).

A simple flight view of the idea can be observed in the image bellow.

[//]: (/Users/emanuel/git/RDS_HIPPA_FTS/FDW_TO_RDS/images/image1.png if using local file)
![alt text](https://raw.githubusercontent.com/3manuek/RDS_HIPAA_FTS/master/FDW_TO_RDS/images/image1.png "Image 1")

Source: https://www.lucidchart.com/documents/edit/c22ce7a1-c09d-4ca8-922d-dcb123d577a5?driveId=0AHk8my7IafcZUk9PVA#


## RDS structure and mirrored local structure with FDW


RDS instance schema structure contains a parent table , a partitioning trigger  and
its trigger:

```
CREATE SCHEMA enc_schema;

SET search_path TO enc_schema;

-- Encrpting locally, that's why we don't need to reference the key here.
create table enc_schema.__person__pgp
     (
      id bigint,
      source varchar(8),
      partial_ssn varchar(4), -- Non encrypted field for other fast search purposes
      ssn bytea,
      keyid varchar(16),
      fname bytea,
      lname bytea,
      description bytea,
      auth_drugs bytea, 		-- This is an encrypted text vector
      patology bytea,
      PRIMARY KEY(id,source)
);

CREATE INDEX ON enc_schema.__person__pgp (partial_ssn);


CREATE OR REPLACE FUNCTION basic_ins_trig() RETURNS trigger LANGUAGE plpgsql AS $basic_ins_trig$
DECLARE
  compTable text :=  TG_RELID::regclass::text ;
  childTable text := compTable || '_' || NEW.source ;
  statement text :=  'INSERT INTO ' || childTable || ' SELECT (' || QUOTE_LITERAL(NEW) || '::'  || compTable ||  ').*' ;
  createStmt text := 'CREATE TABLE ' || childTable  ||
    '(CHECK (source =' || quote_literal(NEW.source) || ')) INHERITS (' || compTable || ')';
  indexAdd1 text := 'CREATE INDEX ON ' || childTable || '(source,id)' ;
  indexAdd2 text := 'CREATE INDEX ON ' || childTable || '(source,ssn)' ;
BEGIN
  BEGIN
    EXECUTE statement;
  EXCEPTION
    WHEN undefined_table THEN
      EXECUTE createStmt;
      EXECUTE indexAdd1;
      EXECUTE indexAdd2;
      EXECUTE statement;
  END;
  RETURN NULL;

END;

$basic_ins_trig$;


CREATE TRIGGER part_person_pgp BEFORE INSERT ON __person__pgp
FOR EACH ROW EXECUTE PROCEDURE basic_ins_trig() ;


```

We are not going to use the `partial SSN` column in the examples, but I found it very helpful to
do RDS searches over encrypted data without fall into the need of decrypting in-the-fly the SSN.
The last SSN's 4-digits do not provide useful information if stolen.

Also, the magic of the multi-source data injection comes from the compound key using a
bigint and a source tag.

Basically, you can think on the local nodes as proxies. You can insert data on every node,
but the data will point to the RDS instance.

If you are planning to manage large amounts of data, you can partition the table on RDS,
allowing a better organization for data management.

You will see no indexes over encrypted data


Local nodes structure:

```
CREATE DATABASE fts_proxy;  --  connect using \c fts_proxy on psql

-- The sauce
CREATE EXTENSION postgres_fdw;
CREATE EXTENSION pgcrypto;

CREATE SERVER RDS_server
        FOREIGN DATA WRAPPER postgres_fdw
        OPTIONS (host 'dbtest1.chuxsnuhtvgl.us-east-1.rds.amazonaws.com', port '5432', dbname 'dbtest');

CREATE USER MAPPING FOR postgres
        SERVER RDS_server
        OPTIONS (user 'dbtestuser', password '<shadowed>');

CREATE FOREIGN TABLE __person__pgp_RDS
(
       id bigint,
       source varchar(8),
       partial_ssn varchar(4), -- Non encrypted field for other fast search purposes
       ssn bytea,
       keyid varchar(16),
       fname bytea,
       lname bytea,
       description bytea,
       auth_drugs bytea, -- This is an encrypted text vector
       patology bytea
)
SERVER RDS_server
OPTIONS (schema_name 'enc_schema', table_name '__person__pgp');
```

Same table. Everytime we want to deal with the RDS table, we are going to do so using the `__person__pgp_RDS` table, which is just a mapping table. We can query this table as any other usual table.

For testing purposes, I also created a table with the same structure as the above with
`__person_rds_RDS_URE` table name and added the `use_remote_estimate 'true'` option.
When enabled, postgres_fdw obtains the row count and estimates from the remote server.


## Inserting keys locally

Just to avoid an extended article, I will skip the GPG key creation commands here. Please follow the instructions on the link at the referece section about keys.

We can insert they keys in several ways, but I found very convenient to use `psql`
features to do so. Once the keys are in place you can use `\lo_import` command:

```
postgres=# \lo_import /var/lib/postgresql/9.4/main/private.key
lo_import 33583
postgres=# \lo_import /var/lib/postgresql/9.4/main/public.key
lo_import 33584
```

The next steps are very straightforward. In a real scenario, you won't probably
want to upload private keys into the table, just for practical purposes of this
article I'm going to do so (only for decrypt data in the SELECT query).

> `pgp_key_id` will return the same key no matter if you use private or public key.

```
CREATE TABLE keys (
   keyid varchar(16) PRIMARY KEY,
   pub bytea,
   priv bytea
);

INSERT INTO keys VALUES ( pgp_key_id(lo_get(33583)) ,lo_get(33584), lo_get(33583));
```

## Splitting data to FTS, encrypt and push into RDS

Now, here is when the tricky part starts. We are going to achieve some functionalities:

- We are going to simulate _routing_ using inheritance on the FTS records. That will allow us to split data as we want and, replicate using Logical Decoding feature between the nodes. I won't include this on the current article just to avoid it to be extense.
- We are going to encrypt using the key that we select on the insert query. If you want a key _per table basis_, you will find easier to hardcode the key id on the `_func_get_FTS_encrypt_and_push_to_RDS`.
- Once the records are encrypted, the function will insert those records to the foreign table (RDS).
- When querying the FTS table, we will be able to determine the source (something like the `routing` technique, you will find this familiar if you played with ElasticSearch). That allow us to make the FTS search transparent to the application, pointing always to the parent table. :dogewow:

> Isn't Postgres cool? :o


### FTS table structures


```
-- Parent table
CREATE TABLE local_search (
  id bigint PRIMARY KEY,
  _FTS tsvector
);
CREATE INDEX fts_index ON local_search USING GIST(_FTS);

-- Child table, suffix local_search_<source>

CREATE TABLE local_search_host1 () INHERITS (local_search);
CREATE INDEX fts_index_host1 ON local_search_host1 USING GIST(_FTS);
```
Doing this, you avoid to have a column with a constant value in the table, consuming unnecessary space. You can have with this method, different names and tables accross the cluster, but always using the same query against `local_search`. You can map/reduce the data if you want to across the nodes, with the very same query.

Is not necessary to only have 1 source or route per node. The only requirement for this is to have different routes per node (combining source and route could increase complexity, however is possible).


## Main code

```
CREATE SEQUENCE global_seq INCREMENT BY 1 MINVALUE 1 NO MAXVALUE;


CREATE TABLE __person__pgp_map
     (
      keyid varchar(16),
      source varchar(8),
      ssn bigint,
      fname text,
      lname text,
      description text,
      auth_drugs text[], -- This is an encrypted text vector
      patology text
    );

CREATE OR REPLACE FUNCTION _func_get_FTS_encrypt_and_push_to_RDS() RETURNS "trigger" AS $$
DECLARE
        secret bytea;
        RDS_MAP __person__pgp_RDS%ROWTYPE;
        FTS_MAP local_search%ROWTYPE;
BEGIN

    SELECT pub INTO secret FROM keys WHERE keyid = NEW.keyid;

    RDS_MAP.source := NEW.source;
    RDS_MAP.fname := pgp_pub_encrypt(NEW.fname, secret);
    RDS_MAP.lname := pgp_pub_encrypt(NEW.lname, secret);
    RDS_MAP.auth_drugs := pgp_pub_encrypt(NEW.auth_drugs::text, secret);
    RDS_MAP.description := pgp_pub_encrypt(NEW.description, secret);
    RDS_MAP.patology := pgp_pub_encrypt(NEW.patology, secret);
    RDS_MAP.ssn := pgp_pub_encrypt(NEW.ssn::text, secret);
    RDS_MAP.partial_ssn := right( (NEW.ssn)::text,4);
    RDS_MAP.id := nextval('global_seq'::regclass);

    RDS_MAP.keyid := NEW.keyid;

    FTS_MAP.id   := RDS_MAP.id;
    FTS_MAP._FTS := (setweight(to_tsvector(NEW.fname) , 'B' ) ||
                   setweight(to_tsvector(NEW.lname), 'A') ||
                   setweight(to_tsvector(NEW.description), 'C') ||
                   setweight(to_tsvector(NEW.auth_drugs::text), 'C') ||
                   setweight(to_tsvector(NEW.patology), 'D')
                    ) ;

    -- Both tables contain same id,source
    INSERT INTO __person__pgp_RDS SELECT (RDS_MAP.*);
    EXECUTE 'INSERT INTO local_search_' || NEW.source || ' SELECT (' ||  quote_literal(FTS_MAP) || '::local_search).* ';
   RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER trigger_befInsRow_name_FTS
BEFORE INSERT ON __person__pgp_map
FOR EACH ROW
EXECUTE PROCEDURE _func_get_FTS_encrypt_and_push_to_RDS();
```

This functions does everything. It inserts the data on RDS and split the data on the corresponding FTS child table. For performance purposes, I didn't want to catch exceptions at insert time (if the child table does not exists, i.e.), but you can also add this feature with an exception block as follows:

```
   BEGIN
    EXECUTE 'INSERT INTO local_search_' || NEW.source || ' SELECT (' ||  quote_literal(FTS_MAP) || '::local_search).* ';
   EXCEPTION WHEN undefined_table THEN
     EXECUTE 'CREATE TABLE local_search_' || NEW.source || '() INHERITS local_search';
   END;
```

The same can be done over the foreign table. More info in "Class HV — Foreign Data Wrapper Error (SQL/MED)" (HV00R -`fdw_table_not_found`).

Check "Appendix A. PostgreSQL Error Codes" on the official manual for references about error codes.


### Inserting data


At insertion time, we are going to push data through a mapping table. The reason for this is that all the encrypted data is stored in `bytea` datatype, and we want to have clear queries instead.

A random data query will look as:

```
INSERT INTO __person__pgp_map
  SELECT
      'host1',  -- source: host1
                -- You can do this better by grabbing this data from a persistent
                -- location
      '76CDA76B5C1EA9AB',
       round(random()*1000000000),
      ('{Romulo,Ricardo,Romina,Fabricio,Francisca,Noa,Laura,Priscila,Tiziana,Ana,Horacio,Tim,Mario}'::text[])[round(random()*12+1)],
      ('{Perez,Ortigoza,Tucci,Smith,Fernandez,Samuel,Veloso,Guevara,Calvo,Cantina,Casas,Korn,Rodriguez,Ike,Baldo,Vespi}'::text[])[round(random()*15+1)],
      ('{some,random,text,goes,here}'::text[])[round(random()*5+1)] ,
      get_drugs_random(round(random()*10)::int),
      ('{Anotia,Appendicitis,Apraxia,Argyria,Arthritis,Asthma,Astigmatism,Atherosclerosis,Athetosis,Atrophy,Abscess,Influenza,Melanoma}'::text[])[round(random()*12+1)]
      FROM generate_series(1,50) ;
```

Did you see the inner comment? Well, probably you want to split by `customer` or any other alias. I'm using this ugly harcoded text just to avoid a long article.

Also, if you want to avoid harcoding as much as posible, you can consider to use a function that returns the host name or routing tag.


### Querying the data

We are almost done! Now we can do  some queries. Here are some examples:

Limiting the matches:

```
# SELECT convert_from(pgp_pub_decrypt(ssn::text::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name)
# FROM __person__pgp_rds as rds JOIN
#       keys ks USING (keyid)
# WHERE rds.id IN (
#                select id
#                from local_search
#                where to_tsquery('Asthma | Athetosis') @@ _fts LIMIT 5)
#   AND rds.source = 'host1';

 source | convert_from
--------+--------------
 host1  | 563588056
(1 row)               

```


All the matches and double check from were the data came from:

```
# SELECT ls.tableoid::regclass, rds.source,
#        convert_from(pgp_pub_decrypt(ssn::text::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name)
# FROM local_search ls JOIN
#     __person__pgp_rds as rds USING (id),
#     keys ks
# WHERE to_tsquery('Asthma | Athetosis') @@ ls._fts;

     tableoid      | source | convert_from
-------------------+--------+--------------
local_search_host1 | host1  | 563588056
(1 row)
```

And, we can't finish the article without showing how to use the ranking (did you see those setweight
functions used in the function? You got it!):

```
#  SELECT rds.id,
#  convert_from(pgp_pub_decrypt(fname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
#  convert_from(pgp_pub_decrypt(lname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
#  ts_rank( ls._FTS, query ) as rank
#    FROM local_search ls JOIN
#         __person__pgp_rds as rds ON (rds.id = ls.id AND rds.source = 'host1') JOIN
#         keys ks USING (keyid),
#         to_tsquery('Mario | Casas | (Casas:*A & Mario:*B) ') query
#    WHERE
#        ls._FTS  @@ query
#    ORDER BY rank DESC;

 id | convert_from | convert_from |   rank   
----+--------------+--------------+----------
 43 | Mario        | Casas        | 0.425549
 61 | Ana          | Casas        | 0.303964
 66 | Horacio      | Casas        | 0.303964
(3 rows)
```

Remember, think that this query is doing FTS, decryption and ranking in just one query, over a local and
a remote server. You can't say that PostgreSQL isn't hipster enough!


I can't continue the article without showing the query plan executed by the local host (using buffers,
  analyze and verbose options).



```
EXPLAIN (buffers,verbose,analyze) SELECT rds.id,
 convert_from(pgp_pub_decrypt(fname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
 convert_from(pgp_pub_decrypt(lname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
 ts_rank( ls._FTS, query ) as rank
   FROM local_search ls JOIN
        __person__pgp_rds as rds ON (rds.id = ls.id AND rds.source = 'host1') JOIN
        keys ks USING (keyid),
        to_tsquery('Mario | Casas | (Casas:*A & Mario:*B) ') query
   WHERE
       ls._FTS  @@ query
   ORDER BY rank DESC;


....
               ->  Materialize  (cost=100.00..117.09 rows=3 width=122) (actual time=62.946..62.971 rows=50 loops=9)
                     Output: rds.id, rds.fname, rds.lname, rds.keyid
                     ->  Foreign Scan on public.__person__pgp_rds rds  (cost=100.00..117.07 rows=3 width=122) (actual time=566.495..566.520 rows=50 loops=1)
                           Output: rds.id, rds.fname, rds.lname, rds.keyid
                           Remote SQL: SELECT id, keyid, fname, lname FROM enc_schema.__person__pgp WHERE ((source = 'host1'::text))
...
 Planning time: 4.931 ms
 Execution time: 2115.919 ms
(45 rows)

```

From the above _Query Plan_ extract, we can see that the partitioning at RDS is transparent for the query.
The execution node in charge of extracting data from the RDS is the _Foreign Scan_, which also
provides the query executed remotely.

Wait a minute. Looks like the remote SQL is somehow dangerous to execute. It is not using the
_id_! There is a reason for that, and its related on how postgres gather the foreign table statistics.
If I use the _remote estimations_ we can see how the remote SQL changes in the Query Plan:

```
 EXPLAIN (ANALYZE, VERBOSE, BUFFERS) SELECT rds.id,
      convert_from(pgp_pub_decrypt(fname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
      convert_from(pgp_pub_decrypt(lname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
      ts_rank( ls._FTS, query ) as rank
        FROM local_search ls,  __person__pgp_rds_URE  rds  JOIN
             keys ks USING (keyid),
             to_tsquery('Mario | Casas | (Casas:*A & Mario:*B) ') query
        WHERE                                                      
            rds.id = ls.id
              AND rds.source = 'host1'
            AND
            ls._FTS  @@ query
        ORDER BY rank DESC;
```

Query Plan (Foreign Scan execution node):

```
...
->  Foreign Scan on public.__person__pgp_rds_ure rds  (cost=100.01..108.21 rows=2 width=1018) (actual time=250.334..250.336 rows=1 loops=31)
      Output: rds.id, rds.source, rds.partial_ssn, rds.ssn, rds.keyid, rds.fname, rds.lname, rds.description, rds.auth_drugs, rds.patology
      Remote SQL: SELECT id, keyid, fname, lname FROM enc_schema.__person__pgp WHERE ((source = 'host1'::text)) AND (($1::bigint = id))
...
```

Foreign tables also need the local statistics to be updated. In the next examples
there are 3 queries: using the `use_remote_estimate`, without previous ANALYZE and
without `use_remote_estimate` and a query using the local estimations (`__person_pgp_rds`)
after issuing ANALYZE and without _URE_.


```
fts_proxy=# \o /dev/null
fts_proxy=#  SELECT rds.id,
      convert_from(pgp_pub_decrypt(fname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
      convert_from(pgp_pub_decrypt(lname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
      ts_rank( ls._FTS, query ) as rank
        FROM local_search ls,  __person__pgp_rds_URE  rds  JOIN
             keys ks USING (keyid),
             to_tsquery('Mario | Casas | (Casas:*A & Mario:*B) ') query
        WHERE
            rds.id = ls.id
              AND rds.source = 'host1'
            AND
            ls._FTS  @@ query
        ORDER BY rank DESC;
Time: 12299,691 ms

fts_proxy=#  SELECT rds.id,
      convert_from(pgp_pub_decrypt(fname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
      convert_from(pgp_pub_decrypt(lname::bytea, ks.priv,''::text)::bytea,'SQL_ASCII'::name),
      ts_rank( ls._FTS, query ) as rank
        FROM local_search ls,  __person__pgp_rds  rds  JOIN
             keys ks USING (keyid),
             to_tsquery('Mario | Casas | (Casas:*A & Mario:*B) ') query
        WHERE
            rds.id = ls.id
              AND rds.source = 'host1'
            AND
            ls._FTS  @@ query
        ORDER BY rank DESC;
Time: 20249,719 ms

-- AFTER ANALYZE on the FOREIGN TABLE __person_pgp_rds (in the local server)

Time: 1656,912 ms

```

After analyzing both foreign tables , the execution time difference was calculated
at 11% in favor of using local estimations.


> NOTE about UPDATES: it is necessary to code the UPDATE trigger also, in order to
> decrypt , modify and re-encrypt the data.


### Json/jsonb datatype is here to help

You can collapse all the data and use `json` datatype on the mapping and foreign table, allowing you to avoid the pain of pointing and decrypting data per column basis.

Put all the encrypted columns in a `bytea` column on RDS. The mapping table will look as follows:

```
CREATE TABLE __person__pgp_map
     (
      keyid varchar(16),
      source varchar(8),
      ssn bigint,
      data jsonb
    );
```

At insert time, just use a json column instead per column basis. Keep in mind that you will need to deal within the json contents.
I found using this easier for insert, but the FTS needs some clean up to avoid insert column names in the `_fts` field at `local_search` tables.
Also, for updates, the jsonb datatype will need extra work when extracting attributes.


## Additional functions used here

In the insert statement above, you will see a user defined function that gets a random length vector of drugs. It is implemented using the following code:


```
CREATE TABLE drugsList ( id serial PRIMARY KEY, drugName text);

INSERT INTO drugsList(drugName) SELECT p.nameD FROM regexp_split_to_table(
'Acetaminophen
Adderall
Alprazolam
Amitriptyline
Amlodipine
Amoxicillin
Ativan
Atorvastatin
Azithromycin
Ciprofloxacin
Citalopram
Clindamycin
Clonazepam
Codeine
Cyclobenzaprine
Cymbalta
Doxycycline
Gabapentin
Hydrochlorothiazide
Ibuprofen
Lexapro
Lisinopril
Loratadine
Lorazepam
Losartan
Lyrica
Meloxicam
Metformin
Metoprolol
Naproxen
Omeprazole
Oxycodone
Pantoprazole
Prednisone
Tramadol
Trazodone
Viagra
Wellbutrin
Xanax
Zoloft', '\n') p(nameD);

CREATE OR REPLACE FUNCTION get_drugs_random(int)
       RETURNS text[] AS
      $BODY$
      WITH rdrugs(dname) AS (
        SELECT drugName FROM drugsList p ORDER BY random() LIMIT $1
      )
      SELECT array_agg(dname) FROM rdrugs ;
$BODY$
LANGUAGE 'sql' VOLATILE;
```


## References

A very awesome tutorial about FTS for PostgreSQL can be found [here](http://www.sai.msu.su/~megera/postgres/fts/doc/appendixes.html).

[Source for drugs list](http://www.drugs.com/drug_information.html)

[Source for diseases](https://simple.wikipedia.org/wiki/List_of_diseases)

[Getting started with GPG keys](https://www.gnupg.org/gph/en/manual/c14.html)

[AWS command line tool](https://aws.amazon.com/cli/)

Discussion in the community mailing lis [here](http://postgresql.nabble.com/Fast-Search-on-Encrypted-Feild-td1863960.html)
