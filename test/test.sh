#!/bin/bash
#
# NAME
#     test.sh - test both XDG MIME query filetype & query default against a selected set of files and mimes
#
# SYNOPSIS
#     ./test.sh
#
# AUTHOR
#     Ciro Scognamiglio

showPasses=true
dirParent="samples"

testQueryFiletype() {
  for file; do
    queryFiletypeResult=$(xdg-mime query filetype "$file")

    mimeToMatch=$(dirname "$file")
    mimeToMatch=${mimeToMatch#./}
    mimeToMatch=${mimeToMatch/-/\/}

    if [ "$queryFiletypeResult" = "$mimeToMatch" ]; then
      if [ "$showPasses" = true ]; then
        echo "[ OK ][xdg-mime query filetype][$(basename "$file")]"
      fi
    else
      echo "[FAIL][xdg-mime query filetype][$(basename "$file")][actual: $queryFiletypeResult][expected: $mimeToMatch]"
    fi

  done
}

testQueryDefault() {
  for dir in *; do
    mimeToMatch=${dir/-/\/}
    queryDefaultResult=$(xdg-mime query default "$mimeToMatch")

    if [ "$queryDefaultResult" = "bzr2.desktop" ]; then
      if [ "$showPasses" = true ]; then
        echo "[ OK ][xdg-mime query default][$mimeToMatch]"
      fi
    else
      echo "[FAIL][xdg-mime query default][$mimeToMatch][actual: $queryFiletypeResult][expected: $mimeToMatch]"
    fi

  done
}

export -f testQueryFiletype
export showPasses=$showPasses
cd $dirParent &&
  find . -type f -exec bash -c 'testQueryFiletype "$0"' {} \; &&
  testQueryDefault
