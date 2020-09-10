# Contributing

`docker-mailserver` is OpenSource. That means that you can contribute on enhancements, bug fixing or improving the documentation in the Wiki.

1. [Issues & PRs](#issues--prs)
   1. [Open an Issue](#open-an-issue)
   2. [Pull Request](#pull-requests)
2. [Coding Style](#coding-style)
   1. [Bash and Shell](#bash-and-shell)
   2. [YAML](#yaml)

## Issues & PRs

### Open an issue

When opening an issue, please provide details use case to let the community reproduce your problem.
Please start the mail server with env `DMS_DEBUG=1` and paste the output into the issue.

### Pull Requests

#### Project architecture

``` TXT
├── config  # User: personal configurations
├── target  # Developer: default server configuration, used when building the image
└── test    # Developer: integration tests to check that everything keeps working
```

#### Submit a Pull-Request

You want to add a feature? Feel free to start creating an issue explaining what you want to do and how you're thinking doing it. Other users may have the same need and collaboration may lead to better results.

The development workflow is the following:

- Fork project and clone your fork
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

1. **Adjust your style of coding to the style that is already present**! Even if you do not like it, this is due to consistency. Look up the GNU coding style guide. There was a lot of work involved in making these scripts consistent.
2. **Use `shellcheck` to check your scripts**! Your contributions are checked by TravisCI with shellcheck. You can check your scripts like Travis with `make shellcheck`.
3. There is a **`.editorconfig`** file. Make your IDE use it or adhere to it manually!
4. It's okay to use `/bin/bash` instead of `/bin/sh`. You can alternatively use `/usr/bin/env bash`.
5. `setup.sh` provides a good starting point to look for.
6. When appropriate, use the `set` builtin. We recommend `set -euEo pipefail` (very strong) or `set -uE` (weaker).

#### Styling rules

##### Initial Description

When writing a script, provide the version and the script's task. We use [semantic versioning][semver] - so do you.

``` BASH
#!/usr/bin/env bash

# version  0.1.0
#
# <TASK DESCRIPTION> -> cut this off
# to make it not longer than approx.
# 80 cols.
```

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
if [[ $VAR -ne 42 ]] || [[ $SOME_VAR -eq 6 ]]
then
  <CODE TO RUN>
fi
```

##### Variables & Braces

Variables are always uppercase. We always use braces. If you forgot this and want to change it later, you can use [this link][regex], which points to <https://regex101.com>. The used regex is `\$([^{("\\'\/])([a-zA-Z0-9_]*)([^}\/ \t'"\n.\]:]*)`, where you should in practice be able to replace all variable occurrences without braces with occurrences with braces.

``` BASH
# good
local VAR="good"
local NEW="${VAR}"

# bad
var="bad"
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

It's always nice to see the use of functions. Not only as it's more C-style, but it also provides a clear structure. If scripts are small, this is unnecessary, but if they become larger, please consider using functions. When doing so, provide `function _main()`. When using functions, they are **always** at the top of the script!

``` BASH
function _<name_underscored_and_lowercase>()
{
  <CODE TO RUN>

  # variables that can be local should be local
  local <LOCAL_VARIABLE_NAME>
}
```

##### Error Tracing

A construct to trace error in your scripts looks like this. Please use it like this (copy-paste) to make errors streamlined. Remember: Remove `set -x` in the end. This of debugging purposes only.

``` BASH
set -euxEo pipefail
trap '_report_err $_ $LINENO $?' ERR

function _report_err()
{
  echo "ERROR occurred :: source (hint) $1 ; line $2 ; exit code $3 ;;" >&2
  
  <CODE TO RUN AFTERWARDS>
}
```

##### Comments and Descriptiveness

Comments should only describe non-obvious matters. Comments should start lowercase when they aren't sentences. Make the code **self-descriptive** by using meaningful names! Make comments not longer than approximately 80 columns, then wrap the line.

A positive example:

``` BASH
# writes result to stdout
function _add_one()
{
  echo $(( $1 + 1 ))
}
```

A negative example:

``` BASH
# adds one to the first argument and print it to stdout
function _add_one()
{
  # save the first variable
  local FIRST=$1

  # add one here
  local RESULT=$(( FIRST + 1 ))

  # print it to stdout
  echo "$_RESULT"
}
```

### YAML

When formatting YAML files, you can opt for [Prettier][prettier]. There are many plugins for IDEs around.

[//]: # (Links)

[commit]: https://help.github.com/articles/closing-issues-via-commit-messages/
[gpg]: https://docs.github.com/en/github/authenticating-to-github/generating-a-new-gpg-key
[semver]: https://semver.org/
[regex]: https://regex101.com/r/ikzJpF/5
[prettier]: https://prettier.io
