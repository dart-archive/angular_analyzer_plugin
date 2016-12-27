library angular2.src.analysis.analyzer_plugin.src;

import 'package:unittest/unittest.dart';

import 'angular_work_manager_test.dart' as angular_work_manager_test;
import 'resolver_test.dart' as resolver_test;
import 'selector_test.dart' as selector_test;
import 'tasks_test.dart' as tasks_test;
import 'offsetting_constant_value_visitor_test.dart'
    as offsetting_constant_value_visitor_test;

/**
 * Utility for manually running all tests.
 */
main() {
  groupSep = ' | ';
  group('Angular Analyzer Plugin tests', () {
    angular_work_manager_test.main();
    resolver_test.main();
    selector_test.main();
    tasks_test.main();
    offsetting_constant_value_visitor_test.main();
  });
}
