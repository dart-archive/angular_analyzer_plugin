// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/starter.dart';

import 'package:angular_analyzer_server_plugin/starter.dart' as ng;

/// Create and run an analysis server with Angular plugins.
void main(List<String> args) {
  final starter = new ServerStarter();
  final server = starter.start(args);

  new ng.Starter().start(server);
}
