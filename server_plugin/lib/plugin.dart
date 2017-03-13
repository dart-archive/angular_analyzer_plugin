library angular2.src.analysis.server_plugin;

import 'package:analysis_server/plugin/analysis/analysis_domain.dart';
import 'package:analysis_server/plugin/analysis/navigation/navigation.dart';
import 'package:analysis_server/plugin/analysis/occurrences/occurrences.dart';
import 'package:analysis_server/src/provisional/completion/completion.dart';
import 'package:angular_analyzer_server_plugin/src/analysis.dart';
import 'package:angular_analyzer_server_plugin/src/completion.dart';
import 'package:plugin/plugin.dart';

/**
 * Contribute a plugin for services such as completions, indexing and refactoring
 * of Angular 2 dart code.
 */
class AngularServerPlugin implements Plugin {
  /**
   * The unique identifier for this plugin.
   */
  static const String UNIQUE_IDENTIFIER = 'angular2.analysis.server_plugin';

  @override
  String get uniqueIdentifier => UNIQUE_IDENTIFIER;

  @override
  void registerExtensionPoints(RegisterExtensionPoint registerExtensionPoint) {}

  @override
  void registerExtensions(RegisterExtension registerExtension) {
    //registerExtension(SET_ANALYSIS_DOMAIN_EXTENSION_POINT_ID,
    //    new AnalysisDomainContributor().setAnalysisDomain);
    //registerExtension(NAVIGATION_CONTRIBUTOR_EXTENSION_POINT_ID,
    //    new AngularNavigationContributor());
    //registerExtension(OCCURRENCES_CONTRIBUTOR_EXTENSION_POINT_ID,
    //    new AngularOccurrencesContributor());
    registerExtension(COMPLETION_CONTRIBUTOR_EXTENSION_POINT_ID,
        () => new AngularTemplateCompletionContributor());
    registerExtension(COMPLETION_CONTRIBUTOR_EXTENSION_POINT_ID,
        () => new AngularDartCompletionContributor());
  }
}
