#!/bin/bash
bundle exec jekyll build && git add --all && git commit -a -m "${1}." && git push
