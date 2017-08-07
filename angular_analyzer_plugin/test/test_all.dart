import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'angular_driver_test.dart' as angular_driver_test;
import 'completion_contributor_test.dart' as completion_contributor_test;
import 'file_tracker_test.dart' as file_tracker_test;
import 'navigation_test.dart' as navigation_test;
import 'occurrences_test.dart' as occurrences_test;
import 'offsetting_constant_value_visitor_test.dart'
    as offsetting_constant_value_visitor_test;
import 'plugin_test.dart' as plugin_test;
import 'resolver_test.dart' as resolver_test;
import 'selector_test.dart' as selector_test;

/// Utility for manually running all tests.
void main() {
  // ignore: unnecessary_lambdas
  defineReflectiveSuite(() {
    plugin_test.main();
    resolver_test.main();
    selector_test.main();
    angular_driver_test.main();
    offsetting_constant_value_visitor_test.main();
    navigation_test.main();
    occurrences_test.main();
    completion_contributor_test.main();
    file_tracker_test.main();
  }, name: 'Angular Plugin tests');
}
