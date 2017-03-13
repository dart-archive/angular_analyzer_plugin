// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/starter.dart';

import 'package:analysis_server/src/analysis_server.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:analyzer/src/context/builder.dart';
import 'package:angular_analyzer_plugin/plugin.dart';
import 'package:angular_analyzer_server_plugin/plugin.dart';
import 'package:plugin/plugin.dart';

/**
 * Create and run an analysis server with Angular plugins.
 */
void main(List<String> args) {
  final starter = new ServerStarter();
  starter.userDefinedPlugins = <Plugin>[
    //new AngularAnalyzerPlugin(),
    //new AngularServerPlugin()
  ];
  final server = starter.start(args);

  ContextBuilder.onCreateAnalysisDriver = (analysisDriver,
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
    server.onFileAdded.listen((String path) {
      if (server.contextManager.getInnermostContextInfoFor(path).folder.path ==
          driverPath) {
        driver.addFile(path);
      }
    });
    server.onFileChanged.listen((String path) {
      if (server.contextManager.getInnermostContextInfoFor(path).folder.path ==
          driverPath) {
        driver.fileChanged(path);
      }
    });
  };
}
