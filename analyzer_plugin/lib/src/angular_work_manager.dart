library angular2.src.analysis.analyzer_plugin.src.angular_work_manager;

import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/context/cache.dart';
import 'package:analyzer/src/generated/engine.dart'
    show AnalysisEngine, CacheState, InternalAnalysisContext;
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/model.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/tasks.dart';
import 'package:path/path.dart' as pathos;

/**
 * The manager for Angular specific analysis.
 */
class AngularWorkManager implements WorkManager {
  /**
   * The context for which work is being managed.
   */
  final InternalAnalysisContext context;

  /**
   * The list of Dart sources for which we want to check whether they are
   * libraries and resolve them to be able to resolve [priorityHtmlSources].
   */
  final List<Source> priorityDartSourcesForKind = <Source>[];

  /**
   * The list of Dart sources for which we want to compute
   * [VIEWS_WITH_HTML_TEMPLATES] to be able to resolve [priorityHtmlSources].
   */
  final List<Source> priorityDartSourcesForViews = <Source>[];

  /**
   * The list of priority HTML sources to resolve as templates.
   */
  final List<Source> priorityHtmlSources = <Source>[];

  /**
   * Initialize a newly created manager.
   */
  AngularWorkManager(this.context) {
    context.onResultInvalidated.listen((InvalidatedResult result) {
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
        entry.setState(TEMPLATE_VIEWS, CacheState.INVALID);
        entry.setValue(TEMPLATE_VIEWS, <View>[], []);
      }
    }
  }

  @override
  void applyPriorityTargets(List<AnalysisTarget> targets) {
    priorityDartSourcesForKind.clear();
    priorityDartSourcesForViews.clear();
    priorityHtmlSources.clear();
    for (AnalysisTarget target in targets) {
      if (_isHtmlSource(target)) {
        Source htmlSource = target;
        priorityHtmlSources.add(htmlSource);
        // Try to find the corresponding Dart source and schedule its analysis.
        Source dartSource = context.sourceFactory.resolveUri(htmlSource,
            pathos.withoutExtension(htmlSource.shortName) + '.dart');
        if (dartSource != null && dartSource.exists()) {
          priorityDartSourcesForKind.add(dartSource);
          priorityHtmlSources.add(htmlSource);
        }
      }
    }
  }

  @override
  List<AnalysisError> getErrors(Source source) {
    return AnalysisError.NO_ERRORS;
  }

  @override
  TargetedResult getNextResult() {
    // Request SOURCE_KIND computing.
    while (priorityDartSourcesForKind.isNotEmpty) {
      Source source = priorityDartSourcesForKind.last;
      if (!_needsComputing(source, SOURCE_KIND)) {
        priorityDartSourcesForKind.removeLast();
        continue;
      }
      return new TargetedResult(source, SOURCE_KIND);
    }
    // Request VIEWS_WITH_HTML_TEMPLATES computing.
    while (priorityDartSourcesForViews.isNotEmpty) {
      Source source = priorityDartSourcesForViews.last;
      LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
      if (!_needsComputing(target, VIEWS_WITH_HTML_TEMPLATES)) {
        priorityDartSourcesForViews.removeLast();
        continue;
      }
      return new TargetedResult(target, VIEWS_WITH_HTML_TEMPLATES);
    }
    // Request HTML_TEMPLATES computing.
    while (priorityHtmlSources.isNotEmpty) {
      Source source = priorityHtmlSources.last;
      if (!_needsComputing(source, HTML_TEMPLATES)) {
        priorityHtmlSources.removeLast();
        continue;
      }
      return new TargetedResult(source, HTML_TEMPLATES);
    }
    // No results to compute.
    return null;
  }

  @override
  WorkOrderPriority getNextResultPriority() {
    if (priorityDartSourcesForKind.isNotEmpty ||
        priorityDartSourcesForViews.isNotEmpty ||
        priorityHtmlSources.isNotEmpty) {
      return WorkOrderPriority.PRIORITY;
    }
    return WorkOrderPriority.NONE;
  }

  @override
  void onAnalysisOptionsChanged() {}

  @override
  void onSourceFactoryChanged() {}

  @override
  void resultsComputed(AnalysisTarget target, Map outputs) {
    // Schedule priority views computing.
    {
      SourceKind sourceKind = outputs[SOURCE_KIND];
      if (sourceKind != null && priorityDartSourcesForKind.remove(target)) {
        if (sourceKind == SourceKind.LIBRARY) {
          priorityDartSourcesForViews.add(target);
        }
      }
    }
    // Update views containing templates.
    {
      List<View> newViews = outputs[VIEWS_WITH_HTML_TEMPLATES];
      if (newViews != null) {
        for (View newView in newViews) {
          _updateTemplateViews(newView, true);
        }
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

  void _updateTemplateViews(View view, bool addView) {
    Source templateUriSource = view.templateUriSource;
    if (templateUriSource != null) {
      CacheEntry templateEntry = context.getCacheEntry(templateUriSource);
      // incrementally update the list of the template views
      List<View> templateViews = templateEntry.getValue(TEMPLATE_VIEWS);
      templateViews = templateViews.toList();
      if (addView) {
        templateViews.add(view);
      } else {
        templateViews.remove(view);
      }
      templateEntry.setState(TEMPLATE_VIEWS, CacheState.INVALID);
      // We ask for the cache entry again, because it may have been removed
      // from the cache after the setState() invocation above. This happens
      // when the entry is implicit and has no results.
      context
          .getCacheEntry(templateUriSource)
          .setValue(TEMPLATE_VIEWS, templateViews, []);
    }
  }

  /**
   * Return `true` if the given [target] is an HTML source.
   */
  static bool _isHtmlSource(AnalysisTarget target) {
    return target is Source && AnalysisEngine.isHtmlFileName(target.fullName);
  }
}
