# block until at least <barrier-size> processes of this barrier group entered the barrier
# once this happened, all latecomers will go through immediately!
# WARNING: a barrier group consists of all processes with the same barrier name *and* size!
single-use-barrier() { # <barrier-name> <barrier-size> [<timeout-in-seconds> [<sleep-cycle-time>]]
    local barrier_name="$1"
    local barrier_size="$2"
    local timeout_in_seconds="${3:-0}"
    local sleep_cycle_time="${3:-1}"
    # use name and size to distinguish between invocations
    # this will block inconsistent sizes on the same name!
    local BARRIER_SUFFIX=${barrier_name//\//_}-$barrier_size
    local BARRIER_FILE="$BATS_RUN_TMPDIR/barrier-$BARRIER_SUFFIX"
    # mark our entry for all others
    echo "in-$$" >> "$BARRIER_FILE"
    local start="$SECONDS"
    # wait for others to enter
    while [[ $(wc -l <"$BARRIER_FILE" ) -lt $barrier_size ]]; do
        if [[ $timeout_in_seconds -ne 0 && $(( SECONDS - start )) -gt $timeout_in_seconds ]]; then
            mv "$BARRIER_FILE" "$BARRIER_FILE-timeout"
            printf "ERROR: single-use-barrier %s timed out\n" "$BARRIER_SUFFIX" >&2
            return 1
        fi
        sleep "$sleep_cycle_time"
    done
    # mark our exit
    echo "out-$$" >> "$BARRIER_FILE"
}