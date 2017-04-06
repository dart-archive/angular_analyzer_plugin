// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/starter.dart';

import 'package:angular_analyzer_plugin/src/angular_driver.dart';
import 'package:analyzer/src/context/builder.dart';
//import 'package:angular_analyzer_server_plugin/plugin.dart';
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

  final angularDrivers = <AngularDriver>[];
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
  };

  server.onResultErrorSupplementor = (path, errors) {
    for (final driver in angularDrivers) {
      driver
          .requestDartErrors(path)
          .then((angularErrors) => errors.addAll(angularErrors));
    }
  };
}
