---
layout: page
title: The Front Page
---

{% include JB/setup %}

## Who am I?

Hi there! I'm Emanuel Calvo, a Datanerd and Consultant _currently_ located in
Buenos Aires, Argentina.

Working in the Open Source community, as a way to enhance society and promote
free and open knowledge. If there is something that made humans as they are today,
is _intelligence_. Been said, contributing to Open Knowledge is the way that
humanity can evolve into a more respectful environment within earth and other beings.

I'm a Net Party pair member (_par del Partido de la Red_). Check the [platform](https://docs.partidodelared.org).


_Disclaimer_

> This is a personal site. All opinions expressed here, do not represent those of my employer.


## Current Posts

<ul class="posts">
  {% for post in site.posts %}
    <li><span>{{ post.date | date_to_string }}</span> &raquo; <a href="{{ BASE_PATH }}{{ post.url }}">{{ post.title }}</a></li>
  {% endfor %}
</ul>


--


![alt text](assets/whoami.gif "Who am I? Zoolander")


This theme is still unfinished. If you'd like to be added as a contributor, [please fork](http://github.com/plusjade/jekyll-bootstrap)! .•.
