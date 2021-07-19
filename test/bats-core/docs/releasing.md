# Releasing a new Bats version

These notes reflect the current process. There's a lot more we could do, in
terms of automation and expanding the number of platforms to which we formally
release (see #103).

## Update docs/CHANGELOG.md

Create a new entry at the top of `docs/CHANGELOG.md` that enumerates the
significant updates to the new version.

## Bumping the version number

Bump the version numbers in the following files:

- contrib/rpm/bats.spec
- libexec/bats-core/bats
- package.json

Commit these changes (including the `docs/CHANGELOG.md` changes) in a commit
with the message `Bats <VERSION>`, where `<VERSION>` is the new version number.

Create a new signed, annotated tag with:

```bash
$ git tag -a -s <VERSION>
```

Include the `docs/CHANGELOG.md` notes corresponding to the new version as the
tag annotation, except the first line should be: `Bats <VERSION> - YYYY-MM-DD`
and any Markdown headings should become plain text, e.g.:

```md
### Added
```

should become:

```md
Added:
```

## Create a GitHub release

Push the new version commit and tag to GitHub via the following:

```bash
$ git push --follow-tags
```

Then visit https://github.com/bats-core/bats-core/releases, and:

* Click **Draft a new release**.
* Select the new version tag.
* Name the release: `Bats <VERSION>`.
* Paste the same notes from the version tag annotation as the description,
  except change the first line to read: `Released: YYYY-MM-DD`.
* Click **Publish release**.

For more on `git push --follow-tags`, see:

* [git push --follow-tags in the online manual][ft-man]
* [Stack Overflow: How to push a tag to a remote repository using Git?][ft-so]

[ft-man]: https://git-scm.com/docs/git-push#git-push---follow-tags
[ft-so]: https://stackoverflow.com/a/26438076

## NPM

`npm publish`. Pretty easy!

For the paranoid, use `npm pack` and install the resulting tarball locally with
`npm install` before publishing.

## Homebrew

The basic instructions are in the [Submit a new version of an existing
formula][brew] section of the Homebrew docs.

[brew]: https://github.com/Homebrew/brew/blob/master/docs/How-To-Open-a-Homebrew-Pull-Request.md#submit-a-new-version-of-an-existing-formula

An example using v1.1.0 (notice that this uses the sha256 sum of the tarball):

```bash
$ curl -LOv https://github.com/bats-core/bats-core/archive/v1.1.0.tar.gz
$ openssl sha256 v1.1.0.tar.gz
SHA256(v1.1.0.tar.gz)=855d8b8bed466bc505e61123d12885500ef6fcdb317ace1b668087364717ea82

# Add the --dry-run flag to see the individual steps without executing.
$ brew bump-formula-pr \
  --url=https://github.com/bats-core/bats-core/archive/v1.1.0.tar.gz \
  --sha256=855d8b8bed466bc505e61123d12885500ef6fcdb317ace1b668087364717ea82
```
This resulted in https://github.com/Homebrew/homebrew-core/pull/29864, which was
automatically merged once the build passed.

## Alpine Linux

An example using v1.1.0 (notice that this uses the sha512 sum of the Zip file):

```bash
$ curl -LOv https://github.com/bats-core/bats-core/archive/v1.1.0.zip
$ openssl sha512 v1.1.0.zip
SHA512(v1.1.0.zip)=accd83cfec0025a2be40982b3f9a314c2bbf72f5c85daffa9e9419611904a8d34e376919a5d53e378382e0f3794d2bd781046d810225e2a77812474e427bed9e
```

After cloning alpinelinux/aports, I used the above information to create:
https://github.com/alpinelinux/aports/pull/4696

**Note:** Currently users must enable the `edge` branch of the `community` repo
by adding/uncommenting the corresponding entry in `/etc/apk/repositories`.

## Announce

It's worth making a brief announcement like [the v1.1.0 announcement via
Gitter][gitter]:

[gitter]: https://gitter.im/bats-core/bats-core?at=5b42c9a57b811a6d63daacb5

```
v1.1.0 is now available via Homebrew and npm:
https://github.com/bats-core/bats-core/releases/tag/v1.1.0

It'll eventually be available in Alpine via the edge branch of the community
repo once alpinelinux/aports#4696 gets merged. (Check /etc/apk/repositories to
ensure this repo is enabled.)
```
