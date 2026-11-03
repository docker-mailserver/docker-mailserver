# Security Policy

## Supported Versions

Due to the way DMS is released, the most recent patches and the most current software is published on the `:edge` tag of the container image. Hence, security updates will land on this "rolling release tag". Older tags need manual updating, as we do not usually release an updated image for an existing tag; this will only be done in case of _severe_ vulnerabilities.

| Image Tags  | Latest Packages & Patches |
|-------------|:-------------------------:|
| `:edge`     | :white_check_mark:        |
| not `:edge` | :x:                       |

## Reporting a Vulnerability

When reporting a vulnerability, you can use GitHub's "Private Vulnerability Reporting". Just navigate to the [Open an Issue](https://github.com/docker-mailserver/docker-mailserver/issues/new/choose) page and choose "Report a security vulnerability". This way, maintainers will privately notified first. Afterwards, in a best-case scenario, if the vulnerability is fixed, the report will be made public.
