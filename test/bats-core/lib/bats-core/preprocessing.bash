#!/usr/bin/env bash

if [[ -z "${TMPDIR:-}" ]]; then
	export BATS_TMPDIR='/tmp'
else
	export BATS_TMPDIR="${TMPDIR%/}"
fi

BATS_TMPNAME="$BATS_RUN_TMPDIR/bats.$$"
BATS_PARENT_TMPNAME="$BATS_RUN_TMPDIR/bats.$PPID"
# shellcheck disable=SC2034
BATS_OUT="${BATS_TMPNAME}.out" # used in bats-exec-file

bats_preprocess_source() {
	# export to make it visible to bats_evaluate_preprocessed_source
	# since the latter runs in bats-exec-test's bash while this runs in bats-exec-file's
	export BATS_TEST_SOURCE="${BATS_TMPNAME}.src"
	bats-preprocess "$BATS_TEST_FILENAME" >"$BATS_TEST_SOURCE"
}

bats_evaluate_preprocessed_source() {
	if [[ -z "${BATS_TEST_SOURCE:-}" ]]; then
		BATS_TEST_SOURCE="${BATS_PARENT_TMPNAME}.src"
	fi
	# Dynamically loaded user files provided outside of Bats.
	# shellcheck disable=SC1090
	source "$BATS_TEST_SOURCE"
}
