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

@test "unmock()" {
    ! type mycommand
    mock mycommand
    type mycommand
    unmock mycommand
    ! type mycommand
}

@test "unmock() restores functions" {
    function myfunc() { echo ORIGINAL; }
    mock -o TESTOUT myfunc
    echo "${__MOCK_BACKUPS[@]}"
    run myfunc
    [[ $status -eq 0 ]]
    [[ $output == "TESTOUT" ]]
    unmock myfunc
    run myfunc
    echo $output
    [[ $status -eq 0 ]]
    [[ $output == "ORIGINAL" ]]
}
# for f in *; do
#     echo
#     echo [$f]
#     cat -n $f
# done
# echo
# echo ---

@test "backup/restore-command()" {
    ! type testfun
    testfun() { echo TESTVALUE; }
    testfun | grep -P ^TESTVALUE
    type testfun
    mock.backup-command testfun
    ! type testfun
    mock.restore-command testfun
    testfun | grep -P ^TESTVALUE
}

@test "unique-filename() generates consistent filenames" {
    run mock.unique-filename aws s3 ls
    [[ $status -eq 0 ]]
    local previous="$output"
    run mock.unique-filename aws s3 ls
    [[ $status -eq 0 ]]
    [[ $output == $previous ]]
}

@test "unique-filename() produces valid filenames" {
    run mock.unique-filename aws s3 ls
    [[ $output =~ [A-Za-z0-9]+ ]]
}
