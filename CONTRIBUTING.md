# Contributing

`docker-mailserver` is OpenSource. That means that you can contribute on enhancements, bug fixing or improving the documentation in the Wiki.

1. [Issues & PRs](#issues--prs)
   1. [Opening an Issue](#opening-an-issue)
   2. [Pull Request](#pull-requests)
2. [Coding Style](#coding-style)
   1. [Bash and Shell](#bash-and-shell)
   2. [YAML](#yaml)

## Issues & PRs

### Opening an Issue

When opening an issue, please provide details use case to let the community reproduce your problem. Please start the mail server with env `DMS_DEBUG=1` and paste the output into the issue. **Use the issue templates** to provide the necessary information. Issues which do not use these templates are not worked on and closed.

### Pull Requests

#### Submit a Pull-Request

You want to add a feature? Feel free to start creating an issue explaining what you want to do and how you're thinking doing it. Other users may have the same need and collaboration may lead to better results.

The development workflow is the following:

- Fork the project and clone your fork
- Create a branch using `git checkout -b branch_name` (you can use `issue-xxx` if fixing an existing issue)
- Run `git submodule init` and `git submodule update` to get the BATS submodules
- Code :-)
- Add integration tests in `test/tests.bats`
- Use `make clean all` to build image locally and run tests
  Note that tests work on Linux only; they hang on Mac and Windows.
- Document your improvements in `README.md` or Wiki depending on content
- [Commit][commit], if possible with [signing your commit with a GPG key][gpg], push and make a pull-request
- Pull-request is automatically tested on Travis
- When tests are green, a review may be done
- When changed are validated, your branch is merged into `master`
- `master` is automatically tested on Travis
- Docker builds a new `latest` image

## Coding Style

### Bash and Shell

When refactoring, writing or altering scripts, that is Shell and Bash scripts, in any way, adhere to these rules:

1. **Adjust your style of coding to the style that is already present**! Even if you do not like it, this is due to consistency. There was a lot of work involved in making all scripts consistent.
2. **Use `shellcheck` to check your scripts**! Your contributions are checked by TravisCI too, so you will need to do this. You can **lint your work with `make lint`** to check against all targets.
3. **Use the provided `.editorconfig`** file.
4. Use `/bin/bash` or `/usr/bin/env bash` instead of `/bin/sh`. Adjust the style accordingly.
5. `setup.sh` provides a good starting point to look for.
6. When appropriate, use the `set` builtin. We recommend `set -euEo pipefail` or `set -uE`.

#### Styling rules

##### If-Else-Statements

``` BASH
# when using braces, use double braces
# remember you do not need "" when using [[ ]]
if [[ <CONDITION1> ]] && [[ -f ${FILE} ]]
then
  <CODE TO RUN>
# when running commands, you don't need braces
elif <COMMAND TO RUN>
  <CODE TO TUN>
else
  <CODE TO TUN>
fi

# equality checks with numbers are done
# with -eq/-ne/-lt/-ge, not != or ==
if [[ ${VAR} -ne 42 ]] || [[ ${SOME_VAR} -eq 6 ]]
then
  <CODE TO RUN>
fi
```

##### Variables & Braces

Variables are always uppercase. We always use braces.

If you forgot this and want to change it later, you can use [this link][regex]. The used regex is `\$([^{("\\'\/])([a-zA-Z0-9_]*)([^}\/ \t'"\n.\]:(=\\-]*)`, where you should in practice be able to replace all variable occurrences without braces with occurrences with braces.

``` BASH
# good
local VAR="good"
local NEW="${VAR}"

# bad -> TravisCI will fail
var="bad"
new=$var
```

##### Loops

Like `if-else`, loops look like this

``` BASH
for / while <LOOP CONDITION>
do
  <CODE TO RUN>
done
```

##### Functions

It's always nice to see the use of functions as it also provides a clear structure. If scripts are small, this is unnecessary, but if they become larger, please consider using functions. When doing so, provide `function _main`.

``` BASH
function _<name_underscored_and_lowercase>
{
  <CODE TO RUN>

  # variables that can be local should be local
  local <LOCAL_VARIABLE_NAME>
}
```

##### Error Tracing

A construct to trace error in your scripts looks like this. Remember: Remove `set -x` in the end. This is for debugging purposes only.

``` BASH
set -xeuEo pipefail
trap '__log_err ${FUNCNAME[0]:-"?"} ${_:-"?"} ${LINENO:-"?"} ${?:-"?"}' ERR

SCRIPT='NAME OF THIS SCRIPT'

function __log_err
{
  printf "\n––– \e[1m\e[31mUNCHECKED ERROR\e[0m\n%s\n%s\n%s\n%s\n\n" \
    "  – script    = ${SCRIPT:-'unknown'}" \
    "  – function  = ${1} / ${2}" \
    "  – line      = ${3}" \
    "  – exit code = ${4}" 1>&2

  <CODE TO RUN AFTERWARDS>
}
```

##### Comments, Descriptiveness & An Example

Comments should only describe non-obvious matters. Comments should start lowercase when they aren't sentences. Make the code **self-descriptive** by using meaningful names! Make comments not longer than approximately 80 columns, then wrap the line.

A positive example, which is taken from `start-mailserver.sh`, would be

``` BASH
function _setup_postfix_aliases
{
  _notify 'task' 'Setting up Postfix Aliases'

  : >/etc/postfix/virtual
  : >/etc/postfix/regexp

  if [[ -f /tmp/docker-mailserver/postfix-virtual.cf ]]
  then
    # fixing old virtual user file
    if grep -q ",$" /tmp/docker-mailserver/postfix-virtual.cf
    then
      sed -i -e "s/, /,/g" -e "s/,$//g" /tmp/docker-mailserver/postfix-virtual.cf
    fi

    cp -f /tmp/docker-mailserver/postfix-virtual.cf /etc/postfix/virtual

    # the `to` is important, don't delete it
    # shellcheck disable=SC2034
    while read -r FROM TO
    do
      # Setting variables for better readability
      UNAME=$(echo "${FROM}" | cut -d @ -f1)
      DOMAIN=$(echo "${FROM}" | cut -d @ -f2)

      # if they are equal it means the line looks like: "user1     other@domain.tld"
      [[ "${UNAME}" != "${DOMAIN}" ]] && echo "${DOMAIN}" >> /tmp/vhost.tmp
    done < <(grep -v "^\s*$\|^\s*\#" /tmp/docker-mailserver/postfix-virtual.cf || true)
  else
    _notify 'inf' "Warning 'config/postfix-virtual.cf' is not provided. No mail alias/forward created."
  fi

  ...
}
```

### YAML

When formatting YAML files, use [Prettier][prettier], an opinionated formatter. There are many plugins for IDEs around.

[//]: # (Links)

[commit]: https://help.github.com/articles/closing-issues-via-commit-messages/
[gpg]: https://docs.github.com/en/github/authenticating-to-github/generating-a-new-gpg-key
[semver]: https://semver.org/
[regex]: https://regex101.com/r/ikzJpF/7
[prettier]: https://prettier.io
