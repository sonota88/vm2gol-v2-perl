#!/bin/bash

print_this_dir() {
  local real_path="$(readlink --canonicalize "$0")"
  (
    cd "$(dirname "$real_path")"
    pwd
  )
}

print_project_dir() {
  (
    cd "$(print_this_dir)"
    cd ..
    pwd
  )
}

export PROJECT_DIR="$(print_project_dir)"
export TEST_DIR="${PROJECT_DIR}/test"
export TEMP_DIR="${PROJECT_DIR}/z_tmp"

ERRS=""
MAX_ID=2

build() {
  :
}

run() {
  perl lexer.pl
}

test_nn() {
  local nn="$1"; shift
  nn="${nn}"

  local temp_tokens_file="${TEMP_DIR}/test.tokens.txt"

  echo "test_${nn}"

  local exp_tokens_file="${TEST_DIR}/lex/exp_${nn}.txt"

  cat ${TEST_DIR}/lex/${nn}.vg.txt \
    | run \
    > $temp_tokens_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_lex"
    return
  fi

  ruby test/diff.rb text $exp_tokens_file $temp_tokens_file
  if [ $? -ne 0 ]; then
    # meld $exp_tokens_file $temp_tokens_file &

    ERRS="${ERRS},${nn}_diff"
    return
  fi
}

# --------------------------------

mkdir -p z_tmp

build

ns=

if [ $# -eq 1 ]; then
  ns="$1"
else
  ns="$(seq 1 $MAX_ID)"
fi

for n in $ns; do
  test_nn $(printf "%02d" $n)
done

echo "----"
if [ "$ERRS" = "" ]; then
  echo "lex: ok"
else
  echo "FAILED: ${ERRS}"
  exit 1
fi
