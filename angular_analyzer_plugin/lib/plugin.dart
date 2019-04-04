// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'dart:async';

import 'package:analyzer/context/context_root.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/context/builder.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/dart/analysis/performance_logger.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer_plugin/plugin/completion_mixin.dart';
import 'package:analyzer_plugin/plugin/navigation_mixin.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_constants.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:analyzer_plugin/src/utilities/completion/completion_core.dart';
import 'package:analyzer_plugin/src/utilities/navigation/navigation.dart';
import 'package:analyzer_plugin/utilities/analyzer_converter.dart';
import 'package:analyzer_plugin/utilities/completion/completion_core.dart';
import 'package:analyzer_plugin/utilities/navigation/navigation.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:angular_analyzer_plugin/src/completion.dart';
import 'package:angular_analyzer_plugin/src/completion_request.dart';
import 'package:angular_analyzer_plugin/src/navigation.dart';
import 'package:angular_analyzer_plugin/src/navigation_request.dart';
import 'package:angular_analyzer_plugin/src/notification_manager.dart';
import 'package:angular_analyzer_plugin/src/options.dart';
import 'package:meta/meta.dart';

class AngularAnalyzerPlugin extends ServerPlugin
    with CompletionMixin, NavigationMixin {
  AngularAnalyzerPlugin(ResourceProvider provider) : super(provider);

  @override
  String get contactInfo =>
      'Please file issues at https://github.com/dart-lang/angular_analyzer_plugin';

  @override
  List<String> get fileGlobsToAnalyze => <String>['*.dart', '*.html'];

  @override
  String get name => 'Angular Analysis Plugin';

  @override
  String get version => '1.0.0-alpha.0';

  AngularDriver angularDriverForPath(String path) {
    final driver = super.driverForPath(path);
    if (driver is AngularDriver) {
      return driver;
    }
    return null;
  }

  @override
  void contentChanged(String path) {
    final driver = angularDriverForPath(path);
    if (driver == null) {
      return;
    }

    driver
      ..addFile(path) // TODO new API to only do this on file add
      ..fileChanged(path);

    driver.dartDriver
      ..addFile(path) // TODO new API to only do this on file add
      ..changeFile(path);
  }

  @override
  AnalysisDriverGeneric createAnalysisDriver(plugin.ContextRoot contextRoot) {
    final root = new ContextRoot(contextRoot.root, contextRoot.exclude,
        pathContext: resourceProvider.pathContext)
      ..optionsFilePath = contextRoot.optionsFile;
    final options = getOptions(root.optionsFilePath);

    final logger = new PerformanceLog(new StringBuffer());
    final builder = new ContextBuilder(resourceProvider, sdkManager, null)
      ..analysisDriverScheduler = (new AnalysisDriverScheduler(logger)..start())
      ..byteStore = byteStore
      ..performanceLog = logger
      ..fileContentOverlay = fileContentOverlay;

    final dartDriver = builder.buildDriver(root)
      ..results.listen((_) {}) // Consume the stream, otherwise we leak.
      ..exceptions.listen((_) {}); // Consume the stream, otherwise we leak.

    final sourceFactory = dartDriver.sourceFactory;

    final driver = new AngularDriver(
        resourceProvider,
        // TODO(mfairhurst) remove NotificationManager & old plugin loader.
        new NoopNotificationManager(),
        dartDriver,
        analysisDriverScheduler,
        byteStore,
        sourceFactory,
        fileContentOverlay,
        options);

    driver.dartResultsStream
        .listen((result) => onResult(result, driver, isHtml: false));
    driver.htmlResultsStream
        .listen((result) => onResult(result, driver, isHtml: true));
    return driver;
  }

  @override
  List<CompletionContributor> getCompletionContributors(String path) {
    if (angularDriverForPath(path) == null) {
      return [];
    }

    return <CompletionContributor>[
      new AngularCompletionContributor(),
      new NgInheritedReferenceContributor(),
      new NgTypeMemberContributor(),
      new NgOffsetLengthContributor(),
    ];
  }

  @override
  Future<CompletionRequest> getCompletionRequest(
      plugin.CompletionGetSuggestionsParams parameters) async {
    final path = parameters.file;
    final driver = angularDriverForPath(path);
    final offset = parameters.offset;

    if (driver == null) {
      return new DartCompletionRequestImpl(resourceProvider, offset, null);
    }

    final templates = await driver.getTemplatesForFile(path);
    final standardHtml = await driver.getStandardHtml();
    assert(standardHtml != null);
    return new AngularCompletionRequest(
        offset, path, resourceProvider, templates, standardHtml);
  }

  /// Return a list containing the navigation contributors that should be used to
  /// create navigation information when used in the context of the given
  /// analysis [driver].
  @override
  List<NavigationContributor> getNavigationContributors(String path) =>
      [new AngularNavigation(angularDriverForPath(path).contentOverlay)];

  /// Return the navigation request that should be passed to the contributors
  /// returned from [getNavigationContributors].
  @override
  Future<NavigationRequest> getNavigationRequest(
      plugin.AnalysisGetNavigationParams parameters) async {
    final driver = driverForPath(parameters.file) as AngularDriver;
    final isHtml = parameters.file.endsWith('.html');
    final result = isHtml
        ? await driver.requestHtmlResult(parameters.file)
        : await driver.requestDartResult(parameters.file);
    return new AngularNavigationRequest(
        parameters.file, parameters.offset, parameters.length, result);
  }

  AngularOptions getOptions(String optionsFilePath) {
    if (optionsFilePath != null && optionsFilePath.isNotEmpty) {
      final file = resourceProvider.getFile(optionsFilePath);
      if (file.exists) {
        return new AngularOptions.from(file.createSource());
      }
    }
    return new AngularOptions.defaults();
  }

  /// The method that is called when an error has occurred in the analysis
  /// server. This method will not be invoked under normal conditions.
  @override
  void onError(Object exception, StackTrace stackTrace) {
    print('Communication Exception: $exception\n$stackTrace');
    // ignore: only_throw_errors
    throw exception;
  }

  void onResult(DirectivesResult result, AngularDriver driver,
      {@required bool isHtml}) {
    _handleResultErrors(result, driver);
    _handleResultNavigation(result, driver, isHtml: isHtml);
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

  /// Send notifications for errors for this result
  void _handleResultErrors(DirectivesResult result, AngularDriver driver) {
    final converter = new AnalyzerConverter();
    final lineInfo =
        new LineInfo.fromContent(driver.getFileContent(result.filename));
    // TODO(mfairhurst) Get the right analysis options.
    final errors = converter.convertAnalysisErrors(
      result.errors,
      lineInfo: lineInfo,
    );
    channel.sendNotification(
        new plugin.AnalysisErrorsParams(result.filename, errors)
            .toNotification());
  }

  /// Send notifications for navigation for this result
  void _handleResultNavigation(DirectivesResult result, AngularDriver driver,
      {@required bool isHtml}) {
    final collector = new NavigationCollectorImpl();
    final filename = result.filename;
    if (filename == null ||
        !subscriptionManager.hasSubscriptionForFile(
            filename, plugin.AnalysisService.NAVIGATION)) {
      return;
    }

    if (result.cacheResult) {
      // get a non-cached result, so we have an AST.
      // TODO(mfairhurst) make this assurance in a less hacky way
      isHtml
          ? driver.requestHtmlResult(filename)
          : driver.requestDartResult(filename);
      return;
    }

    new AngularNavigation(driver.contentOverlay)
      ..computeNavigation(
          new AngularNavigationRequest(filename, null, null, result), collector,
          templatesOnly: isHtml);
    collector.createRegions();
    channel.sendNotification(new plugin.AnalysisNavigationParams(
            filename, collector.regions, collector.targets, collector.files)
        .toNotification());
  }
}
