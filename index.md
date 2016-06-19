---
layout: page
title: The Front Page
tagline: {{ page.tagline }}
---
{% include JB/setup %}

## Who am I?

![alt text](assets/whoami.gif "Who am I? Zoolander")


Hi there! I'm Emanuel Calvo, a Database Consultant and Data Engineer _currently_ located in
Buenos Aires, Argentina.

Working in the Open Source community, as a way to enhance society and promote
free and open knowledge. If there is something that made humans as they are today,
is _intelligence_. Been said, contributing to Open Knowledge is the way that
humanity can evolve into a more respectful environment within earth and other beings.

Also, I'm a responsible Cannabis growing supporter, as part of the exercise of freedom,
against an unfair, outdated and counterproductive law for citizens, which are forced
to illegality thanks for corrupted politics, modern slavery and _black market "lobby"_.


_Disclaimer_

> This is a personal site. All opinions expressed here, do not represent those of my employer.

-----

## Current Posts

<ul class="posts">
  {% for post in site.posts %}
    <li><span>{{ post.date | date_to_string }}</span> &raquo; <a href="{{ BASE_PATH }}{{ post.url }}">{{ post.title }}</a></li>
  {% endfor %}
</ul>


-----

This theme is still unfinished. If you'd like to be added as a contributor, [please fork](http://github.com/plusjade/jekyll-bootstrap)! :.
