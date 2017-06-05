// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import 'package:analysis_server/src/services/completion/completion_core.dart';
import 'package:analysis_server/src/services/completion/completion_performance.dart';
import 'package:analysis_server/src/domains/analysis/navigation.dart';
import 'package:analyzer/context/context_root.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/context/builder.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:front_end/src/base/performace_logger.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_constants.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:angular_analysis_plugin/src/notification_manager.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:angular_analyzer_server_plugin/src/completion.dart';
import 'package:angular_analyzer_server_plugin/src/analysis.dart';
import 'package:analyzer_plugin/protocol/protocol.dart' as plugin;
import 'package:meta/meta.dart';

class AngularAnalysisPlugin extends ServerPlugin {
  AngularAnalysisPlugin(ResourceProvider provider) : super(provider);

  @override
  List<String> get fileGlobsToAnalyze => <String>['*.dart', '*.html'];

  @override
  String get name => 'Angular Analysis Plugin';

  @override
  String get version => '1.0.0-alpha.0';

  @override
  String get contactInfo =>
      'Please file issues at https://github.com/dart-lang/angular_analyzer_plugin';

  @override
  AnalysisDriverGeneric createAnalysisDriver(plugin.ContextRoot contextRoot) {
    final root = new ContextRoot(contextRoot.root, contextRoot.exclude);
    // TODO new API to get this path safely?
    final logger = new PerformanceLog(new StringBuffer());
    final builder = new ContextBuilder(resourceProvider, sdkManager, null)
      ..analysisDriverScheduler = analysisDriverScheduler
      ..byteStore = byteStore
      ..performanceLog = logger
      ..fileContentOverlay = fileContentOverlay;
    final dartDriver = builder.buildDriver(root);

    final sourceFactory = dartDriver.sourceFactory;

    final driver = new AngularDriver(
        new ChannelNotificationManager(channel),
        dartDriver,
        analysisDriverScheduler,
        byteStore,
        sourceFactory,
        fileContentOverlay);

    driver.dartResultsStream
        .listen((result) => onResult(result, driver, templatesOnly: true));
    driver.htmlResultsStream
        .listen((result) => onResult(result, driver, templatesOnly: false));
    return driver;
  }

  bool fileHasSubscription(String filePath, plugin.AnalysisService service) =>
      (subscriptionManager.servicesForFile(filePath) ?? const [])
          .contains(service);

  void onResult(DirectivesResult result, AngularDriver driver,
      {@required bool templatesOnly}) {
    final collector = new NavigationCollectorImpl();
    final filename = result.filename;

    if (filename == null ||
        !fileHasSubscription(filename, plugin.AnalysisService.NAVIGATION)) {
      return;
    }

    if (result.cacheResult) {
      // get a non-cached result, so we have an AST.
      // TODO(mfairhurst) make this assurance in a less hacky way
      templatesOnly
          ? driver.resolveHtml(filename, ignoreCache: true)
          : driver.resolveDart(filename, withDirectives: true);
      return;
    }

    final lineInfo = new LineInfo.fromContent(driver.getFileContent(filename));

    new AngularNavigation()
      ..computeNavigation(
          collector, driver.getSource(filename), null, null, lineInfo, result,
          templatesOnly: templatesOnly);
    collector.createRegions();
    channel.sendNotification(new plugin.AnalysisNavigationParams(
            filename, collector.regions, collector.targets, collector.files)
        .toNotification());
  }

  @override
  Future<plugin.AnalysisGetNavigationResult> handleAnalysisGetNavigation(
      plugin.AnalysisGetNavigationParams params) async {
    final filename = params.file;
    final contextRoot = contextRootContaining(filename);

    if (contextRoot == null) {
      // empty resp
      return super.handleAnalysisGetNavigation(params);
    }

    final driver = (driverMap[contextRoot] as AngularDriver);

    final templatesOnly = filename.endsWith('.html');
    final result = templatesOnly
        ? await driver.resolveHtml(filename, ignoreCache: true)
        : await driver.resolveDart(filename,
            withDirectives: true, onlyIfChangedSignature: false);

    final lineInfo = new LineInfo.fromContent(driver.getFileContent(filename));

    final collector = new NavigationCollectorImpl();
    new AngularNavigation()
      ..computeNavigation(collector, driver.getSource(filename), params.offset,
          params.length, lineInfo, result,
          templatesOnly: templatesOnly);
    collector.createRegions();
    return new plugin.AnalysisGetNavigationResult(
        collector.files, collector.targets, collector.regions);
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
    // ignore: only_throw_errors
    throw exception;
  }

  @override
  void sendNotificationsForSubscriptions(
      Map<String, List<plugin.AnalysisService>> subscriptions) {
    subscriptions.forEach((filePath, services) {
      // TODO(brianwilkerson) Get the results for this file.
      AnalysisResult result;
      for (final service in services) {
        sendNotificationForSubscription(filePath, service, result);
      }
    });
  }

  @override
  Future<plugin.CompletionGetSuggestionsResult> handleCompletionGetSuggestions(
      plugin.CompletionGetSuggestionsParams parameters) async {
    final filePath = parameters.file;
    final contextRoot = contextRootContaining(filePath);
    if (contextRoot == null) {
      // Return an error from the request.
      throw new plugin.RequestFailure(plugin.RequestErrorFactory
          .pluginError('Failed to analyze $filePath', null));
    }
    final AngularDriver driver = driverMap[contextRoot];
    final analysisResult = await driver.dartDriver.getResult(filePath);
    final contributor = new AngularCompletionContributor(driver);
    final performance = new CompletionPerformance();
    final fileSource = resourceProvider.getFile(filePath).createSource();
    final request = new CompletionRequestImpl(analysisResult, resourceProvider,
        fileSource, parameters.offset, performance);
    final suggestions = await contributor.computeSuggestions(request);
    return new plugin.CompletionGetSuggestionsResult(
        request.replacementOffset, request.replacementLength, suggestions);
  }
}
