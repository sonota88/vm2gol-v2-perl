#!/bin/bash

print_project_dir() {
  local real_path="$(readlink --canonicalize "$0")"
  (
    cd "$(dirname "$real_path")"
    pwd
  )
}

export PROJECT_DIR="$(print_project_dir)"
export TEST_DIR="${PROJECT_DIR}/test"
export TEMP_DIR="${PROJECT_DIR}/z_tmp"

ERRS=""
MAX_ID=26

build() {
  :
}

run_tokenizer() {
  perl tokenizer.pl
}

run_parser() {
  perl parser.pl
}

run_codegen() {
  perl codegen.pl
}

# --------------------------------

test_nn() {
  local nn="$1"; shift
  nn="${nn}"

  local temp_tokens_file="${TEMP_DIR}/test.tokens.txt"
  local temp_vgt_file="${TEMP_DIR}/test.vgt.json"
  local temp_vga_file="${TEMP_DIR}/test.vga.txt"

  echo "test_${nn}"

  local exp_vga_file="${TEST_DIR}/step/exp_${nn}.vga.txt"

  echo "  tok" >&2
  cat ${TEST_DIR}/step/${nn}.vg.txt | run_tokenizer > $temp_tokens_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_tokenize"
    return
  fi

  echo "  parse" >&2
  cat $temp_tokens_file | run_parser > $temp_vgt_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_parse"
    return
  fi

  echo "  cg" >&2
  cat $temp_vgt_file | run_codegen > $temp_vga_file
  if [ $? -ne 0 ]; then
    ERRS="${ERRS},${nn}_codegen"
    return
  fi

  ruby test/diff.rb asm $exp_vga_file $temp_vga_file
  if [ $? -ne 0 ]; then
    # meld $exp_vga_file $temp_vga_file &

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
  echo "step: ok"
else
  echo "FAILED: ${ERRS}"
  exit 1
fi
