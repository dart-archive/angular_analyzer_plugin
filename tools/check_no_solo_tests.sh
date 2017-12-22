#!/bin/bash

# Fast fail the script on failures.
set -e

# Check whether we need to format any files.
GREP_OUT=$(grep solo_test $PACKAGE/test -r)
if [[ ! -z "$GREP_OUT" ]]; then
  printf "$PACKAGE is skipping tests due to solo_test(s): \n$GREP_OUT\n"
  exit 1
fi
