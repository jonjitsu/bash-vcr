#!/user/bin/env bash

export PROJECT_ROOT=${PROJECT_ROOT:-/project}

fatal() {
    echo "ERROR: $*" >&2
    exit 124
}

install-bats() {
    cd "$PROJECT_ROOT"/bats || fatal "no bats to install."
    ./install.sh /usr/local
    if bats -v | grep Bats
    then echo
    else fatal "Failed to install Bats"
    fi
    # shellcheck disable=SC2164
    cd -
}

run() {
    install-bats
    if [[ $1 == repl ]]
    then bash
    else bats tests/unit
    fi
}

run "$@"
