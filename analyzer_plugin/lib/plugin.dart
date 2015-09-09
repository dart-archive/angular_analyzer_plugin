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
    // tasks
    String taskId = TASK_EXTENSION_POINT_ID;
    registerExtension(taskId, AngularDartErrorsTask.DESCRIPTOR);
    registerExtension(taskId, BuildUnitDirectivesTask.DESCRIPTOR);
    registerExtension(taskId, BuildUnitViewsTask.DESCRIPTOR);
    registerExtension(taskId, ResolveDartTemplatesTask.DESCRIPTOR);
    // work manager
    registerExtension(WORK_MANAGER_EXTENSION_POINT_ID,
        (InternalAnalysisContext context) {
      return new AngularWorkManager(context);
    });
  }
}
