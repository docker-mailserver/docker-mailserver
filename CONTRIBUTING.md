# Contributing

`docker-mailserver` is OpenSource. That means that you can contribute on enhancements, bug fixing or improving the documentation in the Wiki.

## Issues & PRs

### Open an issue

When opening an issue, please provide details use case to let the community reproduce your problem.
Please start the mail server with env `DMS_DEBUG=1` and paste the output into the issue.

### Pull Requests

#### Project architecture

``` TXT
├── config                    # User: personal configurations
├── target                    # Developer: default server configuration, used when building the image
└── test                      # Developer: integration tests to check that everything keeps working
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
- [Commit](https://help.github.com/articles/closing-issues-via-commit-messages/), push and make a pull-request
- Pull-request is automatically tested on Travis
- When tests are green, a review may be done
- When changed are validated, your branch is merged into `master`
- `master` is automatically tested on Travis
- Docker builds a new `latest` image

## Coding Style

### Bash and Shell

When refactoring, writing or altering Script, that is Shell and Bash scripts, in any way, adhere to these rules:

1. **Adjust your style of coding to the style that is already present**! Even if you do not like it, this is due to consistency. Look up the GNU coding style guide. There was a lot of work involved in making these scripts consistent.
2. **Use `shellcheck` to check your scripts**! Your contributions are checked by TravisCI with shellcheck.
3. There is a **`.editorconfig`** file. Make your IDE use it or adhere to it manually!
4. It's okay to use `/bin/bash` instead of `/bin/sh`. You can alternatively use `/usr/bin/env bash`.
5. `setup.sh` provides a good starting point to look for.
6. When appropriate, use the `set` builtin. We recommend `set -euEo pipefail` (very strong) or `set -uE` (weaker).

#### Styling rules

##### initial description

When writing a script, provide the version and the script's task like so:

``` BASH
#!/usr/bin/env bash

# version  0.1.0
#
# <TASK DESCRIPTION> -> cut this off
# to make it not longer than approx.
# 60 cols.
```

We use [semantic versioning](https://semver.org/) - so do you.

##### if-else-statements

``` BASH
if <CONDITION1>
then
  <CODE TO RUN>
elif <CONDITION2>
  <CODE TO TUN>
else
  <CODE TO RUN>
fi

# when using braces, use double braces!
if [[ <CONDITION1> ]] && [[ <CONDITION2> ]]
then
  <CODE TO RUN>
fi

# remember you do not need "" when using [[ ]]
if [[ -f $FILE ]] # is fine
then
  <CODE TO RUN>
fi

# equality checks with numbers - use -eq/-ne/-lt/-ge, not != or ==
if [[ $VAR -ne <NUMBER> ]] && [[ $SOME_VAR -eq 6 ]] || [[ $SOME_VAR -lt 42 ]]
then
  <CODE TO RUN>
elif [[ $SOME_VAR -ge 242 ]]
then
  <CODE TO RUN>
fi
```

##### variables

Variables are always uppercase.

``` BASH
# good
local VAR="good"

# bad
var="bad"
```

##### braces

We always use braces.

``` BASH
${VAR}
```

If you forgot this and want to change it later, you can use [this link](https://regex101.com/r/ikzJpF/4), which points to <https://regex101.com>. The used regex is `\$([^{("\\'\/])([a-zA-Z0-9_]*)([^}\/ \t'"\n.\]:]*)`, where you should in practice be able to replace all variable occurrences without braces with occurrences with braces.

##### loops

Like `if-else`, loops look like this

``` BASH
for / while <LOOP CONDITION>
do
  <CODE TO RUN>
done
```

##### functions

It's always nice to see the use of functions. Not only as it's more C-style, but it also provides a clear structure. If scripts are small, this is unnecessary, but if they become larger, please consider using functions. When doing so, provide `function _main()`. When using functions, they are **always** at the top of the script!

``` BASH
function _<name_underscored_and_lowercase>()
{
  <CODE TO RUN>

  # variables that can be local should be local
  local _<LOCAL_VARIABLE_NAME>
}
```

##### error tracing

A construct to trace error in your scripts looks like this:

``` BASH
set -euxEo pipefail
trap '_report_err $_ $LINENO $?' ERR

function _report_err()
{
  echo "ERROR occurred :: source (hint) $1 ; line $2 ; exit code $3 ;;" >&2
  
  <CODE TO RUN AFTERWARDS>
}
```

Please use it like this (copy-paste) to make errors streamlined. Remember: Remove `set -x` in the end. This of debugging purposes only.

##### comments and descriptiveness

Comments should be kept minimal and only describe non-obvious matters, i.e. not what the code does. Comments should start lowercase as most of them are not sentences. Make the code **self-descriptive** by using meaningful names! Make comments not longer than approximately 60 columns, then wrap the line.

A negative example:

``` BASH
# adds one to the first argument
# and print it to stdout
function _add_one()
{
  # save the first variable
  local FIRST=$1

  # add one here
  local RESULT=$(( _FIRST + 1 ))

  # print it to stdout
  echo "$_RESULT"
}
```

A positive example:

``` BASH
# writes result to stdout
function _add_one()
{
  echo $(( $1 + 1 ))
}
