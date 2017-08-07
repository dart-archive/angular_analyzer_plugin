import 'dart:async';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as protocol;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as protocol;
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:angular_analyzer_plugin/plugin.dart';
import 'package:angular_analyzer_plugin/src/noop_driver.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';

import 'mock_sdk.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PluginIntegrationTest);
  });
}

@reflectiveTest
class PluginIntegrationTest {
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

  void enableInOptionsFile() {
    setOptionsFileContent('''
plugins:
  angular:
    enabled: true
''');
  }

  void setOptionsFileContent(String content) {
    resourceProvider.newFile('/test/analysis_options.yaml', content);
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver() {
    enableInOptionsFile();
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, isNotNull);
    expect(driver.byteStore, isNotNull);
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_containsDartDriver() {
    enableInOptionsFile();
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
  void test_createAnalysisDriver_noAnalysisOptionsMeansDisabled() {
    root.optionsFile = null;
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, const isInstanceOf<NoopDriver>());
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_emptyAnalysisOptionsMeansDisabled() {
    root.optionsFile = '';
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, const isInstanceOf<NoopDriver>());
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_analysisOptionsNotExistsMeansDisabled() {
    final AngularDriver driver = plugin.createAnalysisDriver(root);
    // and then don't set up analysis_options.yaml

    expect(driver, const isInstanceOf<NoopDriver>());
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_analysisOptionsNotEnabled() {
    setOptionsFileContent('''
analyzer:
  strong-mode: true

plugins:
  other-plugin:
    that: "is irrelevant"
''');
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, const isInstanceOf<NoopDriver>());
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_analysisOptionsDisabled() {
    setOptionsFileContent('''
plugins:
  angular:
    enabled: false
''');
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, const isInstanceOf<NoopDriver>());
  }

  // ignore: non_constant_identifier_names
  void test_noAnalysisDriver_getAngularDriverIsNull() {
    root.optionsFile = null;
    plugin.createAnalysisDriver(root);

    expect(plugin.angularDriverForPath(root.root), isNull);
  }

  // ignore: non_constant_identifier_names
  void test_noAnalysisDriver_getCompletionContributors_Empty() {
    root.optionsFile = null;
    plugin.createAnalysisDriver(root);

    expect(plugin.getCompletionContributors(root.root), hasLength(0));
  }

  // ignore: non_constant_identifier_names
  Future test_noAnalysisDriver_updateFilesOk() async {
    root.optionsFile = null;
    plugin.createAnalysisDriver(root);

    await plugin.handleAnalysisUpdateContent(
        new protocol.AnalysisUpdateContentParams(
            {'/test/test.dart': new protocol.AddContentOverlay('foo')}));
    await plugin
        .handleAnalysisUpdateContent(new protocol.AnalysisUpdateContentParams({
      '/test/test.dart': new protocol.ChangeContentOverlay(
          [new protocol.SourceEdit(1, 2, 'foo')])
    }));
    await plugin.handleAnalysisUpdateContent(
        new protocol.AnalysisUpdateContentParams(
            {'/test/test.dart': new protocol.RemoveContentOverlay()}));
    // should not have thrown
  }

  // ignore: non_constant_identifier_names
  Future test_noAnalysisDriver_getCompletionOk() async {
    root.optionsFile = null;
    plugin.createAnalysisDriver(root);

    final resp = await plugin.handleCompletionGetSuggestions(
        new protocol.CompletionGetSuggestionsParams('/test/test.dart', 0));

    expect(resp.replacementOffset, equals(0));
    expect(resp.replacementLength, equals(0));
    expect(resp.results, isEmpty);
  }
}

class MockResourceProvider extends Mock implements ResourceProvider {}
