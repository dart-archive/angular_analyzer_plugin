import 'dart:async';

import 'package:analyzer/error/error.dart';
import 'package:analysis_server/src/analysis_server.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:analyzer/src/context/builder.dart';
import 'package:analysis_server/plugin/protocol/protocol.dart'
    show
        Request,
        CompletionGetSuggestionsParams,
        CompletionGetSuggestionsResult;
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
    server.onResultErrorSupplementor = sumErrors;
    server.onNoAnalysisResult = sendHtmlResult;
    server.onNoAnalysisCompletion = sendAngularCompletions;
    //server.onExtraCompletionContributor = sendAngularContributor;
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
    angularDrivers[driverPath] = driver;
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

  // Handles .dart completion. Returns a CompletionContributor to the
  // domain completion.
  Future<AngularCompletionContributor> sendAngularContributor(
      CompletionRequestImpl request) async {
    var filePath = request.result.path;
    if (server.contextManager.isInAnalysisRoot(filePath)) {
      for (final driverPath in angularDrivers.keys) {
        if (server.contextManager.getContextFolderFor(filePath).path ==
            driverPath) {
          final driver = angularDrivers[driverPath];
          var template = await driver.getTemplateForFile(filePath);
          if (template != null) {
            return new AngularCompletionContributor(driver);
          }
        }
      }
    }
    return null;
  }

  // Handles .html completion. Directly sends the suggestions to the
  // [completionHandler].
  Future sendAngularCompletions(
    Request request,
    CompletionDomainHandler completionHandler,
    CompletionGetSuggestionsParams params,
    CompletionPerformance performance,
    String completionId,
  ) async {
    var filePath = (request.toJson()['params'] as Map)['file'];
    var source =
        new FileSource(server.resourceProvider.getFile(filePath), filePath);

    if (server.contextManager.isInAnalysisRoot(filePath)) {
      for (final driverPath in angularDrivers.keys) {
        if (server.contextManager.getContextFolderFor(filePath).path ==
            driverPath) {
          final driver = angularDrivers[driverPath];

          var completionContributor = new AngularCompletionContributor(driver);
          CompletionRequestImpl completionRequest = new CompletionRequestImpl(
              null,
              null,
              server.resourceProvider,
              server.searchEngine,
              source,
              params.offset,
              performance,
              server.ideOptions);
          completionHandler.setNewRequest(completionRequest);
          server.sendResponse(new CompletionGetSuggestionsResult(completionId)
              .toResponse(request.id));
          var suggestions =
              await completionContributor.computeSuggestions(completionRequest);
          completionHandler.sendCompletionNotification(
              completionId,
              completionRequest.replacementOffset,
              completionRequest.replacementLength,
              suggestions);
          completionHandler.ifMatchesRequestClear(completionRequest);
        }
      }
    }
  }
}
