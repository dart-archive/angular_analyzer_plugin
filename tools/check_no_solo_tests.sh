#!/bin/bash

# Fast fail the script on failures.
set -e

# Look for solo_test in test/*, and catch the "fast fail" error when no results
GREP_OUT=$(egrep 'solo(T|_t)est' $PACKAGE/test -r || :)
if [[ ! -z "$GREP_OUT" ]]; then
  printf "$PACKAGE is skipping tests due to solo_test(s): \n$GREP_OUT\n"
  exit 1
fi
