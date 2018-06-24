#!/bin/bash

# Fast fail the script on failures.
set -e

if [[ -z "$TRAVIS_BRANCH" ]]
then
  TRAVIS_BRANCH="$(git branch)"
fi

# Go to the respective package directory
cd $PACKAGE

# Check if we should resolve pub dependencies, or use what was fetched from
# depot tools.
if [[ "$PACKAGE" != old_plugin_loader ]]
then
  if [[ -z "$(echo $TRAVIS_BRANCH | grep 'SDK_AT_HEAD')" ]]
  then
    echo Using pub for the SDK dependencies.
    echo
    echo To test against the SDK at master, include SDK_AT_HEAD in your branch
    echo name. Otherwise, we will test with pub.
  
    pub get
  else
    echo Using depot_tools for the SDK dependencies.
    echo
    echo Because your branch name includes SDK_AT_HEAD, this will test against
    echo the latest SDK source instead of using pub.
  fi
else
  echo Using depot_tools for the SDK dependencies.
  echo
  echo The old_plugin_loader relies on packages not published by pub, and so
  echo can only be tested by using depot_tools.
fi

# Analyze the test first
dartanalyzer lib test

# Run the actual tests
dart --no-preview-dart-2 --checked test/test_all.dart # in dart 1 mode
dart --preview-dart-2 test/test_all.dart # and dart 2 mode

