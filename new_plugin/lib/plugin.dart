// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/context/context_root.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/src/context/builder.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/generated/engine.dart' hide AnalysisResult;
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_constants.dart' as plugin;
import 'package:analyzer_plugin/protocol/protocol_generated.dart' as plugin;
import 'package:analyzer_plugin/utilities/analyzer_converter.dart';
import 'package:angular_analysis_plugin/src/error_visitor.dart';
import 'package:front_end/src/base/source.dart';

class AngularAnalysisPlugin extends ServerPlugin {
  AngularAnalysisPlugin(ResourceProvider provider) : super(provider);

  @override
  List<String> get fileGlobsToAnalyze => <String>['*.dart', '*.html'];

  @override
  String get name => 'Angular Analysis Plugin';

  @override
  String get version => '1.0.0';

  @override
  AnalysisDriverGeneric createAnalysisDriver(plugin.ContextRoot contextRoot) {
    ContextRoot root = new ContextRoot(contextRoot.root, contextRoot.exclude);
    DartSdkManager sdkManager =
        new DartSdkManager('/Users/brianwilkerson/Dev/dart/dart-sdk', true);
    ContextBuilder builder =
        new ContextBuilder(resourceProvider, sdkManager, null);
    builder.analysisDriverScheduler = analysisDriverScheduler;
    return builder.buildDriver(root);
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
    subscriptions
        .forEach((String filePath, List<plugin.AnalysisService> services) {
      // TODO(brianwilkerson) Get the results for this file.
      AnalysisResult result;
      for (plugin.AnalysisService service in services) {
        sendNotificationForSubscription(filePath, service, result);
      }
    });
  }

  void _processResults(AnalysisResult result) {
    RecordingErrorListener listener = new RecordingErrorListener();
    Source source = result.unit.element.source;
    String filePath = source.fullName;
    ErrorReporter reporter = new ErrorReporter(listener, source);
    AngularErrorVisitor visitor = new AngularErrorVisitor(reporter);
    result.unit.accept(visitor);
    AnalyzerConverter converter = new AnalyzerConverter();
    // TODO(brianwilkerson) Get the right analysis options.
    List<plugin.AnalysisError> errors = converter.convertAnalysisErrors(
        listener.errors,
        lineInfo: result.lineInfo,
        options: null);
    channel.sendNotification(
        new plugin.AnalysisErrorsParams(filePath, errors).toNotification());
    // TODO(brianwilkerson) Generate notifications based on subscriptions.
    List<plugin.AnalysisService> services =
        subscriptionManager.servicesForFile(filePath);
    for (plugin.AnalysisService service in services) {
      sendNotificationForSubscription(filePath, service, result);
    }
  }
}
