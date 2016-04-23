---
layout: default
title: MySQL category
---
<div class="page-content wc-container">
  <h1>PostgreSQL entries</h1>  
  {% for post in site.posts %}
  	{% capture currentyear %}{{post.date | date: "%Y"}}{% endcapture %}
  	{% if currentyear != year %}
    	{% unless forloop.first %}</ul>{% endunless %}
    		<h5>{{ currentyear }}</h5>
    		<ul class="posts">
    		{% capture year %}{{currentyear}}{% endcapture %}
  		{% endif %}
    {% capture postcategories %}{{ post.categories }}{% endcapture %}
    {% if postcategories ~ /.*PostgreSQL.*/ %}
      <li><a href="{{ post.url | prepend: site.baseurl }}">{{ post.title }}</a></li>
     {% endif %}
   {% endfor %}
</div>
