import 'package:angular_analyzer_plugin/src/options.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test/test.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AngularOptionsTest);
  });
}

@reflectiveTest
class AngularOptionsTest {
  // ignore: non_constant_identifier_names
  void test_buildEmpty() {
    final options = new AngularOptions.defaults();
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames, isEmpty);
  }

  // ignore: non_constant_identifier_names
  void test_buildExact() {
    final options = new AngularOptions(customTagNames: ['foo']);
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames, equals(['foo']));
  }

  // ignore: non_constant_identifier_names
  void test_buildYaml_defaults() {
    final options = new AngularOptions.from('''
analyzer:
  plugins:
    angular:
      enabled: true
''');
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames, isEmpty);
  }

  // ignore: non_constant_identifier_names
  void test_buildYaml_simple_tags() {
    final options = new AngularOptions.from('''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_tag_names:
        - foo
        - bar
        - baz
''');
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames, equals(['foo', 'bar', 'baz']));
  }

  // ignore: non_constant_identifier_names
  void test_buildYaml_ignoresUnrelatedPlugin() {
    final options = new AngularOptions.from('''
analyzer:
  plugins:
    craaangularrrrrk:
      enabled: true
      custom_tag_names:
        - foo
        - bar
        - baz

''');
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames, isEmpty);
  }

  // ignore: non_constant_identifier_names
  void test_buildYaml_selfLoading() {
    final options = new AngularOptions.from('''
analyzer:
  plugins:
    angular_analyzer_plugin:
      enabled: true
      custom_tag_names:
        - foo
        - bar
        - baz

''');
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames, equals(['foo', 'bar', 'baz']));
  }

  // ignore: non_constant_identifier_names
  void test_buildYaml_selfLoadingIgnoredIfNotEnabled() {
    final options = new AngularOptions.from('''
analyzer:
  plugins:
    angular:
      enabled: true

    angular_analyzer_plugin:
      enabled: false
      custom_tag_names:
        - foo
        - bar
        - baz

''');
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames, isEmpty);
  }

  // ignore: non_constant_identifier_names
  void test_buildYaml_angularIgnoredIfNotEnabled() {
    final options = new AngularOptions.from('''
analyzer:
  plugins:
    angular:
      enabled: false
      custom_tag_names:
        - foo
        - bar
        - baz

    angular_analyzer_plugin:
      enabled: true

''');
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames, isEmpty);
  }

  // ignore: non_constant_identifier_names
  void test_buildYaml_angularAndSelfLoadingMerged() {
    final options = new AngularOptions.from('''
analyzer:
  plugins:
    angular:
      enabled: true

    angular_analyzer_plugin:
      enabled: true
      custom_tag_names:
        - foo
        - bar
        - baz

''');
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames, equals(['foo', 'bar', 'baz']));
  }

  // ignore: non_constant_identifier_names
  void test_buildYaml_angularPrioritizedOverSelfLoading() {
    // TODO(mfairhurst) this should be an error/warning.
    // However, not critical.
    // For now, let's at least test this so it doesn't change willy-nilly.
    final options = new AngularOptions.from('''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_tag_names:
        - tags-from-angular
        - should-appear
        - this-is-good

    angular_analyzer_plugin:
      enabled: true
      custom_tag_names:
        - tags-from-plugin
        - should-not-appear
        - this-is-good

''');
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames,
        equals(['tags-from-angular', 'should-appear', 'this-is-good']));
  }

  // ignore: non_constant_identifier_names
  void test_buildYaml_mangledValueIgnored() {
    // TODO(mfairhurst) this should be an error/warning.
    // However, the most important thing is that we don't propagate the mangled
    // values which can cause later crashes.
    final options = new AngularOptions.from('''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_tag_names: true
''');
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames, const isInstanceOf<List>());
    expect(options.customTagNames, isEmpty);
  }

  // ignore: non_constant_identifier_names
  void test_buildYaml_nonMangledValuesPrioritizedOverMangled() {
    // TODO(mfairhurst) this should be an error/warning.
    // However, not critical.
    // For now, let's at least test this so it doesn't change willy-nilly.
    final options = new AngularOptions.from('''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_tag_names: 10

    angular_analyzer_plugin:
      enabled: true
      custom_tag_names:
        - should-appear
        - this-is-good

''');
    expect(options.customTagNames, isNotNull);
    expect(options.customTagNames, equals(['should-appear', 'this-is-good']));
  }
}
