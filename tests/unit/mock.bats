# -*- mode: sh -*-

source "$PROJECT_ROOT"/mock.sh

setup() {
    export TEST_TMPDIR="$(mktemp -d)"
    cd "$TEST_TMPDIR"
    mock.set-dir "$PWD"
}

teardown() {
    rm -rf "$TEST_TEMPDIR"
}

# @test "envdump" {
#     set | grep -P '^BATS'
#     false
# }

@test "bats: can create functions from within tests" {
    abc() { echo hi; }
    run abc
    [[ $output == hi ]]
}

@test "bats: can't create aliases from within tests" {
    alias abc="echo 123"
    eval "alias abc=echo"
    ! type abc
}

@test "vcr() works with commands" {
    vcr date
    run date +%s
    [[ $status -eq 0 ]]
    [[ $output =~ [1-9]+ ]]
    local firstpass="$output"
    for i in {1..11}; do
        sleep 0.1
        run date +%s
        [[ $output == $firstpass ]]
    done
}

@test "vcr() works with builtins" {
    JAW1=123
    vcr set
    local output1="$(set | grep JAW)"
    echo $output1
    JAW1=321
    JAW2=321
    local output2="$(set | grep JAW)"
    echo $output2
    [[ $output1 == $output2 ]]
    mock.unmock set
    local output2="$(set | grep JAW)"
    echo $output2
    [[ $output1 != $output2 ]]
}

@test "mock() can mock non-existant commands" {
    mock doesnotexist
    type doesnotexist
}

@test "mock() can mock output" {
    mock --out "{}" mycommand
    mycommand 1>actual.out 2>actual.err
    [[ $? -eq 0 ]]
    [[ $(cat actual.out) == "{}" ]]
    [[ -z $(cat actual.err) ]]
}

@test "mock() can mock exit code" {
    mock --status 122 mycommand
    run mycommand
    [[ $status -eq 122 ]]
    [[ -z $output ]]
}

@test "mock() can mock stderr(even with success return)" {
    mock -o "STDOUT" -e "STDERR" -s 0 mycommand
    mycommand 1>actual.out 2>actual.err
    [[ $? -eq 0 ]]
    [[ $(cat actual.out) == STDOUT ]]
    [[ $(cat actual.err) == STDERR ]]
}

@test "mock() can mock using files" {
    local out='{"name":"Jo"}'
    echo "$out" > data.out
    local err='WARN: insecure connection'
    echo "$err" > data.err
    mock -o data.out -e data.err mycommand
    mycommand 1>actual.out 2>actual.err
    [[ $? -eq 0 ]]
    diff data.out actual.out
    diff data.err actual.err
}

@test "mock.unmock() restores non-existant commands" {
    ! type mycommand
    mock mycommand
    type mycommand
    mock.unmock mycommand
    ! type mycommand
}

@test "mock.unmock() restores functions" {
    function myfunc() { echo ORIGINAL; }
    run myfunc
    [[ $status -eq 0 ]]
    [[ $output == "ORIGINAL" ]]
    mock -o TESTOUT myfunc
    echo "[${__MOCK_BACKUPS[@]}]"
    run myfunc
    [[ $status -eq 0 ]]
    [[ $output == "TESTOUT" ]]
    mock.unmock myfunc
    run myfunc
    echo $output
    [[ $status -eq 0 ]]
    [[ $output == "ORIGINAL" ]]
}

@test "mock.exists()" {
    ! mock.exists funkyfunc
    mock -o TEST funkyfunc
    mock.exists funkyfunc
}

@test "mock.record()" {
    run mock.record date +%s
    [[ $status -eq 0 ]]
    local firstpass="$output"
    for i in {1..11}; do
        sleep 0.1
        run mock.play date +%s
        echo 1st: $firstpass
        echo out: $output
        [[ $status -eq 0 ]]
        [[ $output == $firstpass ]]
    done
}

@test "mock.backup-command() does nothing on non-existant command" {
    mock.backup-command alkjasdflkj
}

@test "mock.backup-command/restore-command()" {
    ! type testfun
    testfun() { echo TESTVALUE; }
    testfun | grep -P ^TESTVALUE
    type testfun
    mock.backup-command testfun
    ! type testfun
    mock.restore-command testfun
    testfun | grep -P ^TESTVALUE
}

@test "mock.unique-filename() generates consistent filenames" {
    run mock.unique-filename aws s3 ls
    [[ $status -eq 0 ]]
    local previous="$output"
    run mock.unique-filename aws s3 ls
    [[ $status -eq 0 ]]
    [[ $output == $previous ]]
}

@test "mock.unique-filename() produces valid filenames" {
    run mock.unique-filename aws s3 ls
    [[ $output =~ [A-Za-z0-9]+ ]]
}
