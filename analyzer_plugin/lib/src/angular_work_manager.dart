library angular2.src.analysis.analyzer_plugin.src.angular_work_manager;

import 'package:analyzer/src/context/cache.dart';
import 'package:analyzer/src/generated/engine.dart'
    show
        AnalysisEngine,
        AnalysisErrorInfo,
        AnalysisErrorInfoImpl,
        AnalysisOptions,
        CacheState,
        InternalAnalysisContext;
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/task/model.dart';

/**
 * The manager for Angular specific analysis.
 */
class AngularWorkManager implements WorkManager {
  /**
   * The context for which work is being managed.
   */
  final InternalAnalysisContext context;

  /**
   * Initialize a newly created manager.
   */
  AngularWorkManager(this.context);

  /**
   * Returns the correctly typed result of `context.analysisCache`.
   */
  AnalysisCache get analysisCache => context.analysisCache;

  @override
  void applyChange(List<Source> addedSources, List<Source> changedSources,
      List<Source> removedSources) {}

  @override
  void applyPriorityTargets(List<AnalysisTarget> targets) {}

  @override
  List<AnalysisError> getErrors(Source source) {
    return AnalysisError.NO_ERRORS;
  }

  @override
  TargetedResult getNextResult() {
    return null;
  }

  @override
  WorkOrderPriority getNextResultPriority() {
    return WorkOrderPriority.NONE;
  }

  @override
  void onAnalysisOptionsChanged() {}

  @override
  void onSourceFactoryChanged() {}

  @override
  void resultsComputed(AnalysisTarget target, Map outputs) {}
}
