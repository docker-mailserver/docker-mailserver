---
title: 'Contributing | General Information'
---

## Coding Style

When refactoring, writing or altering scripts or other files, adhere to these rules:

1. **Adjust your style of coding to the style that is already present**! Even if you do not like it, this is due to consistency. There was a lot of work involved in making all scripts consistent.
2. **Use `shellcheck` to check your scripts**! Your contributions are checked by GitHub Actions too, so you will need to do this. You can **lint your work with `make lint`** to check against all targets.
3. **Use the provided `.editorconfig`** file.
4. Use `/bin/bash` instead of `/bin/sh` in scripts

## Documentation

Make sure to select `edge` in the dropdown menu at the top. Navigate to the page you would like to edit and click the edit button in the top right. This allows you to make changes and create a pull-request.

Alternatively you can make the changes locally. For that you'll need to have Docker installed and run:

```sh
# From the root directory of the git clone:
docker run --rm -it -p 8000:8000 -v "./docs:/docs" squidfunk/mkdocs-material
```

This serves the documentation on your local machine on port `8000`. Each change will be hot-reloaded onto the page you view, just edit, save and look at the result.

!!! note

    The container logs will inform you of invalid links detected, but a [few are false-positives][gh-dms::mkdocs-link-error-false-positives] due to our usage of linking to specific [content tabs][mkdocs::content-tabs].

[get-docker]: https://docs.docker.com/get-docker/
[docs-bats-parallel]: https://bats-core.readthedocs.io/en/v1.8.2/usage.html#parallel-execution
[gh-dms::mkdocs-link-error-false-positives]: https://github.com/docker-mailserver/docker-mailserver/pull/4366
[mkdocs::content-tabs]: https://squidfunk.github.io/mkdocs-material/reference/content-tabs/#anchor-links
