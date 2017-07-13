import 'dart:async';
import 'dart:io' as io;
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as protocol;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as protocol;
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:angular_analyzer_plugin/plugin.dart';
import 'package:angular_analyzer_plugin/src/noop_driver.dart';
import 'package:angular_analyzer_plugin/src/file_service.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';
import 'package:typed_mock/typed_mock.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(PluginIntegrationTest);
  });
}

@reflectiveTest
class PluginIntegrationTest {
  AngularAnalyzerPlugin plugin;
  ResourceProvider resourceProvider;
  FileService fileService;
  protocol.ContextRoot root;

  void setUp() {
    resourceProvider = PhysicalResourceProvider.INSTANCE;
    fileService = new MockFileService();
    plugin = new AngularAnalyzerPlugin(resourceProvider, fileService);
    final versionCheckParams = new protocol.PluginVersionCheckParams(
        "~/.dartServer/.analysis-driver", "../deps/sdk/sdk", "1.0.0");
    plugin.handlePluginVersionCheck(versionCheckParams);
    root = new protocol.ContextRoot("/test", [],
        optionsFile: '/test/analysis_options.yaml');
  }

  void enableInOptionsFile() {
    final mockFile = new MockFile();
    when(fileService.newFile('/test/analysis_options.yaml'))
        .thenReturn(mockFile);
    when(mockFile.existsSync()).thenReturn(true);
    when(mockFile.readAsStringSync()).thenReturn('''
angular:
  enabled: true
''');
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
    final mockFile = new MockFile();
    when(fileService.newFile('/test/analysis_options.yaml'))
        .thenReturn(mockFile);
    when(mockFile.existsSync()).thenReturn(false);
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, const isInstanceOf<NoopDriver>());
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_analysisOptionsNotEnabled() {
    final mockFile = new MockFile();
    when(fileService.newFile('/test/analysis_options.yaml'))
        .thenReturn(mockFile);
    when(mockFile.existsSync()).thenReturn(true);
    when(mockFile.readAsStringSync()).thenReturn('''
analyzer:
  strong-mode: true

other-stuff:
  that: "is not used"
''');
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, const isInstanceOf<NoopDriver>());
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_analysisOptionsDisabled() {
    final mockFile = new MockFile();
    when(fileService.newFile('/test/analysis_options.yaml'))
        .thenReturn(mockFile);
    when(mockFile.existsSync()).thenReturn(true);
    when(mockFile.readAsStringSync()).thenReturn('''
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

class MockResourceProvider extends TypedMock implements ResourceProvider {}

class MockFileService extends TypedMock implements FileService {}

class MockFile extends TypedMock implements io.File {}
