import 'dart:async';

import 'package:analyzer/error/error.dart';
import 'package:analysis_server/src/analysis_server.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:angular_analyzer_plugin/notification_manager.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:analyzer/src/context/builder.dart';
import 'package:analysis_server/src/protocol_server.dart' as protocol;
import 'package:analysis_server/protocol/protocol.dart' show Request;
import 'package:analysis_server/protocol/protocol_generated.dart'
    show CompletionGetSuggestionsParams, CompletionGetSuggestionsResult;
import 'package:analysis_server/src/services/completion/completion_core.dart';
import 'package:analysis_server/src/services/completion/completion_performance.dart';
import 'package:angular_analyzer_server_plugin/src/completion.dart';
import 'package:analyzer/src/source/source_resource.dart';
import 'package:analysis_server/src/domain_completion.dart';

class Starter {
  final angularDrivers = <String, AngularDriver>{};
  AnalysisServer server;

  void start(AnalysisServer server) {
    this.server = server;
    ContextBuilder.onCreateAnalysisDriver = onCreateAnalysisDriver;
    server
      ..onResultErrorSupplementor = sumErrors
      ..onNoAnalysisResult = sendHtmlResult;
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
    final driver = new AngularDriver(
        new ServerNotificationManager(server, analysisDriver),
        analysisDriver,
        scheduler,
        byteStore,
        sourceFactory,
        contentOverlay);
    angularDrivers[driverPath] = driver;
    server.onFileAdded.listen((path) {
      if (server.contextManager.getContextFolderFor(path).path == driverPath) {
        // only the owning driver "adds" the path
        driver.addFile(path);
      } else {
        // but the addition of a file is a "change" to all the other drivers
        driver.fileChanged(path);
      }
    });

    // all drivers get change notification
    server.onFileChanged.listen(driver.fileChanged);
  }

  Future sumErrors(String path, List<AnalysisError> errors) async {
    for (final driver in angularDrivers.values) {
      final angularErrors = await driver.requestDartErrors(path);
      errors.addAll(angularErrors);
    }
    return null;
  }

  Future sendHtmlResult(String path, Function sendFn) async {
    for (final driverPath in angularDrivers.keys) {
      if (server.contextManager.getContextFolderFor(path).path == driverPath) {
        final driver = angularDrivers[driverPath];
        // only the owning driver "adds" the path
        final angularErrors = await driver.requestHtmlErrors(path);
        sendFn(
            driver.dartDriver.analysisOptions,
            new LineInfo.fromContent(driver.getFileContent(path)),
            angularErrors);
        return;
      }
    }

    sendFn(null, null, null);
  }
}

class ServerNotificationManager implements NotificationManager {
  final AnalysisServer server;
  final AnalysisDriver dartDriver;

  ServerNotificationManager(this.server, this.dartDriver);

  @override
  void recordAnalysisErrors(
          String path, LineInfo lineInfo, List<AnalysisError> analysisErrors) =>
      server.notificationManager.recordAnalysisErrors(
          'angular driver',
          path,
          protocol.doAnalysisError_listFromEngine(
              dartDriver.analysisOptions, lineInfo, analysisErrors));
}
