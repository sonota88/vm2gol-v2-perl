#!/bin/bash

print_this_dir() {
  local real_path="$(readlink --canonicalize "$0")"
  (
    cd "$(dirname "$real_path")"
    pwd
  )
}

ERRS=""

test_all() {
  echo "==== json ===="
  test/test_json.sh
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_json"
    return
  fi

  echo "==== lex ===="
  test/test_lex.sh
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_lex"
    return
  fi

  echo "==== parse ===="
  test/test_parse.sh
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_parser"
    return
  fi

  echo "==== compile ===="
  test/test_compile.sh
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_compile"
    return
  fi
}

# --------------------------------

test_all

echo "----"
if [ "$ERRS" = "" ]; then
  echo "all ok"
else
  echo "FAILED: ${ERRS}"
  exit 1
fi
