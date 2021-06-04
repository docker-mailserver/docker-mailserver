SHELL = /bin/bash

NAME   ?= mailserver-testing:ci
VCS_REF = $(shell git rev-parse --short HEAD)
VCS_VER = $(shell git describe --tags --contains --always)

KERNEL_NAME=$(shell uname -s)
KERNEL_NAME_LOWERCASE=$(shell echo $(KERNEL_NAME) | tr '[:upper:]' '[:lower:]')
MACHINE_ARCH=$(shell uname -m)
CONTAINER_WORKDIR=/tmp/docker-mailserver
TOOLS_DIR=$(CONTAINER_WORKDIR)/tools

HADOLINT_VERSION   = 2.4.1
SHELLCHECK_VERSION = 0.7.2
ECLINT_VERSION     = 2.3.5

export CDIR = $(shell pwd)

define docker-execute
	docker run -v $(CDIR):$(CONTAINER_WORKDIR) --workdir="$(CONTAINER_WORKDIR)" --rm -t $(NAME) bash -c $(1)
endef

# –––––––––––––––––––––––––––––––––––––––––––––––
# ––– Generic Build Targets –––––––––––––––––––––
# –––––––––––––––––––––––––––––––––––––––––––––––

all: build lint backup generate-accounts tests clean

build:
	docker build -t $(NAME) . --build-arg VCS_VER=$(VCS_VER) --build-arg VCS_REF=$(VCS_REF) --build-arg BUILD_TEST=1

backup:
# if backup directories exist, clean hasn't been called, therefore
# we shouldn't overwrite it. It still contains the original content.
	-@ [[ ! -d config.bak ]] && cp -rp config config.bak || :
	-@ [[ ! -d testconfig.bak ]] && cp -rp test/config testconfig.bak || :

clean:
# remove running and stopped test containers
	-@ [[ -d config.bak ]] && { rm -rf config ; mv config.bak config ; } || :
	-@ [[ -d testconfig.bak ]] && { sudo rm -rf test/config ; mv testconfig.bak test/config ; } || :
	-@ for container in $$(docker ps -a | grep -E "mail|ldap_for_mail|mail_overri.*" | cut -f 1-1 -d ' '); do docker rm -f $container; done
	-@ sudo rm -rf test/onedir test/alias test/quota test/relay test/config/dovecot-lmtp/userdb test/config/key* test/config/opendkim/keys/domain.tld/ test/config/opendkim/keys/example.com/ test/config/opendkim/keys/localdomain2.com/ test/config/postfix-aliases.cf test/config/postfix-receive-access.cf test/config/postfix-receive-access.cfe test/config/dovecot-quotas.cf test/config/postfix-send-access.cf test/config/postfix-send-access.cfe test/config/relay-hosts/chksum test/config/relay-hosts/postfix-aliases.cf test/config/dhparams.pem test/config/dovecot-lmtp/dh.pem test/config/relay-hosts/dovecot-quotas.cf test/config/user-patches.sh test/alias/config/postfix-virtual.cf test/quota/config/dovecot-quotas.cf test/quota/config/postfix-accounts.cf test/relay/config/postfix-relaymap.cf test/relay/config/postfix-sasl-password.cf test/duplicate_configs/

# –––––––––––––––––––––––––––––––––––––––––––––––
# ––– Tests –––––––––––––––––––––––––––––––––––––
# –––––––––––––––––––––––––––––––––––––––––––––––

generate-accounts:
	@ docker run --rm -e MAIL_USER=user1@localhost.localdomain -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' > test/config/postfix-accounts.cf
	@ docker run --rm -e MAIL_USER=user2@otherdomain.tld -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' >> test/config/postfix-accounts.cf
	@ docker run --rm -e MAIL_USER=user3@localhost.localdomain -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)|userdb_mail=mbox:~/mail:INBOX=~/inbox"' >> test/config/postfix-accounts.cf
	@ echo "# this is a test comment, please don't delete me :'(" >> test/config/postfix-accounts.cf
	@ echo "           # this is also a test comment, :O" >> test/config/postfix-accounts.cf

tests:
	@ NAME=$(NAME) ./test/bats/bin/bats test/*.bats

.PHONY: ALWAYS_RUN
test/%.bats: ALWAYS_RUN
	@ ./test/bats/bin/bats $@

lint:
	$(call docker-execute,"[[ ! -e "$(TOOLS_DIR)/hadolint" ]] && make install_linters; make hadolint shellcheck eclint")

hadolint:
	@ ./test/linting/lint.sh hadolint

shellcheck:
	@ ./test/linting/lint.sh shellcheck

eclint:
	@ ./test/linting/lint.sh eclint

install_linters:
	@ mkdir -p $(CDIR)/tools
	@ curl -S -L \
		"https://github.com/hadolint/hadolint/releases/download/v$(HADOLINT_VERSION)/hadolint-$(KERNEL_NAME)-$(MACHINE_ARCH)" -o $(CDIR)/tools/hadolint
	@ curl -S -L \
		"https://github.com/koalaman/shellcheck/releases/download/v$(SHELLCHECK_VERSION)/shellcheck-v$(SHELLCHECK_VERSION).$(KERNEL_NAME_LOWERCASE).$(MACHINE_ARCH).tar.xz" | tar -JxO shellcheck-v$(SHELLCHECK_VERSION)/shellcheck > $(CDIR)/tools/shellcheck
	@ curl -S -L \
		"https://github.com/editorconfig-checker/editorconfig-checker/releases/download/$(ECLINT_VERSION)/ec-$(KERNEL_NAME_LOWERCASE)-amd64.tar.gz" | tar -zxO bin/ec-$(KERNEL_NAME_LOWERCASE)-amd64 > $(CDIR)/tools/eclint
	@ chmod u+rx $(CDIR)/tools/*
