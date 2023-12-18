#!/bin/bash
set -ex

# PWD should be at the project docs/ folder.
# `--user` is required for build output file ownership to match the CI user,
#  instead of the internal root user of the container.
# `build --strict` ensures the build fails when any warnings are omitted.
docker run \
  --rm \
  --user "$(id -u):$(id -g)" \
  --volume "${PWD}:/docs" \
  --name "build-docs" \
  squidfunk/mkdocs-material:9.2 build --strict

# Remove unnecessary build artifacts: https://github.com/squidfunk/mkdocs-material/issues/2519
# site/ is the build output folder.
cd site
find . -type f -name '*.min.js.map' -delete -o -name '*.min.css.map' -delete
rm sitemap.xml.gz
rm assets/images/favicon.png
rm -r assets/javascripts/lunr
