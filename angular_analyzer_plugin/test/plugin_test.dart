import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as protocol;
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:angular_analyzer_plugin/plugin.dart';
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

  void setUp() {
    resourceProvider = PhysicalResourceProvider.INSTANCE;
    plugin = new AngularAnalyzerPlugin(resourceProvider);
    final versionCheckParams = new protocol.PluginVersionCheckParams(
        "~/.dartServer/.analysis-driver", "../deps/sdk/sdk", "1.0.0");
    plugin.handlePluginVersionCheck(versionCheckParams);
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver() {
    final root = new protocol.ContextRoot("/test", []);
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, isNotNull);
    expect(driver.byteStore, isNotNull);
  }

  // ignore: non_constant_identifier_names
  void test_createAnalysisDriver_containsDartDriver() {
    final root = new protocol.ContextRoot("/test", []);
    final AngularDriver driver = plugin.createAnalysisDriver(root);

    expect(driver, isNotNull);
    expect(driver.dartDriver, isNotNull);
    expect(driver.dartDriver.analysisOptions, isNotNull);
    expect(driver.dartDriver.fsState, isNotNull);
    expect(driver.dartDriver.name, equals("/test"));
    expect(driver.dartDriver.sourceFactory, isNotNull);
    expect(driver.dartDriver.contextRoot, isNotNull);
  }
}

class MockResourceProvider extends TypedMock implements ResourceProvider {}
