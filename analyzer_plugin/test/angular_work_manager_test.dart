library angular2.src.analysis.analyzer_plugin.src.angular_work_manager_test;

import 'package:analyzer/src/context/cache.dart';
import 'package:analyzer/src/generated/engine.dart'
    show
        AnalysisErrorInfo,
        AnalysisErrorInfoImpl,
        CacheState,
        ChangeNoticeImpl,
        InternalAnalysisContext;
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/task/dart.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/model.dart';
import 'package:angular2_analyzer_plugin/src/angular_work_manager.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/tasks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:typed_mock/typed_mock.dart';
import 'package:unittest/unittest.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(AngularWorkManagerTest);
}

@reflectiveTest
class AngularWorkManagerTest {
  SourceFactory sourceFactory = new _SourceFactoryMock();
  InternalAnalysisContext context = new _InternalAnalysisContextMock();
  AnalysisCache cache;
  AngularWorkManager manager;

  Source source1 = new _SourceMock('1.html');
  Source source2 = new _SourceMock('2.html');
  Source source3 = new _SourceMock('3.html');
  Source source4 = new _SourceMock('4.html');
  Source dartSource1 = new _SourceMock('1.dart');
  Source dartSource2 = new _SourceMock('2.dart');
  CacheEntry entry1;
  CacheEntry entry2;
  CacheEntry entry3;
  CacheEntry entry4;
  CacheEntry dartEntry1;
  CacheEntry dartEntry2;
  CacheEntry dartUnitEntry1;
  CacheEntry dartUnitEntry2;

  void setUp() {
    when(context.sourceFactory).thenReturn(sourceFactory);
    cache = context.analysisCache;
    manager = new AngularWorkManager(context);
    when(dartSource1.exists()).thenReturn(true);
    when(dartSource2.exists()).thenReturn(true);
    entry1 = context.getCacheEntry(source1);
    entry2 = context.getCacheEntry(source2);
    entry3 = context.getCacheEntry(source3);
    entry4 = context.getCacheEntry(source4);
    dartEntry1 = context.getCacheEntry(dartSource1);
    dartEntry2 = context.getCacheEntry(dartSource2);
    dartUnitEntry1 = context
        .getCacheEntry(new LibrarySpecificUnit(dartSource1, dartSource1));
    dartUnitEntry2 = context
        .getCacheEntry(new LibrarySpecificUnit(dartSource2, dartSource2));
  }

  void test_applyChange_addHtml_emptyTemplateViews() {
    manager.applyChange(<Source>[source1], [], []);
    expect(entry1.getState(TEMPLATE_VIEWS), CacheState.VALID);
    expect(entry1.getValue(TEMPLATE_VIEWS), isEmpty);
  }

  void test_applyPriorityTargets_hasDart() {
    when(sourceFactory.resolveUri(source1, '1.dart')).thenReturn(dartSource1);
    manager.applyPriorityTargets(<Source>[source1]);
    expect(manager.priorityDartSourcesForKind, [dartSource1]);
  }

  void test_applyPriorityTargets_noDart() {
    manager.applyPriorityTargets(<Source>[source1]);
    expect(manager.priorityDartSourcesForKind, isEmpty);
  }

  void test_getNextResult_null() {
    TargetedResult nextResult = manager.getNextResult();
    expect(nextResult, isNull);
  }

  void test_getNextResult_priorityDartSourcesForKind() {
    manager.priorityDartSourcesForKind.add(dartSource1);
    TargetedResult nextResult = manager.getNextResult();
    expect(nextResult, new TargetedResult(dartSource1, SOURCE_KIND));
    expect(manager.priorityDartSourcesForKind, [dartSource1]);
  }

  void test_getNextResult_priorityDartSourcesForKind_alreadyComputed() {
    manager.priorityDartSourcesForKind.add(dartSource1);
    dartEntry1.setValue(SOURCE_KIND, SourceKind.LIBRARY, []);
    TargetedResult nextResult = manager.getNextResult();
    expect(nextResult, null);
    expect(manager.priorityDartSourcesForKind, isEmpty);
  }

  void test_getNextResult_priorityDartSourcesForViews() {
    manager.priorityDartSourcesForViews.add(dartSource1);
    TargetedResult nextResult = manager.getNextResult();
    expect(
        nextResult,
        new TargetedResult(new LibrarySpecificUnit(dartSource1, dartSource1),
            VIEWS_WITH_HTML_TEMPLATES));
    expect(manager.priorityDartSourcesForViews, [dartSource1]);
  }

  void test_getNextResult_priorityDartSourcesForViews_alreadyComputed() {
    manager.priorityDartSourcesForViews.add(dartSource1);
    dartUnitEntry1.setValue(VIEWS_WITH_HTML_TEMPLATES, [], []);
    TargetedResult nextResult = manager.getNextResult();
    expect(nextResult, null);
    expect(manager.priorityDartSourcesForKind, isEmpty);
  }

  void test_getNextResult_priorityHtmlSources() {
    manager.priorityHtmlSources.add(source1);
    TargetedResult nextResult = manager.getNextResult();
    expect(nextResult, new TargetedResult(source1, HTML_TEMPLATES));
    expect(manager.priorityHtmlSources, [source1]);
  }

