library angular2.src.analysis.analyzer_plugin.src;

import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'analysis_test.dart' as analysis_test;
import 'completion_contributor_test.dart' as completion_contributor_test;

/**
 * Utility for manually running all tests.
 */
main() {
  defineReflectiveSuite(() {
    analysis_test.main();
    completion_contributor_test.main();
  }, name: 'Angular Server Plugin tests');
}
