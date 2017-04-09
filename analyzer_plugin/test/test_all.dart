library angular2.src.analysis.analyzer_plugin.src;

import 'package:unittest/unittest.dart';

import 'resolver_test.dart' as resolver_test;
import 'selector_test.dart' as selector_test;
import 'angular_driver_test.dart' as angular_driver_test;
import 'offsetting_constant_value_visitor_test.dart'
    as offsetting_constant_value_visitor_test;

/**
 * Utility for manually running all tests.
 */
main() {
  groupSep = ' | ';
  group('Angular Analyzer Plugin tests', () {
    resolver_test.main();
    selector_test.main();
    angular_driver_test.main();
    offsetting_constant_value_visitor_test.main();
  });
}
