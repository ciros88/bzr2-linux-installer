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
  local mime_actual
  mime_actual=$(xdg-mime query filetype "$file")

  if [ "$mime_actual" == "$mime_expected" ]; then
    ((test_query_filetype_passed += 1))
    if [ "$hide_tests_pass" = false ]; then
      echo -e "[ ${bold}OK${bold_reset} ][expected: $mime_expected][actual: $mime_actual][$file]"
    fi
  else
    ((test_query_filetype_failed += 1))
    echo -e "[${bold}FAIL${bold_reset}][expected: $mime_expected][actual: $mime_actual][$file]"
  fi
}

test_query_default_on_query_filetype() {
  local mime_actual
  mime_type=$(xdg-mime query filetype "$file")

  local query_default_result
  query_default_result=$(xdg-mime query default "$mime_type")

  if [ "$query_default_result" = "$desktop_expected" ]; then
    if [ "$hide_tests_pass" = false ]; then
      echo -e "[ ${bold}OK${bold_reset} ][$mime_type][$query_default_result][$(basename "$file")]"
      return 0
    fi
  else
    echo -e "[${bold}FAIL${bold_reset}][$mime_type][expected: $desktop_expected]\
[actual: $query_default_result][$(basename "$file")]"
    return 1
  fi
}

check_requirements

if [ -z "$1" ]; then
  echo "MIME type arg is required"
  exit 1
fi

mime_provided="$1"
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
else
  files=("$target")
fi

echo -e "\nTesting ${bold}xdg-mime query default${bold_reset} on ${bold}xdg-mime query filetype${bold_reset} \
(file's MIME type association with bzr2 desktop entry)...\n"

test_query_default_passed=0
test_query_default_failed=0
desktop_expected="bzr2.desktop"

for file in "${files[@]}"; do
  if test_query_default_on_query_filetype 2>/dev/null; then
    ((test_query_default_passed += 1))
  else
    ((test_query_default_failed += 1))
  fi
done

echo -e "\nTest results [${bold}xdg-mime query default${bold_reset}]:"
echo -e "Run ${bold}$((test_query_default_passed + test_query_default_failed))${bold_reset}, \
Passed ${bold}$((test_query_default_passed))${bold_reset}, \
Failed ${bold}$((test_query_default_failed))${bold_reset}"
echo -e "\nTesting ${bold}xdg-mime query filetype${bold_reset} \
(MIME type effectiveness against provided target)...\n"

mime_expected=$mime_provided
test_query_filetype_passed=0
test_query_filetype_failed=0

for file in "${files[@]}"; do
  test_query_filetype
done

echo -e "\nTest results [${bold}xdg-mime query filetype${bold_reset}]:"
echo -e "Run ${bold}$((test_query_filetype_passed + test_query_filetype_failed))${bold_reset}: \
Passed ${bold}$test_query_filetype_passed${bold_reset}, Failed ${bold}$test_query_filetype_failed${bold_reset}"
