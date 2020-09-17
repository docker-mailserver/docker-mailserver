load 'test_helper/common'

@test "checking SRS: SRS_DOMAINNAME is used correctly" {
    docker run --rm -d --name mail_srs_domainname \
		-v "$(duplicate_config_for_container . mail_srs_domainname)":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e PERMIT_DOCKER=network \
		-e DMS_DEBUG=0 \
		-e ENABLE_SRS=1 \
		-e SRS_DOMAINNAME=srs.my-domain.com \
		-e DOMAINNAME=my-domain.com \
		-h unknown.domain.tld \
		-t ${NAME}

    teardown() { docker rm -f mail_srs_domainname; }

    repeat_until_success_or_timeout 15 docker exec mail_srs_domainname grep "SRS_DOMAIN=srs.my-domain.com" /etc/default/postsrsd
}

@test "checking SRS: DOMAINNAME is handled correctly" {
    docker run --rm -d --name mail_domainname \
		-v "$(duplicate_config_for_container . mail_domainname)":/tmp/docker-mailserver \
		-v "`pwd`/test/test-files":/tmp/docker-mailserver-test:ro \
		-e PERMIT_DOCKER=network \
		-e DMS_DEBUG=0 \
		-e ENABLE_SRS=1 \
		-e DOMAINNAME=my-domain.com \
		-h unknown.domain.tld \
		-t ${NAME}

    teardown() { docker rm -f mail_domainname; }

    repeat_until_success_or_timeout 15 docker exec mail_domainname grep "SRS_DOMAIN=my-domain.com" /etc/default/postsrsd
}