#!/bin/bash

# Fast fail the script on failures.
set -e

# Go to the respective package directory and resolve pub dependencies.
cd $PACKAGE
pub get

# Analyze the test first
dartanalyzer lib test

# Run the actual tests
dart test/test_all.dart

