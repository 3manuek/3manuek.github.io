---
layout: post
title:  "Internal Load Balancing in GCP with Terraform"
subtitle: "Avoiding legacy code and briefing what is propagated in hundreds of documentation pages"
date:   2019-01-24
description: Avoiding legacy code and briefing what is propagated in hundreds of documentation pages.
tags : [Terraform]
categories:
- Terraform
- GoogleCloud
category: blog
comments: true
permalink: terraformgcpilb
author: 3manuek
---


## GCP iLB and Terraform integration

Implementing an Internal Load Balancing in GCP through Terraform wasn't smooth,
specially if your resources rely on HTTP health checks. I do emphasis on the _internal_ as
even tho the Google console web assistant looks pretty much the similar with its
_external_ conterpart, its Terraform implementation vary in between strongly.

> It is recommended a full read of [Google Cloud load balancing](https://cloud.google.com/load-balancing/docs/internal/) documentation

iLB is widely used for backend services such as Database components or stateful components
that require an entity or snapshot consistency and that are not accessible to the world. This characteristic
discards certain resources such as the Target Pool for the iLB, meaning that all the routing and scaling
of the connections from the Load balancer will be provided by the Backend Service resource.

Setting up a Load Balancer will depend on which resources have been choose for spinning the computes. That is,
`google_compute_region_instance_group_manager`, `google_compute_instance_group_manager` and single computes. In this particular post
I'm going to stick to `google_compute_region_instance_group_manager` for the sake of abstraction.

There is a legacy resource called [`google_compute_http_health_check`](https://www.terraform.io/docs/providers/google/r/compute_http_health_check.html), which contains the following note:

> Note: google_compute_http_health_check is a legacy health check. The newer google_compute_health_check 
> should be preferred for all uses except Network Load Balancers which still require the legacy version.

The final resource will end up with an iLB pointing to those nodes that return OK to the corresponding Health Check
(reqpath + port through HTTP in this case). This is pretty useful if the state of the computes are served through
an API backed with a DCS, meaning that the whole cluster of computes will be consistent to that view. In stateful
services you will access a single machine of the cluster for RW transactions or, access only certain group of machines
that return OK on the requested method/port.

If you happen to use Consul agents, you can provide such API to make your architecture consistent through consensus, erradicating
split brain scenarios or data inconsitency during failovers.


## Resource Map of an iLB

The flight view of the basic architecture of an iLB will look like this in a diagram:


![iLB Image][1]{: class="bigger-image" }
<figcaption class="caption">Flight view of the iLB Terraform resources.</figcaption>



## Instance Managed Groups

For the internal Load Balancing, there is nothing to parametrize here except for the AutoHealing block, which
will point to the corresponding Health Check. Usually, for stateless services, we use the same Health Check 
for the autohealing (or, at least is functional to do so); although, stateful services such databases, can 
return _not available_ (503) response code from the API but it does not mean that the service is down, as it might have more 
complex statuses depending the request path/method (service is up, but can't receive writes).

It is important to define an initial delay for checking the service, specially on stateful components that could spend certain time before they
are available due to data transfers or provisioning. During development, you may want to wipe this block out, until 
your services are available, in the contrary the computes will be destroy in an endless loop.

```hcl
  auto_healing_policies {
    health_check = "${google_compute_health_check.tcp_hc.self_link}"
    initial_delay_sec = "${var.initial_delay_sec}"
  }
```

As we are setting up an iLB, `google_compute_region_instance_group_manager` has been choose as it is compatible with its 
setup. This resource manages computes across a region, through several availability zones.

## Health Checks

Consider an API through port 8008, wether it returns 503/200 response codes over master/replica methods.
The bellow output shows the responses for both methods over the same **master** node:

```
curl -sSL -D -  http://127.0.0.1:8008/master
HTTP/1.0 200 OK
...

curl -sSL -D -  http://127.0.0.1:8008/replica
HTTP/1.0 503 Service Unavailable
...
```

These methods can be used for the Backend Service configuration for refreshing the iLB node that act as master
or those for replicas (for RO iLB).

It is important to clarify that creating Health Check does not affect the other resources unless linked. You will
prefer to define this resource even if your services aren't up and running, as you can _plug it_ once they are 
available (as it will be shown in the Backend Service section).

Even tho, it is possible to setup iLB using the new resource and using its corresponding setup through
the `http_health_check`/`tcp_health_check` block:

```hcl
resource "google_compute_health_check" "http_hc" {
  name                = "${var.name}-health-check"
  check_interval_sec  = 10
  timeout_sec         = 10
  healthy_threshold   = 2
  unhealthy_threshold = 10

  description = "this HC returns OK depending on the method"

  http_health_check {
    request_path = "/${var.reqpath}"
    port         = "${var.hcport}"
  }
}

resource "google_compute_health_check" "tcp_hc" {
  name                = "${var.name}-health-check"
  check_interval_sec  = 10
  timeout_sec         = 10
  healthy_threshold   = 2
  unhealthy_threshold = 10

  description = "this HC is for autohealing and returns OK if service is up"

  tcp_health_check {
    port         = "${var.hcport}"
  }
}
```

> The autohealing health check can either be TCP or HTTP, just make sure that the HTTP API method
> returns _not available_ **only** if the service is completely down.

More read available at [Health Check/ Legacy Health Checks](https://cloud.google.com/load-balancing/docs/health-checks#legacy_health_checks).

## Backend Service

Particularly in this case, the corresponding resource for `google_compute_region_instance_group_manager` is `google_compute_region_backend_service`.
This resource needs: 1) Which instances are in the backend, 2) which health check is in use to determine the available nodes.

An example of this would be the following:

```
resource "google_compute_region_backend_service" "instance_group_backendservice" {
  name             = "${var.name}-rig-bs"
  description      = "Region Instance Group Backend Service"
  protocol         = "TCP"
  timeout_sec      = 10
  session_affinity = "NONE"

  backend {
    group = "${google_compute_region_instance_group_manager.instance_group_manager.instance_group}"
  }

  health_checks = ["${google_compute_health_check.http_hc.self_link}"]
}
```

The `backend` block provices the instances created by `google_compute_region_instance_group_manager` and `health_checks`
point to the predefined HC above. One backend service can point to several Health Checks like built in the [google-lb-internal](https://github.com/GoogleCloudPlatform/terraform-google-lb-internal/blob/master/main.tf#L42-L71):


```
resource "google_compute_region_backend_service" "default" {
...
  health_checks    = ["${element(compact(concat(google_compute_health_check.tcp.*.self_link,google_compute_health_check.http.*.self_link)), 0)}"]
}

resource "google_compute_health_check" "tcp" {
  count = "${var.http_health_check ? 0 : 1}"
  project = "${var.project}"
  name    = "${var.name}-hc"

  tcp_health_check {
    port = "${var.health_port}"
  }
}

resource "google_compute_health_check" "http" {
  count = "${var.http_health_check ? 1 : 0}"
  project = "${var.project}"
  name    = "${var.name}-hc"

  http_health_check {
    port = "${var.health_port}"
  }
}
```

Keep in mind that we are setting an internal Load Balancer, which is compatible with `google_compute_region_backend_service` ,
diverging from the external Load Balancer that require `google_compute_backend_service`. The difference is the level of the abstraction
when provisioning nodes, which in the external, you need to end up defining resources more explicitely than using internal.


> Note: Region backend services can only be used when using internal load balancing. For external load balancing, 
> use google_compute_backend_service instead. [Terraform Doc](https://www.terraform.io/docs/providers/google/r/compute_region_backend_service.html)

## Forwarding Rule


The Forwarding Rule is a resource that will define the LB options, in which the most noticeable are: 1) `load_balancing_scheme` and
2) `backend_service`. The `load_balancing_scheme` change will require considerable changes on the architecture, so you need to 
define this before hand when blackboarding your infra. Regarding the backend_service, this needs to point to the corresponding 
backend_service than you spin for the Instance Managed Group.

```hcl
resource "google_compute_forwarding_rule" "main_fr" {
  project               = "${var.project}"
  name                  = "fw-rule-${var.name}"
  region                = "${var.region}"
  network               = "${var.network}"

  backend_service       = "${google_compute_region_backend_service.instance_group_backendservice.self_link}"
  load_balancing_scheme = "INTERNAL"
  ports                 = ["${var.forwarding_port_ranges}"]

  ip_address            = ["${google_compute_address.ilb_ip.address}"]
}
```

It is a common practice to predefine a compute address for the iLB instead leaving GCP choose one for us and, going further, you can prevent 
this resource to be destroyed accidentaly, as this IP is an entrypoint for your application and might be coded in a different 
piece of architecture:

```hcl
resource "google_compute_address" "ilb_ip" {
  name         = "${var.name}-theIP"
  project      = "${var.project}"

  region       = "${var.region}"
  address_type = "INTERNAL" 

  lifecycle {
    prevent_destroy = true
  }
  
}
```

## Don't forget the Firewall Rules!

All the above resources are core to the iLB setup, although there is one resource that even tho isn't strictly
part of the component, it must be specified to allow services and computes talk to each other. In this case, the
source_ranges should match the corresponding subnet setup of all the above resources. If you happen to be in development
phase, you can use `0.0.0.0/0` for wide opening the rule, although you may want to specify a narrow IP range in production.

```
resource "google_compute_firewall" "default-lb-fw" {
  project = "${var.project}"
  name    = "${format("%v-%v-fw-ilb",var.name,count.index)}"
  network = "${var.network}"

  allow {
    protocol = "tcp"
    ports    = ["${var.forwarding_port_ranges}"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.tags}"]
}
```


Hope you liked this post, do not hesitate to point questions and comments!


[1]: http://www.3manuek.com/assets/posts/ilb.png
