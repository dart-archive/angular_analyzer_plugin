// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/starter.dart';

import 'package:angular_analyzer_plugin/starter.dart' as ng;
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

  //new ng.Starter().start(server);
}
