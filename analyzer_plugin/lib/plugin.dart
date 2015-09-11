library angular2.src.analysis.analyzer_plugin;

import 'package:analyzer/plugin/task.dart';
import 'package:analyzer/src/generated/engine.dart'
    show InternalAnalysisContext;
import 'package:angular2_analyzer_plugin/src/angular_work_manager.dart';
import 'package:plugin/plugin.dart';

import 'src/tasks.dart';

/// Contribute a plugin to the dart analyzer for analysis of
/// Angular 2 dart code.
class AngularAnalyzerPlugin implements Plugin {
  /// The unique identifier for this plugin.
  static const String UNIQUE_IDENTIFIER = 'angular2.analysis.analyzer_plugin';

  @override
  String get uniqueIdentifier => UNIQUE_IDENTIFIER;

  @override
  void registerExtensionPoints(RegisterExtensionPoint registerExtensionPoint) {}

  @override
  void registerExtensions(RegisterExtension registerExtension) {
    // errors for Dart sources
    {
      String id = DART_ERRORS_FOR_UNIT_EXTENSION_POINT_ID;
      registerExtension(id, DIRECTIVES_ERRORS);
      registerExtension(id, VIEWS_ERRORS);
      registerExtension(id, DART_TEMPLATES_ERRORS);
    }
    // tasks
    {
      String id = TASK_EXTENSION_POINT_ID;
      registerExtension(id, BuildUnitDirectivesTask.DESCRIPTOR);
      registerExtension(id, BuildUnitViewsTask.DESCRIPTOR);
      registerExtension(id, ResolveDartTemplatesTask.DESCRIPTOR);
      registerExtension(id, ResolveHtmlTemplateTask.DESCRIPTOR);
      registerExtension(id, ResolveViewsTask.DESCRIPTOR);
    }
    // work manager
    registerExtension(WORK_MANAGER_EXTENSION_POINT_ID,
        (InternalAnalysisContext context) {
      return new AngularWorkManager(context);
    });
  }
}
