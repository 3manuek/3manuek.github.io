---
layout: post
title:  "redshift."
date:   2016-08-01
description: A full overview.
tags : [PostgreSQL, Redshift]
categories:
- Redshift
permalink: redshift
---


STV tables are actually virtual system tables that contain snapshots of the current system data.

http://docs.aws.amazon.com/redshift/latest/dg/c_intro_STV_tables.html

STL Tables for Logging  http://docs.aws.amazon.com/redshift/latest/dg/c_intro_STL_tables.html

SV (system views)

http://docs.aws.amazon.com/redshift/latest/dg/c_intro_system_views.html


https://aws.amazon.com/redshift/faqs/



class Meta:
        db_table = 'request_stats_2015'
        diststyle = base.RedshiftDiststyles.KEY
        distkey = 'identity_id'
        sortkey = ('created_at', 'store_id', 'resource_type', 'action')
        compression = dict(
            id=base.RedshiftCompressionTypes.BYTEDICT,
            created_at=base.RedshiftCompressionTypes.DELTA32K,
            store_id=base.RedshiftCompressionTypes.BYTEDICT,
            identity_id=base.RedshiftCompressionTypes.BYTEDICT,
            remote_address=base.RedshiftCompressionTypes.BYTEDICT,
            resource_type=base.RedshiftCompressionTypes.BYTEDICT,
            resource_id=base.RedshiftCompressionTypes.TEXT255,
            action=base.RedshiftCompressionTypes.TEXT255,
            os=base.RedshiftCompressionTypes.BYTEDICT,
            client=base.RedshiftCompressionTypes.BYTEDICT,
            data=base.RedshiftCompressionTypes.LZO
        )




https://github.com/iMedicare/shared/blob/master/imedicare/shared/historical/request_stat.py#L29-L45



Distribution of reads across disks:


```
historical=# select host , diskno, sum(reads),sum(writes),sum(mbps),sum(seek_forward), sum(seek_back), max(used) from stv_partitions group by 1,2;
 host | diskno |  sum  |   sum   | sum | sum  | sum  |  max  
------+--------+-------+---------+-----+------+------+-------
    1 |      0 |  8408 | 1667511 |   0 | 2915 | 2273 | 90125
    2 |      0 | 20194 | 1523545 |   0 | 9389 | 4061 | 96542
    0 |      0 |  8010 | 1611316 |   0 | 2838 | 2235 | 96542
(3 rows)
```

http://docs.aws.amazon.com/redshift/latest/dg/r_STV_PARTITIONS.html




explain  SELECT max(created_at) as created_at
from request_stats_2015
WHERE ((("resource_type" = 'patients') AND
           ("store_id" = '7f419e906bfe578faef5277c7fc9fb80')) 
AND  ("remote_address" <> '10.0/16')) 






explain SELECT max(t1.created_at), t1.client
FROM 
( SELECT created_at, client
request_stats_2015
WHERE ((("resource_type" = 'tokens') AND
           ("store_id" = '7f419e906bfe578faef5277c7fc9fb80')) AND
          NOT ("remote_address" ILIKE '10.0.%')) 
  ORDER BY created_at DESC LIMIT 1
) t1                                                                                                                                                                                                                     


explain 

SELECT
  (SELECT max("t2"."created_at")
   FROM "request_stats_2015" AS t2
   WHERE ((("t2"."resource_type" = 'tokens') AND
           ("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80')) AND
          NOT ("t2"."remote_address" ILIKE '10.0.%')))                                                                                                                                                                                                                           AS last_login_at,
  (SELECT "t2"."client"
   FROM "request_stats_2015" AS t2
   WHERE ((("t2"."resource_type" = 'tokens') AND
           ("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80')) AND
          NOT ("t2"."remote_address" ILIKE '10.0.%'))
   ORDER BY "t2"."created_at" DESC
   LIMIT 1)                                                                                                                                                                                                                                                                      AS last_browser_used,
  (SELECT count('*')
   FROM "request_stats_2015" AS t2
   WHERE ((("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80') AND
           NOT ("t2"."remote_address" ILIKE '10.0.%')) AND
          ((("t2"."resource_type" = 'patients') AND ("t2"."action" = 'read'))
           AND ("t2"."data" ILIKE
                '%ref%'))))                                                                                                                                                                                                                                                      AS opened_reports_count,
  (SELECT count('*')
   FROM "request_stats_2015" AS t2
   WHERE ((("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80') AND
           NOT ("t2"."remote_address" ILIKE '10.0.%')) AND
          (("t2"."resource_type" = 'click_resource') AND ("t2"."action" =
                                                          'created'))))                                                                                                                                                                                                          AS opened_library_count,
  (SELECT count('*')
   FROM "request_stats_2015" AS t2
   WHERE ((("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80') AND
           NOT ("t2"."remote_address" ILIKE '10.0.%')) AND
          ("t2"."resource_type" IN
           ('click_print_preview_eligible_letter', 'click_manage_interventions', 'click_report_compare_plans', 'click_opportunity_reach_out', 'click_opportunity_manage_drugs', 'click_opportunity_review_plans', 'click_opportunity_view_profile', 'click_schedule_message')))) AS report_actions_count,
  (SELECT count('*')
   FROM "request_stats_2015" AS t2
   WHERE ((("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80') AND
           NOT ("t2"."remote_address" ILIKE '10.0.%')) AND
          ("t2"."resource_type" =
           'click_print_letter')))                                                                                                                                                                                                                                               AS print_letter_count,
  (SELECT count('*')
   FROM "request_stats_2015" AS t2
   WHERE ((("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80') AND
           NOT ("t2"."remote_address" ILIKE '10.0.%')) AND
          ("t2"."resource_type" =
           'click_email_letters')))                                                                                                                                                                                                                                              AS email_letters_count,
  (SELECT count('*')
   FROM "request_stats_2015" AS t2
   WHERE ((("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80') AND
           NOT ("t2"."remote_address" ILIKE '10.0.%')) AND
          ("t2"."resource_type" =
           'click_schedule_call')))                                                                                                                                                                                                                                              AS schedule_call_count,
  (SELECT count('*')
   FROM "request_stats_2015" AS t2
   WHERE ((("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80') AND
           NOT ("t2"."remote_address" ILIKE '10.0.%')) AND
          ("t2"."resource_type" =
           'click_schedule_calls')))                                                                                                                                                                                                                                             AS schedule_calls_count,
  (SELECT count('*')
   FROM "request_stats_2015" AS t2
   WHERE ((("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80') AND
           NOT ("t2"."remote_address" ILIKE '10.0.%')) AND
          ("t2"."resource_type" =
           'click_opportunity')))                                                                                                                                                                                                                                                AS opportunity_count,
  ((SELECT count(DISTINCT ("t2"."resource_id"))
    FROM "request_stats_2015" AS t2
    WHERE ((("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80') AND
            NOT ("t2"."remote_address" ILIKE '10.0.%')) AND
           ("t2"."resource_type" = 'click_print_preview_plans'))) +
   (SELECT count(DISTINCT ("t2"."resource_id"))
    FROM "request_stats_2015" AS t2
    WHERE ((("t2"."store_id" = '7f419e906bfe578faef5277c7fc9fb80') AND
            NOT ("t2"."remote_address" ILIKE '10.0.%')) AND
           ("t2"."resource_type" =
            'click_print_preview_comparison'))))                                                                                                                                                                                                                                 AS printed_comparisons_count
FROM (SELECT 1) AS void;





