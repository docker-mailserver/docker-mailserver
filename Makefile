SHELL       := /bin/bash
.SHELLFLAGS += -e -u -o pipefail

export REPOSITORY_ROOT := $(CURDIR)
export IMAGE_NAME      ?= mailserver-testing:ci
export NAME            ?= $(IMAGE_NAME)

MAKEFLAGS              += --no-print-directory
BATS_FLAGS             ?= --timing
BATS_PARALLEL_JOBS     ?= 2

.PHONY: ALWAYS_RUN

# -----------------------------------------------
# --- Generic Targets ---------------------------
# -----------------------------------------------

all: lint build backup generate-accounts tests clean

build:
	@ DOCKER_BUILDKIT=1 docker build \
		--tag $(IMAGE_NAME) \
		--build-arg VCS_VERSION=$(shell git rev-parse --short HEAD) \
		--build-arg VCS_REVISION=$(shell cat VERSION) \
		.

generate-accounts: ALWAYS_RUN
	@ cp test/config/templates/postfix-accounts.cf test/config/postfix-accounts.cf
	@ cp test/config/templates/dovecot-masters.cf test/config/dovecot-masters.cf

backup:
# if backup directory exist, clean hasn't been called, therefore
# we shouldn't overwrite it. It still contains the original content.
	-@ [[ ! -d testconfig.bak ]] && cp -rp test/config testconfig.bak || :

clean:
# remove test containers and restore test/config directory
	-@ [[ -d testconfig.bak ]] && { sudo rm -rf test/config ; mv testconfig.bak test/config ; } || :
	-@ for CONTAINER in $$(docker ps -a --filter name='^dms-test_.*|^mail_.*|^hadolint$$|^eclint$$|^shellcheck$$' | sed 1d | cut -f 1-1 -d ' '); do docker rm -f $${CONTAINER}; done
	-@ while read -r LINE; do [[ $${LINE} =~ test/.+ ]] && sudo rm -rf $${LINE}; done < .gitignore

# -----------------------------------------------
# --- Tests  ------------------------------------
# -----------------------------------------------

tests: ALWAYS_RUN
# See https://github.com/docker-mailserver/docker-mailserver/pull/2857#issuecomment-1312724303
# on why `generate-accounts` is run before each set (TODO/FIXME)
	@ for DIR in tests/{serial,parallel/set{1,2,3}} ; do $(MAKE) generate-accounts "$${DIR}" ; done

tests/serial: ALWAYS_RUN
	@ shopt -s globstar ; ./test/bats/bin/bats $(BATS_FLAGS) test/$@/*.bats

tests/parallel/set%: ALWAYS_RUN
	@ shopt -s globstar ; ./test/bats/bin/bats $(BATS_FLAGS) \
		--no-parallelize-within-files --jobs $(BATS_PARALLEL_JOBS) test/$@/**/*.bats

test/%: ALWAYS_RUN
	@ shopt -s globstar nullglob ; ./test/bats/bin/bats $(BATS_FLAGS) test/tests/**/{$*,}.bats

# -----------------------------------------------
# --- Lints -------------------------------------
# -----------------------------------------------

lint: eclint hadolint shellcheck

hadolint:
	@ ./test/linting/lint.sh hadolint

shellcheck:
	@ ./test/linting/lint.sh shellcheck

eclint:
	@ ./test/linting/lint.sh eclint
