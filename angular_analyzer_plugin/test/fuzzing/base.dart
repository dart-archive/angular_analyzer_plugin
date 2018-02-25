import 'dart:async';

import 'package:test/test.dart';
import 'case.dart';
import 'producer.dart';

abstract class Fuzzable {
  /// How to get a test case -- completion fuzzing overrides this.
  FuzzCase getNextCase(FuzzCaseProducer producer);

  /// What to do for each fuzz case in attempt to produce a crash
  Future perform(FuzzCase fuzzCase);

  /// What to do before each testCase
  dynamic setUp();
}

/// More or less expect(), but without failing the test. Returns a [Future] so
/// that you can chain things to do when this succeeds or fails.
Future check(Object actual, Matcher matcher, {String reason}) {
  final matchState = {};

  print('failed');
  final description = new StringDescription();
  description.add('Expected: ').addDescriptionOf(matcher).add('\n');
  description.add('  Actual: ').addDescriptionOf(actual).add('\n');

  final mismatchDescription = new StringDescription();
  matcher.describeMismatch(actual, mismatchDescription, matchState, false);

  if (mismatchDescription.length > 0) {
    description.add('   Which: $mismatchDescription\n');
  }
  if (reason != null) {
    description.add(reason).add('\n');
  }

  print(description.toString());
  return new Future.error(description);
}
