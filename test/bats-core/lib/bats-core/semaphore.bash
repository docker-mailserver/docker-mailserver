#!/usr/bin/env bash

# $1 - output directory for stdout/stderr
# $@ - command to run
# run the given command in a semaphore
# block when there is no free slot for the semaphore
# when there is a free slot, run the command in background
# gather the output of the command in files in the given directory
bats_semaphore_run() {
    local output_dir=$1
    shift
    local semaphore_slot
    semaphore_slot=$(bats_semaphore_acquire_slot)
    bats_semaphore_release_wrapper "$output_dir" "$semaphore_slot" "$@" &
    printf "%d\n" "$!"
}

export BATS_SEMAPHORE_DIR="$BATS_RUN_TMPDIR/semaphores"

# $1 - output directory for stdout/stderr
# $@ - command to run
# this wraps the actual function call to install some traps on exiting
bats_semaphore_release_wrapper() {
    local output_dir="$1"
    local semaphore_name="$2"
    shift 2 # all other parameters will be use for the command to execute

    # shellcheck disable=SC2064 # we want to expand the semaphore_name right now!
    trap "status=$?; bats_semaphore_release_slot '$semaphore_name'; exit $status" EXIT

    mkdir -p "$output_dir"
    "$@" 2>"$output_dir/stderr" >"$output_dir/stdout"
    local status=$?

    # bash bug: the exit trap is not called for the background process
    bats_semaphore_release_slot "$semaphore_name"
    trap - EXIT # avoid calling release twice
    return $status
}

bats_semaphore_acquire_while_locked() {
    if [[ $(bats_semaphore_get_free_slot_count) -gt 0 ]]; then
        local slot=0
        while [[ -e "$BATS_SEMAPHORE_DIR/slot-$slot" ]]; do
            (( ++slot ))
        done
        if [[ $slot -lt $BATS_SEMAPHORE_NUMBER_OF_SLOTS ]]; then
            touch "$BATS_SEMAPHORE_DIR/slot-$slot" && printf "%d\n" "$slot" && return 0
        fi
    fi
    return 1
}

export -f bats_semaphore_acquire_while_locked

if command -v flock >/dev/null; then
    bats_run_under_lock() {
        flock "$BATS_SEMAPHORE_DIR" "$@"
    }
elif command -v shlock >/dev/null; then
    bats_run_under_lock() {
        local lockfile="$BATS_SEMAPHORE_DIR/shlock.lock"
        while ! shlock -p $$ -f "$lockfile"; do
            sleep 1
        done
        # we got the lock now, execute the command
        "$@"
        # free the lock
        rm -f "$lockfile"
    }
fi

# block until a semaphore slot becomes free
# prints the number of the slot that it received
bats_semaphore_acquire_slot() {
    mkdir -p "$BATS_SEMAPHORE_DIR"
    # wait for a slot to become free
    # TODO: avoid busy waiting by using signals -> this opens op prioritizing possibilities as well
    while true; do
        # don't lock for reading, we are fine with spuriously getting no free slot
        if [[ $(bats_semaphore_get_free_slot_count) -gt 0 ]]; then
            bats_run_under_lock bash -c bats_semaphore_acquire_while_locked && break
        fi
        sleep 1
    done
}

bats_semaphore_release_slot() {
    # we don't need to lock this, since only our process owns this file
    # and freeing a semaphore cannot lead to conflicts with others
    rm "$BATS_SEMAPHORE_DIR/slot-$1" # this will fail if we had not aqcuired a semaphore!
}

bats_semaphore_get_free_slot_count() {
    # find might error out without returning something useful when a file is deleted,
    # while the directory is traversed ->  only continue when there was no error
    until used_slots=$(find "$BATS_SEMAPHORE_DIR" -name 'slot-*' 2>/dev/null | wc -l); do :; done
    echo $(( BATS_SEMAPHORE_NUMBER_OF_SLOTS - used_slots ))
}

export -f bats_semaphore_get_free_slot_count