#!/bin/bash
git add --all && bundle exec jekyll build && git commit -a -m "${1}." && git push
