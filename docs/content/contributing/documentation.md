---
title: 'Contributing | Documentation'
---

## Prerequisites

You will need have Python and Python pip installed. Or just docker.

## Building and serving the documentation

This tutorial was written using Python `2.7.18` and Python pip `20.3.4`.
And Docker `19.03.6`.

### Python way

#### Install the modules

The documentation builder

```sh
pip install mkdocs
```

Now the theme

```sh
pip install mkdocs-material
```

#### Serve

!!! note "Note: be sure to be in the docs folder (`cd ./docs/`)"

```sh
mkdocs serve
```

Wait for it to build and open the URL in your browser.
Each change will be hot-reloaded onto the page you view, just edit, save and look at the result.

### Docker way

Using the official image ([squidfunk/mkdocs-material](https://hub.docker.com/r/squidfunk/mkdocs-material)) for our documentation theme.

#### Serve

!!! note "Note: be sure to be in the docs folder (`cd ./docs/`)"

```sh
docker run --rm -it -p 8000:8000 -v "${PWD}:/docs" squidfunk/mkdocs-material
```

Each change will be hot-reloaded onto the page you view, just edit, save and look at the result.
