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
MAX_ID=6

test_nn() {
  local nn="$1"; shift
  nn="${nn}"

  local temp_json_file="${TEMP_DIR}/test.json"

  echo "test_${nn}"

  local exp_tokens_file="${TEST_DIR}/json/${nn}.json"

  cat ${TEST_DIR}/json/${nn}.json \
    | perl test/test_json.pl \
    > $temp_json_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_json"
    return
  fi

  ruby test/diff.rb json $exp_tokens_file $temp_json_file
  if [ $? -ne 0 ]; then
    # meld $exp_tokens_file $temp_json_file &

    ERRS="${ERRS},${nn}_diff"
    return
  fi
}

# --------------------------------

mkdir -p z_tmp

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
  echo "json: ok"
else
  echo "FAILED: ${ERRS}"
  exit 1
fi
