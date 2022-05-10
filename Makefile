SHELL = /bin/bash

NAME   ?= mailserver-testing:ci
VCS_REF = $(shell git rev-parse --short HEAD)
VCS_VER = $(shell git describe --tags --contains --always)

# -----------------------------------------------
# --- Generic Build Targets ---------------------
# -----------------------------------------------

all: lint build backup generate-accounts tests clean

build:
	docker build -t $(NAME) . --build-arg VCS_VER=$(VCS_VER) --build-arg VCS_REF=$(VCS_REF)

backup:
# if backup directory exist, clean hasn't been called, therefore
# we shouldn't overwrite it. It still contains the original content.
	-@ [[ ! -d testconfig.bak ]] && cp -rp test/config testconfig.bak || :

clean:
# remove test containers and restore test/config directory
	-@ [[ -d testconfig.bak ]] && { sudo rm -rf test/config ; mv testconfig.bak test/config ; } || :
	-@ for container in $$(docker ps -a --filter name='^/mail$$|^ldap_for_mail$$|^mail_override_hostname$$|^mail_non_subdomain_hostname$$|^open-dkim$$|^hadolint$$|^eclint$$|^shellcheck$$|mail_changedetector.*' | sed 1d | cut -f 1-1 -d ' '); do docker rm -f $$container; done
	-@ sudo rm -rf test/onedir test/alias test/quota test/relay test/config/dovecot-lmtp/userdb test/config/key* test/config/opendkim/keys/domain.tld/ test/config/opendkim/keys/example.com/ test/config/opendkim/keys/localdomain2.com/ test/config/postfix-aliases.cf test/config/postfix-receive-access.cf test/config/postfix-receive-access.cfe test/config/dovecot-quotas.cf test/config/postfix-send-access.cf test/config/postfix-send-access.cfe test/config/relay-hosts/chksum test/config/relay-hosts/postfix-aliases.cf test/config/dhparams.pem test/config/dovecot-lmtp/dh.pem test/config/relay-hosts/dovecot-quotas.cf test/config/user-patches.sh test/alias/config/postfix-virtual.cf test/quota/config/dovecot-quotas.cf test/quota/config/postfix-accounts.cf test/relay/config/postfix-relaymap.cf test/relay/config/postfix-sasl-password.cf test/duplicate_configs/

# -----------------------------------------------
# --- Tests -------------------------------------
# -----------------------------------------------

generate-accounts:
# Normal mail accounts
	@ docker run --rm -e MAIL_USER=user1@localhost.localdomain -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' > test/config/postfix-accounts.cf
	@ docker run --rm -e MAIL_USER=user2@otherdomain.tld -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)"' >> test/config/postfix-accounts.cf
	@ docker run --rm -e MAIL_USER=user3@localhost.localdomain -e MAIL_PASS=mypassword -t $(NAME) /bin/sh -c 'echo "$$MAIL_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MAIL_USER -p $$MAIL_PASS)|userdb_mail=mbox:~/mail:INBOX=~/inbox"' >> test/config/postfix-accounts.cf
	@ echo "# this is a test comment, please don't delete me :'(" >> test/config/postfix-accounts.cf
	@ echo "           # this is also a test comment, :O" >> test/config/postfix-accounts.cf

# Dovecot master accounts
	@ docker run --rm -e MASTER_USER=masterusername -e MASTER_PASS=masterpassword -t $(NAME) /bin/sh -c 'echo "$$MASTER_USER|$$(doveadm pw -s SHA512-CRYPT -u $$MASTER_USER -p $$MASTER_PASS)"' > test/config/dovecot-masters.cf

tests:
	@ NAME=$(NAME) ./test/bats/bin/bats --timing test/*.bats

.PHONY: ALWAYS_RUN
test/%.bats: ALWAYS_RUN
	@ ./test/bats/bin/bats $@

lint: eclint hadolint shellcheck

hadolint:
	@ ./test/linting/lint.sh hadolint

shellcheck:
	@ ./test/linting/lint.sh shellcheck

eclint:
	@ ./test/linting/lint.sh eclint
