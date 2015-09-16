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
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/tasks.dart';

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
  AngularWorkManager(this.context) {
    analysisCache.onResultInvalidated.listen((InvalidatedResult result) {
      if (result.descriptor == VIEWS_WITH_HTML_TEMPLATES) {
        List<View> views = result.value;
        for (View view in views) {
          _updateTemplateViews(view, false);
        }
      }
    });
  }

  /**
   * Returns the correctly typed result of `context.analysisCache`.
   */
  AnalysisCache get analysisCache => context.analysisCache;

  @override
  void applyChange(List<Source> addedSources, List<Source> changedSources,
      List<Source> removedSources) {
    for (Source source in addedSources) {
      if (_isHtmlSource(source)) {
        CacheEntry entry = context.getCacheEntry(source);
        entry.setValueIncremental(TEMPLATE_VIEWS, <View>[]);
      }
    }
  }

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
  void resultsComputed(AnalysisTarget target, Map outputs) {
    List<View> newViews = outputs[VIEWS_WITH_HTML_TEMPLATES];
    if (newViews != null) {
      for (View newView in newViews) {
        _updateTemplateViews(newView, true);
      }
    }
  }

  void _updateTemplateViews(View view, bool addView) {
    Source templateSource = view.templateSource;
    if (templateSource != null) {
      CacheEntry templateEntry = context.getCacheEntry(templateSource);
      // incrementally update the list of the template views
      List<View> templateViews = templateEntry.getValue(TEMPLATE_VIEWS);
      templateViews = templateViews.toList();
      if (addView) {
        templateViews.add(view);
      } else {
        templateViews.remove(view);
      }
      templateEntry.setValueIncremental(TEMPLATE_VIEWS, templateViews);
    }
  }

  /**
   * Return `true` if the given target is an HTML source.
   */
  static bool _isHtmlSource(AnalysisTarget target) {
    return target is Source && AnalysisEngine.isHtmlFileName(target.fullName);
  }
}
