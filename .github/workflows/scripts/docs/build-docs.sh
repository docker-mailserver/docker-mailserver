#!/bin/bash
set -eo pipefail

# `--user` is required for build output file ownership to match the CI user,
#  instead of the internal root user of the container.
docker run \
  --rm \
  --user "$(id -u):$(id -g)" \
  -v "${PWD}:/docs" \
  --name "prepare-docs" \
  squidfunk/mkdocs-material:7.3.0 build --strict

# Remove unnecessary build artifacts: https://github.com/squidfunk/mkdocs-material/issues/2519
cd site
find . -type f -name '*.min.js.map' -delete -o -name '*.min.css.map' -delete
rm sitemap.xml.gz
rm assets/images/favicon.png
rm -r assets/javascripts/lunr
