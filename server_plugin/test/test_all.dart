library angular2.src.analysis.analyzer_plugin.src;

import 'package:unittest/unittest.dart';

import 'analysis_test.dart' as analysis_test;

/**
 * Utility for manually running all tests.
 */
main() {
  groupSep = ' | ';
  group('Angular Server Plugin tests', () {
    analysis_test.main();
  });
}
