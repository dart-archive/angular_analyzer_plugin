library angular2.src.analysis.analyzer_plugin;

import 'package:plugin/plugin.dart';

/**
 * Contribute a plugin to the dart analyzer for analysis of
 * Angular 2 dart code.
 */
class AngularAnalyzerPlugin implements Plugin {
  /**
   * The unique identifier for this plugin.
   */
  static const String UNIQUE_IDENTIFIER = 'angular2.analysis.analyzer_plugin';

  @override
  String get uniqueIdentifier => UNIQUE_IDENTIFIER;

  @override
  void registerExtensionPoints(RegisterExtensionPoint registerExtensionPoint) {}

  @override
  void registerExtensions(RegisterExtension registerExtension) {
    // errors for Dart sources
  }
}
