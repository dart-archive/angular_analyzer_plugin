import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as protocol;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as protocol;
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:angular_analyzer_plugin/plugin.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

import 'mock_sdk.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PluginIntegrationTest);
    defineReflectiveTests(AnalysisOptionsUtilsTest);
  });
}

@reflectiveTest
class PluginIntegrationTest extends AnalysisOptionsUtilsBase {
  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver() {
    enableAnalyzerPluginsAngular();
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, isNotNull);
    expect(driver.byteStore, isNotNull);
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_containsDartDriver() {
    enableAnalyzerPluginsAngular();
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, isNotNull);
    expect(driver.dartDriver, isNotNull);
    expect(driver.dartDriver.analysisOptions, isNotNull);
    expect(driver.dartDriver.fsState, isNotNull);
    expect(driver.dartDriver.name, equals("/test"));
    expect(driver.dartDriver.sourceFactory, isNotNull);
    expect(driver.dartDriver.contextRoot, isNotNull);
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_defaultOptions() {
    enableAnalyzerPluginsAngular();
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, isNotNull);
    expect(driver.options, isNotNull);
    expect(driver.options.unknownTagNames, isNotNull);
    expect(driver.options.unknownTagNames, isEmpty);
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_customTagNames() {
    enableAnalyzerPluginsAngular(extraOptions: [
      'custom_tag_names:',
      '  - foo',
      '  - bar',
      '  - baz',
    ]);
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, isNotNull);
    expect(driver.options, isNotNull);
    expect(driver.options.unknownTagNames, isNotNull);
    expect(driver.options.unknownTagNames, equals(['foo', 'bar', 'baz']));
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_customTagNames_pluginSelfLoader() {
    enableAnalyzerPluginsAngularPlugin(extraOptions: [
      'custom_tag_names:',
      '  - foo',
      '  - bar',
      '  - baz',
    ]);
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, isNotNull);
    expect(driver.options, isNotNull);
    expect(driver.options.unknownTagNames, isNotNull);
    expect(driver.options.unknownTagNames, equals(['foo', 'bar', 'baz']));
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_customTagNames_onlyInDisabledSection() {
    setAnalysisYamlBothPluginSections(angularOptions: [
      'enabled: true',
    ], angularPluginOptions: [
      'enabled: false',
      'custom_tag_names:',
      '  - foo',
      '  - bar',
      '  - baz',
    ]);
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, isNotNull);
    expect(driver.options, isNotNull);
    expect(driver.options.unknownTagNames, isNotNull);
    expect(driver.options.unknownTagNames, isEmpty);
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_customTagNames_onlyInEnabledSection() {
    setAnalysisYamlBothPluginSections(angularOptions: [
      'enabled: false',
    ], angularPluginOptions: [
      'enabled: true',
      'custom_tag_names:',
      '  - foo',
      '  - bar',
      '  - baz',
    ]);
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, isNotNull);
    expect(driver.options, isNotNull);
    expect(driver.options.unknownTagNames, isNotNull);
    expect(driver.options.unknownTagNames, equals(['foo', 'bar', 'baz']));
  }
}

/// Unfortunately, package:yaml doesn't support dumping to yaml. So this is
/// what we are stuck with, for now. Put it in a base class so we can test it
class AnalysisOptionsUtilsBase {
  AngularAnalyzerPlugin plugin;
  MemoryResourceProvider resourceProvider;
  protocol.ContextRoot root;

  void setUp() {
    resourceProvider = new MemoryResourceProvider();
    new MockSdk(resourceProvider: resourceProvider);
    plugin = new AngularAnalyzerPlugin(resourceProvider);
    final versionCheckParams = new protocol.PluginVersionCheckParams(
        "~/.dartServer/.analysis-driver", "/sdk", "1.0.0");
    plugin.handlePluginVersionCheck(versionCheckParams);
    root = new protocol.ContextRoot("/test", [],
        optionsFile: '/test/analysis_options.yaml');
  }

