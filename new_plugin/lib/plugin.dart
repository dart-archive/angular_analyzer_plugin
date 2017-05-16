// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//import 'dart:async';

//import 'package:analysis_server/src/services/completion/completion_core.dart';
//import 'package:analysis_server/src/services/completion/dart/completion_manager.dart';
import 'package:analyzer/context/context_root.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/context/builder.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_constants.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:angular_analysis_plugin/src/notification_manager.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
//import 'package:angular_analyzer_server_plugin/src/completion.dart';
import 'package:analyzer_plugin/protocol/protocol.dart' as plugin;

class AngularAnalysisPlugin extends ServerPlugin {
  AngularAnalysisPlugin(ResourceProvider provider) : super(provider);

  @override
  List<String> get fileGlobsToAnalyze => <String>['*.dart', '*.html'];

  @override
  String get name => 'Angular Analysis Plugin';

  @override
  String get version => '1.0.0';

  @override
  String get contactInfo =>
      'Please file issues at https://github.com/dart-lang/angular_analyzer_plugin';

  @override
  AnalysisDriverGeneric createAnalysisDriver(plugin.ContextRoot contextRoot) {
    final root = new ContextRoot(contextRoot.root, contextRoot.exclude);
    // TODO new API to get this path safely?
    final sdkManager = new DartSdkManager('/home/mfairhurst/.dart-sdk', true);
    final logger = new PerformanceLog(new StringBuffer());
    final builder = new ContextBuilder(resourceProvider, sdkManager, null)
      ..analysisDriverScheduler = analysisDriverScheduler
      ..byteStore = byteStore
      ..performanceLog = logger
      ..fileContentOverlay = fileContentOverlay;
    final dartDriver = builder.buildDriver(root);

    final sourceFactory = dartDriver.sourceFactory;

    return new AngularDriver(
        new ChannelNotificationManager(channel),
        dartDriver,
        analysisDriverScheduler,
        byteStore,
        sourceFactory,
        fileContentOverlay);
  }

  void sendNotificationForSubscription(
      String fileName, plugin.AnalysisService service, AnalysisResult result) {
    switch (service) {
      case plugin.AnalysisService.FOLDING:
        // TODO(brianwilkerson) Implement this.
        break;
      case plugin.AnalysisService.HIGHLIGHTS:
        // TODO(brianwilkerson) Implement this.
        break;
      case plugin.AnalysisService.NAVIGATION:
        // TODO(brianwilkerson) Implement this.
        break;
      case plugin.AnalysisService.OCCURRENCES:
        // TODO(brianwilkerson) Implement this.
        break;
      case plugin.AnalysisService.OUTLINE:
        // TODO(brianwilkerson) Implement this.
        break;
      default:
        // Ignore unhandled service types.
        break;
    }
  }

  @override
  void contentChanged(String path) {
    final contextRoot = contextRootContaining(path);

    if (contextRoot == null) {
      return;
    }

    final driver = (driverMap[contextRoot] as AngularDriver)
      ..addFile(path) // TODO new API to only do this on file add
      ..fileChanged(path);

    driver.dartDriver
      ..addFile(path) // TODO new API to only do this on file add
      ..changeFile(path);
  }

  /// The method that is called when an error has occurred in the analysis
  /// server. This method will not be invoked under normal conditions.
  @override
  void onError(Object exception, StackTrace stackTrace) {
    print('Communication Exception: $exception\n$stackTrace');
    throw exception;
  }

  @override
  void sendNotificationsForSubscriptions(
      Map<String, List<plugin.AnalysisService>> subscriptions) {
    subscriptions
        .forEach((String filePath, List<plugin.AnalysisService> services) {
      // TODO(brianwilkerson) Get the results for this file.
      AnalysisResult result;
      for (plugin.AnalysisService service in services) {
        sendNotificationForSubscription(filePath, service, result);
      }
    });
  }

  //@override
  //Future<plugin.CompletionGetSuggestionsResult> handleCompletionGetSuggestions(
  //    plugin.CompletionGetSuggestionsParams parameters) async {
  //  final filePath = parameters.file;
  //  final contextRoot = contextRootContaining(filePath);
  //  if (contextRoot == null) {
  //    // Return an error from the request.
  //    throw new plugin.RequestFailure(plugin.RequestErrorFactory
  //        .pluginError('Failed to analyze $filePath', null));
  //  }
  //  final AngularDriver driver = driverMap[contextRoot];
  //  final analysisResult = await driver.dartDriver.getResult(filePath);
  //  final contributor = new AngularCompletionContributor(driver);
  //  final request = new CompletionRequestImpl(
  //      analysisResult, resourceProvider, null, parameters.offset, null, null);
  //  final DartCompletionRequestImpl dartRequest =
  //      await DartCompletionRequestImpl.from(request);
  //  final suggestions = await contributor.computeSuggestions(dartRequest);
  //  return new plugin.CompletionGetSuggestionsResult(
  //      request.replacementOffset, request.replacementLength, suggestions);
  //}
}
