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
import 'package:analyzer/task/model.dart';
import 'package:angular2_analyzer_plugin/src/angular_work_manager.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:typed_mock/typed_mock.dart';
import 'package:unittest/unittest.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(AngularWorkManagerTest);
}

@reflectiveTest
class AngularWorkManagerTest {
  InternalAnalysisContext context = new _InternalAnalysisContextMock();
  AnalysisCache cache;
  AngularWorkManager manager;

  Source source1 = new _MockSource('1.dart');
  Source source2 = new _MockSource('2.dart');
  Source source3 = new _MockSource('3.dart');
  Source source4 = new _MockSource('4.dart');
  CacheEntry entry1;
  CacheEntry entry2;
  CacheEntry entry3;
  CacheEntry entry4;

  void setUp() {
    cache = context.analysisCache;
    manager = new AngularWorkManager(context);
    entry1 = context.getCacheEntry(source1);
    entry2 = context.getCacheEntry(source2);
    entry3 = context.getCacheEntry(source3);
    entry4 = context.getCacheEntry(source4);
  }

  void test_getNextResult_null() {
    TargetedResult nextResult = manager.getNextResult();
    expect(nextResult, isNull);
  }

  void test_getNextResultPriority_none() {
    WorkOrderPriority priority = manager.getNextResultPriority();
    expect(priority, WorkOrderPriority.NONE);
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

class _MockSource extends _StringTypedMock implements Source {
  _MockSource([String name = 'mocked.dart']) : super(name);
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StringTypedMock extends TypedMock {
  String _toString;

  _StringTypedMock(this._toString);

  @override
  String toString() {
    if (_toString != null) {
      return _toString;
    }
    return super.toString();
  }
}
