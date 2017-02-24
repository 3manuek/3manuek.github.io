---
layout: page
title: The Front Page
---

{% include JB/setup %}

## An introduction

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
.•.

## Para mis pares _hispano parlantes_

Suelo tener contactos de tanto en tanto, respecto a consultas relativas de como
es trabajar en empresas extranjeras, haciendo WFH (_work from home_).

Yo creo que existen dos bases para emprender en el rubro: la comunicación
y _hacer_. La comunicación es no solo se limita al como uno se expresa, sino también ser
legible. Tenés que aprender no solo el lenguaje, sino también mucho de aspectos culturales
<sup>[1]</sup>.

Hacer. Esto afecta más al WFH, ya que te permite mantenerte ocupado en la franja
más continua posible. Evitar breaks largos, para tener una jornada corta. El primer
paso es lograr quedar libre en horario, el segundo es marcarse actividades.

Si es posible, trabaja primero _en oficinas_ y practica cara a cara. Trabajar remoto
y no tener buena comunicación, harán que tu jornada laboral se extienda, por tener
menor capacidad de respuesta. Ten esto en claro si es que no has tenido opción.

Cuando empecé, fue un proceso bastante duro y varias veces te topas con situaciones
_raras_ en las que podía notar un acento de discriminación. Es normal, que sepas
que hay gente para todo y la globalización no filtra ideologías. Algunas cosas que ayudan
son: ver películas en idioma original con subtítulos en inglés (o el idioma que uses), leer libros no-técnicos, hablar de cosas cotidianas con tus colegas nativos, meterse en las comunidades
y prestar atención a los acentos (ejercitar escuchar y tratar de diferenciarlos).


[1] Un muy buen libro es [El mapa cultural](http://erinmeyer.com/book/). Lamentablemente
no hay una versión en español al momento.


--

Support this theme, [fork](http://github.com/plusjade/jekyll-bootstrap)!
