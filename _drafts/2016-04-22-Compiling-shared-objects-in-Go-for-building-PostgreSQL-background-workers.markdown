---
layout: post
title:  "Compiling shared objects in Go language for building PostgreSQL blocks."
date:   2016-04-22
description: Compiling Go lang shared objects for building PostgreSQL compatible code.
categories:
- blog
- PostgreSQL
permalink: sha-obj-go-pg
---

## Objective

Building complex services require more complex and modern languages. Although C
is still the primary choice for the PostgreSQL project, is not uncommon to see
tools written in several languages.

This POC will guide you to build a basic background worker for PostgreSQL, compiled
in Go language through the BW framework.
