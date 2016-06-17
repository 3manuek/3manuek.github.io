---
layout: page
title: Home Page
tagline: Data Engineering & others
---
{% include JB/setup %}

## Who is me?

Hi there! I'm Emanuel Calvo, a Database Consultant and Data Engineer located in
Buenos Aires, Argentina.


## Disclaimer

This is a personal site. All opinions expressed here, do not represent those of my employer.


## Current Posts

<ul class="posts">
  {% for post in site.posts %}
    <li><span>{{ post.date | date_to_string }}</span> &raquo; <a href="{{ BASE_PATH }}{{ post.url }}">{{ post.title }}</a></li>
  {% endfor %}
</ul>


--

This theme is still unfinished. If you'd like to be added as a contributor, [please fork](http://github.com/plusjade/jekyll-bootstrap)! :.
