# -*- mode: sh -*-

__MOCKS_DIR=${TEST_MOCKS_DIR:-./tests/mocks}

mock.error() {
    echo "[ERROR] $*" >&2
}
mock.warn() {
    echo "[WARN] $*" >&2
}

mock.set-dir() {
    __MOCKS_DIR="$1"
}

mock.unique-filename() {
    echo -n "$__MOCKS_DIR"/
    # make it unique per test when running in bats environment
    if [[ -n $BATS_TEST_NAME ]]
    then echo -n "${BATS_TEST_NAME}-"
    fi
    md5sum <<<"$@" | awk '{print $1}'
}

declare -A __MOCK_BACKUPS
mock.backup-command() {
    case "$(type -t "$1")" in
        alias)    __MOCK_BACKUPS[$1]="$(alias "$1")"
                  unalias "$1";;
        function) __MOCK_BACKUPS[$1]="$(declare -f "$1")"
                  unset -f "$1";;
        *) true;;
    esac
}

mock.restore-command() {
    eval "${__MOCK_BACKUPS[$1]}"
}

mock() {
    local stderr stdout status=0 cmd
    local fn
    while true; do
        case "$1" in
            -o|--out) shift; stdout="$1"; shift;;
            -s|--status) shift; status="$1"; shift;;
            -e|--err) shift; stderr="$1"; shift;;
            --) shift; break;;
            *)  break;;
        esac
    done
    fn="$(mock.unique-filename "$*")"
    if   [[ -f "$stderr" ]]
    then cp "$stderr" "$fn.err"
    else echo -n "$stderr" >"$fn.err"
    fi
    if   [[ -f "$stdout" ]]
    then cp "$stdout" "$fn.out"
    else echo -n "$stdout" >"$fn.out"
    fi
    echo -n "$status" >"$fn.status"
    mock.backup-command "$1"
    eval "function $1() { mock.play $1 \"\$@\"; }"
}

unmock() {
    unset -f "$1"
    mock.restore-command "$1"
}

mock.exists() {
    local fn
    fn="$(mock.unique-filename "$@")"
    # [[ -f "$fn.out" ]] \
    #     && [[ -f "$fn.err" ]] \
    #     && [[ -f "$fn.status" ]]
    if [[ -f "$fn.out" ]] && [[ -f "$fn.err" ]] && [[ -f "$fn.status" ]]
    then return 0
    fi
    if [[ ! -f "$fn.out" ]] && [[ ! -f "$fn.err" ]] && [[ ! -f "$fn.status" ]]
    then return 1
    fi

    mock.warn "Partial mock exists for [$fn] overwriting."
    return 0
}

mock.play() {
    local fn
    fn="$(mock.unique-filename "$@")"
    if   [[ -f "$fn.out" ]]
    then cat "$fn.out"
    else mock.error "no stdout."
    fi

    if   [[ -f "$fn.err" ]]
    then cat "$fn.err" >&2
    else mock.error "no stderr."
    fi
    if   [[ -f "$fn.status" ]]
    then return "$(cat "$fn.status")"
    else mock.error "no status."
    fi
}

# This only works with commands, not alias/functions/builtins
mock.record() {
    local fn ret
    fn="$(mock.unique-filename "$@")"
    command $@ 1>"$fn.out" 2>"$fn.err"
    ret=$?
    echo "$ret" >"$fn.status"
    cat "$fn.out"
    cat "$fn.err"
    return $ret
}

vcr.run() {
    if   mock.exists "$@"
    then mock.play   "$@"
    else mock.record "$@"
    fi
}

vcr() {
    mock.backup-command "$1"
    eval "function $1() { vcr.run $1 \"\$@\"; }"
}

vcr.eject() {
    unmock "$1"
}

# vcr aws
# vcr aws s3

# aws s3 ls
