library angular2.src.analysis.analyzer_plugin.src.angular_work_manager;

import 'dart:collection';

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
import 'package:angular2_analyzer_plugin/tasks.dart';
import 'package:analyzer/task/dart.dart';

/**
 * The manager for Angular specific analysis.
 */
class AngularWorkManager implements WorkManager {
  /**
   * The context for which work is being managed.
   */
  final InternalAnalysisContext context;

  /**
   * The Dart sources with resolved units.
   */
  final LinkedHashSet<LibrarySpecificUnit> dartUnitQueue =
      new LinkedHashSet<LibrarySpecificUnit>();

  /**
   * Initialize a newly created manager.
   */
  AngularWorkManager(this.context) {
    analysisCache.onResultInvalidated.listen((InvalidatedResult result) {
      if (result.descriptor == RESOLVED_UNIT) {
        dartUnitQueue.remove(result.entry.target);
      }
    });
  }

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
    // TODO: implement getErrors
    return AnalysisError.NO_ERRORS;
  }

  @override
  TargetedResult getNextResult() {
    // Try to find a new target to analyze.
    while (dartUnitQueue.isNotEmpty) {
      LibrarySpecificUnit target = dartUnitQueue.first;
      // Maybe done with this target.
      if (!_needsComputing(target, ANGULAR_DART_ERRORS)) {
        dartUnitQueue.remove(target);
        continue;
      }
      // Analyze this target.
      return new TargetedResult(target, ANGULAR_DART_ERRORS);
    }
    // No results to compute.
    return null;
  }

  @override
  WorkOrderPriority getNextResultPriority() {
    if (dartUnitQueue.isNotEmpty) {
      return WorkOrderPriority.NORMAL;
    }
    return WorkOrderPriority.NONE;
  }

  @override
  void onAnalysisOptionsChanged() {}

  @override
  void onSourceFactoryChanged() {}

  @override
  void resultsComputed(AnalysisTarget target, Map outputs) {
    if (target is LibrarySpecificUnit) {
      if (outputs.containsKey(RESOLVED_UNIT)) {
        dartUnitQueue.add(target);
      }
    }
  }

  /**
   * Returns `true` if the given [result] of the given [target] needs
   * computing, i.e. it is not in the valid and not in the error state.
   */
  bool _needsComputing(AnalysisTarget target, ResultDescriptor result) {
    CacheState state = analysisCache.getState(target, result);
    return state != CacheState.VALID && state != CacheState.ERROR;
  }
}
