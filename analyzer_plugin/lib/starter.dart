import 'package:analysis_server/src/analysis_server.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:analyzer/src/context/builder.dart';

class Starter {
  final angularDrivers = <AngularDriver>[];
  AnalysisServer server;

  void start(AnalysisServer server) {
    this.server = server;
    ContextBuilder.onCreateAnalysisDriver = onCreateAnalysisDriver;
    server.onResultErrorSupplementor = sumErrors;
  }

  void onCreateAnalysisDriver(
      analysisDriver,
      scheduler,
      logger,
      resourceProvider,
      byteStore,
      contentOverlay,
      driverPath,
      sourceFactory,
      analysisOptions) {
    final AngularDriver driver = new AngularDriver(server, analysisDriver,
        scheduler, byteStore, sourceFactory, contentOverlay);
    angularDrivers.add(driver);
    server.onFileAdded.listen((String path) {
      if (server.contextManager.getContextFolderFor(path).path == driverPath) {
        // only the owning driver "adds" the path
        driver.addFile(path);
      } else {
        // but the addition of a file is a "change" to all the other drivers
        driver.fileChanged(path);
      }
    });
    server.onFileChanged.listen((String path) {
      // all drivers get change notification
      driver.fileChanged(path);
    });
  }

  Future sumErrors(String path, List<AnalysisError> errors) async {
    for (final driver in angularDrivers) {
      final angularErrors = await driver.requestDartErrors(path);
      errors.addAll(angularErrors);
    }
    return null;
  }
}
