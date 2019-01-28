
.PHONY:= build build-watch install-req

install-req:
	bundle install

build:
	bundle exec jekyll build

build-watch:
	bundle exec jekyll serve --watch --config=_config-dev.yml

fuck: build
	git commit -a -m "Release $$(date)" && git push origin master