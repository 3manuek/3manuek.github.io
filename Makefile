
.PHONY:= build build-watch

build:
	bundle exec jekyll build

build-watch:
	bundle exec jekyll serve --watch

fuck: build
	git commit -a -m "Release $$(date)" && git push