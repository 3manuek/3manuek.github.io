---
layout: post
title:  "Go-Plus and Atom GOPATH fix"
date:   2016-10-05
description: A fix for the unloaded GOPATH.
tags : [Golang, Go, Atom]
categories:
- Golang
- Atom
category: blog
comments: true
tagline: A fix for the unloaded GOPATH.
permalink: goplusatomcopath
---

## The background

Golang is an awesome language, but I found it pretty unstable within the environment variables (at least in macOS Sierra/El Capitan). `gvm` is your friend btw, and it helped me to fix some of the issues by installing the latest release candidate of the 1.7.1 series.

Keep in mind that if you want to upgrade your macOS to Sierra, you'll  need to backup all of your environment variables and reinstall `gvm`.

Atom has a plugin for Golang, which is `go-plus`, and if you are reading this is because the documentation around isn't very helpful.

## The problem

GOPATH is not been loaded! Also you may see several errors when Atom is trying to get packages using `go-get`. Nor neither GOBIN environment variable.

Also, I've been having issues with the following (gocode is one of the packages for the Atom's plugin, but it does happen with any package):

```
go install github.com/nsf/gocode: open /bin/gocode: operation not permitted
```


## The solution

The solution for the GOPATH is simple. There is a _warning_ when this happens but it's been added recently, with the HINT to start from the command line for fixing this.

That's easy. An `atom &` from terminal should fix this by loading the environment variables. However, keep in mind that GOBIN needs to be on the path! You may need to create a bin folder in your _go workspace_. Also, don't forget to add those variables into your shell _.*rc_ file (.bashrc, .zshrc, .profile).

i.e.

```
mkdir -p ~/go/bin
export GOPATH=$HOME/go
export GOBIN=$HOME/go/bin
nohup atom &
```

Hope it fixes your day!

{% if page.comments %}
<div id="disqus_thread"></div>
<script>


var disqus_config = function () {
this.page.url = {{ site.url }};  // Replace PAGE_URL with your page's canonical URL variable
this.page.identifier = {{ page.title }}; // Replace PAGE_IDENTIFIER with your page's unique identifier variable
};

(function() { // DON'T EDIT BELOW THIS LINE
var d = document, s = d.createElement('script');
s.src = '//3manuek.disqus.com/embed.js';
s.setAttribute('data-timestamp', +new Date());
(d.head || d.body).appendChild(s);
})();
</script>
<noscript>Please enable JavaScript to view the <a href="https://disqus.com/?ref_noscript">comments powered by Disqus.</a></noscript>
{% endif %}
