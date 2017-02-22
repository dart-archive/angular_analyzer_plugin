// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/starter.dart';

import 'package:analysis_server/src/analysis_server.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:analyzer/src/context/builder.dart';

/**
 * Create and run an analysis server with Angular plugins.
 */
void main(List<String> args) {
  AnalysisServer.onCreate = (AnalysisServer server) {
    ContextBuilder.onCreateAnalysisDriver = (analysisDriver,
        scheduler,
        logger,
        resourceProvider,
        byteStore,
        contentOverlay,
        sourceFactory,
        analysisOptions) {
      final AngularDriver driver = new AngularDriver(
          server, analysisDriver, scheduler, byteStore, sourceFactory);
      AnalysisServer.onFileAdd = (String path) {
        driver.addFile(path);
      };
      AnalysisServer.onFileChange = (String path) {
        driver.fileChanged(path);
      };
    };
  };

  final ServerStarter starter = new ServerStarter();
  starter.start(args);
}