  void test_getNextResult_priorityHtmlSources_alreadyComputed() {
    manager.priorityHtmlSources.add(source1);
    entry1.setValue(HTML_TEMPLATES, [], []);
    TargetedResult nextResult = manager.getNextResult();
    expect(nextResult, null);
    expect(manager.priorityHtmlSources, isEmpty);
  }

  void test_getNextResultPriority_none() {
    WorkOrderPriority priority = manager.getNextResultPriority();
    expect(priority, WorkOrderPriority.NONE);
  }

  void test_getNextResultPriority_priorityDartSourcesForKind() {
    manager.priorityDartSourcesForKind.add(dartSource1);
    WorkOrderPriority priority = manager.getNextResultPriority();
    expect(priority, WorkOrderPriority.PRIORITY);
  }

  void test_getNextResultPriority_priorityDartSourcesForViews() {
    manager.priorityDartSourcesForViews.add(dartSource1);
    WorkOrderPriority priority = manager.getNextResultPriority();
    expect(priority, WorkOrderPriority.PRIORITY);
  }

  void test_getNextResultPriority_priorityHtmlSources() {
    manager.priorityHtmlSources.add(source1);
    WorkOrderPriority priority = manager.getNextResultPriority();
    expect(priority, WorkOrderPriority.PRIORITY);
  }

  void test_resultsComputed_notSourceKind() {
    manager.priorityDartSourcesForKind.add(dartSource1);
    manager.resultsComputed(dartSource1, {SCAN_ERRORS: []});
    expect(manager.priorityDartSourcesForKind, [dartSource1]);
    expect(manager.priorityDartSourcesForViews, isEmpty);
  }

  void test_resultsComputed_sourceKind_forPriorityDartSource_library() {
    manager.priorityDartSourcesForKind.add(dartSource1);
    manager.resultsComputed(dartSource1, {SOURCE_KIND: SourceKind.LIBRARY});
    expect(manager.priorityDartSourcesForKind, isEmpty);
    expect(manager.priorityDartSourcesForViews, [dartSource1]);
  }

  void test_resultsComputed_sourceKind_forPriorityDartSource_notLibrary() {
    manager.priorityDartSourcesForKind.add(dartSource1);
    manager.resultsComputed(dartSource1, {SOURCE_KIND: SourceKind.PART});
    expect(manager.priorityDartSourcesForKind, isEmpty);
    expect(manager.priorityDartSourcesForViews, isEmpty);
  }

  void test_resultsComputed_sourceKind_notPriorityDartSource() {
    manager.priorityDartSourcesForKind.add(dartSource1);
    manager.resultsComputed(dartSource2, {SOURCE_KIND: SourceKind.LIBRARY});
    expect(manager.priorityDartSourcesForKind, [dartSource1]);
    expect(manager.priorityDartSourcesForViews, isEmpty);
  }

  void test_resultsComputed_viewsWithHtmlTemplates() {
    Source templateSource = source2;
    var view1 = new View(null, null, [], templateSource: templateSource);
    var view2 = new View(null, null, [], templateSource: templateSource);
    var view3 = new View(null, null, [], templateSource: templateSource);
    // no views for "source2"
    expect(cache.getValue(templateSource, TEMPLATE_VIEWS), isEmpty);
    // add "view1"
    manager.resultsComputed(source1, {
      VIEWS_WITH_HTML_TEMPLATES: [view1]
    });
    expect(cache.getValue(templateSource, TEMPLATE_VIEWS),
        unorderedEquals([view1]));
    // add "view2" from "source3"
    entry3.setValue(VIEWS_WITH_HTML_TEMPLATES, [view2], []);
    manager.resultsComputed(source3, {
      VIEWS_WITH_HTML_TEMPLATES: [view2]
    });
    expect(cache.getValue(templateSource, TEMPLATE_VIEWS),
        unorderedEquals([view1, view2]));
    // add "view3"
    manager.resultsComputed(source1, {
      VIEWS_WITH_HTML_TEMPLATES: [view3]
    });
    expect(cache.getValue(templateSource, TEMPLATE_VIEWS),
        unorderedEquals([view1, view2, view3]));
    // invalidate [view2]
    entry3.setState(VIEWS_WITH_HTML_TEMPLATES, CacheState.INVALID);
    expect(cache.getValue(templateSource, TEMPLATE_VIEWS),
        unorderedEquals([view1, view3]));
  }
}

class _InternalAnalysisContextMock extends TypedMock
    implements InternalAnalysisContext {
  @override
  CachePartition privateAnalysisCachePartition;

  @override
  AnalysisCache analysisCache;

  _InternalAnalysisContextMock() {
    privateAnalysisCachePartition = new UniversalCachePartition(this);
    analysisCache = new AnalysisCache([privateAnalysisCachePartition]);
  }

  @override
  CacheEntry getCacheEntry(AnalysisTarget target) {
    CacheEntry entry = analysisCache.get(target);
    if (entry == null) {
      entry = new CacheEntry(target);
      analysisCache.put(entry);
    }
    return entry;
  }

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SourceFactoryMock extends TypedMock implements SourceFactory {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SourceMock extends TypedMock implements Source {
  final String shortName;
  _SourceMock(this.shortName);
  @override
  String get fullName => '/' + shortName;
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  String toString() => fullName;
}
