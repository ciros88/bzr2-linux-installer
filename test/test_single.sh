#!/bin/bash
#
# NAME
#     test_single.sh - test both XDG MIME 'query filetype' & 'query default'
#     for a single MIME type against a target file or directory content
#
# SYNOPSIS #TODO update for test_query_default
#     ./test_single.sh mime_type target
#
# AUTHOR
#     Ciro Scognamiglio

set -e

hide_tests_pass=true

bold=$'\e[1m'
bold_reset=$'\e[0m'

check_requirements() {
  local requirements=(
    realpath xdg-mime
  )

  for requirement in "${requirements[@]}"; do
    if ! type "$requirement" &>/dev/null; then
      echo -e "\nplease install ${bold}$requirement${bold_reset}"
      exit 1
    fi
  done
}

test_query_filetype() {

  mime_actual=$(xdg-mime query filetype "$file")

  if [ "$mime_actual" == "$mime_expected" ]; then
    if [ "$hide_tests_pass" = false ]; then
      echo -e "[ ${bold}OK${bold_reset} ][expected: $mime_expected][actual: $mime_actual][$file]"
    fi
  else
    echo -e "[${bold}FAIL${bold_reset}][expected: $mime_expected][actual: $mime_actual][$file]"
  fi

}

check_requirements

if [ -z "$1" ]; then
  echo "MIME type arg is required"
  exit 1
fi

mime_expected="$1"
target="$2"

if [ -z "$target" ]; then
  echo "target arg is required"
  exit 1
fi

if [ ! -e "$target" ]; then
  echo "provided target does not exists"
  exit 1
fi

if [ -d "$target" ]; then
  if [ -z "$(ls -A "$target")" ]; then
    echo "provided target directory is empty"
    exit 1
  fi
  is_target_dir=true
else
  if [ ! -r "$target" ]; then
    echo "unable to read provided target file"
    exit 1
  fi
  is_target_dir=false
fi

target=$(realpath -s "$target")

if [ $is_target_dir = true ]; then
  readarray -d '' files < <(find "$target" -type f -print0)

  for file in "${files[@]}"; do
    test_query_filetype
  done

  #TODO test_query_default

else
  file=$target
  test_query_filetype
fi
