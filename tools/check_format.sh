#!/bin/bash

# Fast fail the script on failures.
set -e

# Check whether we need to format any files.
DARTFMT_OUT=$(dartfmt -n "$PACKAGE")
if [[ ! -z "$DARTFMT_OUT" ]]; then
  printf "$PACKAGE has unformatted Dart files: \n$DARTFMT_OUT\n"
  printf "Run 'dartfmt -w $PACKAGE'"
  exit 1
fi
