library angular2.src.analysis.analyzer_plugin.src;

import 'package:unittest/unittest.dart';

import 'analysis_test.dart' as analysis_test;
import 'completion_contributor_test.dart' as completion_contributor_test;

/**
 * Utility for manually running all tests.
 */
main() {
  groupSep = ' | ';
  group('Angular Server Plugin tests', () {
    analysis_test.main();
    completion_contributor_test.main();
  });
}
