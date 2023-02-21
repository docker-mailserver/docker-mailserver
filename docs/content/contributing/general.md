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

You will need to have Docker installed. Navigate into the `docs/` directory. Then run:

```sh
docker run --rm -it -p 8000:8000 -v "${PWD}:/docs" squidfunk/mkdocs-material
```

This serves the documentation on your local machine on port `8000`. Each change will be hot-reloaded onto the page you view, just edit, save and look at the result.

[get-docker]: https://docs.docker.com/get-docker/
[docs-bats-parallel]: https://bats-core.readthedocs.io/en/v1.8.2/usage.html#parallel-execution