  void enableAnalyzerPluginsAngular({List<String> extraOptions = const []}) =>
      setOptionsFileContent(optionsHeader +
          optionsSection('angular',
              extraOptions: ['enabled: true']..addAll(extraOptions)));

  void enableAnalyzerPluginsAngularPlugin(
          {List<String> extraOptions = const []}) =>
      setOptionsFileContent(optionsHeader +
          optionsSection('angular_analyzer_plugin',
              extraOptions: ['enabled: true']..addAll(extraOptions)));

  void setAnalysisYamlBothPluginSections(
          {List<String> angularOptions = const [],
          List<String> angularPluginOptions = const []}) =>
      setOptionsFileContent(optionsHeader +
          optionsSection('angular', extraOptions: angularOptions) +
          optionsSection('angular_analyzer_plugin',
              extraOptions: angularPluginOptions));

  String optionsHeader = '''
analyzer:
  plugins:
''';

  String optionsSection(String key, {List<String> extraOptions = const []}) =>
      '''
    $key:
${extraOptions.map((option) => """
      $option
""").join('')}
''';

  void setOptionsFileContent(String content) {
    resourceProvider.newFile('/test/analysis_options.yaml', content);
  }
}

/// Since our yaml generation is...not ideal, let's test it.
@reflectiveTest
class AnalysisOptionsUtilsTest extends AnalysisOptionsUtilsBase {
  // ignore: non_constant_identifier_names
  void test_enableAnalyzerPluginsAngular_noExtraOptions() {
    enableAnalyzerPluginsAngular();
    final optionsText = resourceProvider
        .getFile('/test/analysis_options.yaml')
        .readAsStringSync();

    expect(optionsText, '''
analyzer:
  plugins:
    angular:
      enabled: true

''');
  }

  // ignore: non_constant_identifier_names
  void test_enableAnalyzerPluginsAngular_extraOptions() {
    enableAnalyzerPluginsAngular(extraOptions: ['foo: bar', 'baz:', '  - qux']);
    final optionsText = resourceProvider
        .getFile('/test/analysis_options.yaml')
        .readAsStringSync();

    expect(optionsText, '''
analyzer:
  plugins:
    angular:
      enabled: true
      foo: bar
      baz:
        - qux

''');
  }

  /// Since our yaml generation is...not ideal, let's test it.
  // ignore: non_constant_identifier_names
  void test_enableAnalyzerPluginsAngularPlugin_noExtraOptions() {
    enableAnalyzerPluginsAngularPlugin();
    final optionsText = resourceProvider
        .getFile('/test/analysis_options.yaml')
        .readAsStringSync();

    expect(optionsText, '''
analyzer:
  plugins:
    angular_analyzer_plugin:
      enabled: true

''');
  }

  // ignore: non_constant_identifier_names
  void test_enableAnalyzerPluginsAngularPlugin_extraOptions() {
    enableAnalyzerPluginsAngularPlugin(
        extraOptions: ['foo: bar', 'baz:', '  - qux']);
    final optionsText = resourceProvider
        .getFile('/test/analysis_options.yaml')
        .readAsStringSync();

    expect(optionsText, '''
analyzer:
  plugins:
    angular_analyzer_plugin:
      enabled: true
      foo: bar
      baz:
        - qux

''');
  }

  // ignore: non_constant_identifier_names
  void test_setAnalysisYamlBothPluginSections() {
    setAnalysisYamlBothPluginSections(angularOptions: [
      'foo:',
      '  - bar',
    ], angularPluginOptions: [
      'baz:',
      '  - qux',
    ]);

    final optionsText = resourceProvider
        .getFile('/test/analysis_options.yaml')
        .readAsStringSync();

    expect(optionsText, '''
analyzer:
  plugins:
    angular:
      foo:
        - bar

    angular_analyzer_plugin:
      baz:
        - qux

''');
  }
}

class MockResourceProvider extends Mock implements ResourceProvider {}
