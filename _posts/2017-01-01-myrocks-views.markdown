---
title: "MyRocks Views"
layout: post
date: 2017-01-01 22:10
tag: scripts
# image: images/alambre.jpg # https://koppl.in/indigo/assets/images/jekyll-logo-light-solid.png
headerImage: true
projects: true
hidden: true # don't count this post in blog pagination
description: "Extending the current catalogs in MyRocks."
jemoji: '<img class="emoji" title=":wrench:" alt=":wrench:" src="https://assets-cdn.github.com/images/icons/emoji/unicode/1f527.png" height="20" width="20" align="absmiddle">'
category: project
author: 3manuek
externalLink: false
---

[MyRocks][1] is an storage engine available also in MongoDB, focused on performance
and space saving. It is a LSM tree, with Bloom filtering for unique keys, providing
steady performance in limited amount of cache. Installing can be done through
a 5.6 fork, [repository here][3].

Installing is easy as importing the sql file into your database.

Repository can be found [here][2].

---

What has inside?

- SQL    

---

[1]: http://myrocks.io/
[2]: https://github.com/3manuek/myrocks_views
[3]: https://github.com/facebook/mysql-5.6
