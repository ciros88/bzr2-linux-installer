#!/bin/bash

#test specific MIME type against a directory content

#TODO merge with test.sh
#TODO adapt hide_tests_pass to test.sh
#TODO add scanning in progress animation with counter/all format

set -e

hide_tests_pass=true

bold=$'\e[1m'
bold_reset=$'\e[0m'

check_requirements() {
  local requirements=(
    realpath xdg-mime date
  )

  for requirement in "${requirements[@]}"; do
    if ! type "$requirement" &>/dev/null; then
      echo -e "\nplease install ${bold}$requirement${bold_reset}"
      exit 1
    fi
  done
}

check_requirements

if [ -z "$1" ]; then
  echo "MIME type argument is missing"
  exit 1
fi

mime_expected="$1"
directory="$2"

if [ -z "$directory" ]; then
  echo "directory argument is missing"
  exit 1
fi

if [ ! -d "$directory" ]; then
  echo "provided directory does not exists"
  exit 1
fi

if [ -z "$(ls -A "$directory")" ]; then
  echo "provided directory is empty"
  exit 1
fi

directory=$(realpath -s "$directory")
now=$(date "+%Y-%m-%d_%H:%M:%S.%3N")
results_filename="results_${mime_expected////-}_$now.txt"

for file in "$directory"/*; do
  mime_actual=$(xdg-mime query filetype "$file")

  if [ "$hide_tests_pass" = true ]; then
    if [ "$mime_actual" != "$mime_expected" ]; then
      echo "$file: $mime_actual" >>"$results_filename"
    fi
  else
    echo "$file: $mime_actual" >>"$results_filename"
  fi

done
