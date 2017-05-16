import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'plugin_test.dart' as plugin_test;

/// Utility for manually running all tests.
void main() {
  defineReflectiveSuite(() {
    plugin_test.main();
  }, name: 'Angular Plugin tests');
}
