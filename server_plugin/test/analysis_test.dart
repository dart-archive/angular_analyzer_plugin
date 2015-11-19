library angular2.src.analysis.server_plugin.analysis_test;

import 'dart:async';

import 'package:analysis_server/plugin/analysis/analysis_domain.dart';
import 'package:analysis_server/plugin/analysis/navigation/navigation_core.dart';
import 'package:analysis_server/plugin/analysis/occurrences/occurrences_core.dart';
import 'package:analysis_server/plugin/protocol/protocol.dart' as protocol;
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/src/context/context.dart' show AnalysisContextImpl;
import 'package:analyzer/src/generated/engine.dart'
    show AnalysisContext, AnalysisEngine, ComputedResult;
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/task/driver.dart';
import 'package:analyzer/src/task/manager.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/model.dart';
import 'package:angular2_analyzer_plugin/plugin.dart';
import 'package:angular2_analyzer_plugin/src/tasks.dart';
import 'package:angular2_server_plugin/src/analysis.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:typed_mock/typed_mock.dart';
import 'package:unittest/unittest.dart';

import 'mock_sdk.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(AnalysisDomainContributorTest);
  defineReflectiveTests(AngularNavigationContributorTest);
  defineReflectiveTests(AngularOccurrencesContributorTest);
}

class AnalysisContextMock extends TypedMock implements AnalysisContext {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

@reflectiveTest
class AnalysisDomainContributorTest {
  AnalysisDomainContributor contributor = new AnalysisDomainContributor();

  AnalysisContext analysisContext = new AnalysisContextMock();

  Source source1 = new SourceMock('/a.dart');
  AnalysisTarget target1 = new AnalysisTargetMock();

  StreamController<ComputedResult> dartTemplatesController =
      new StreamController<ComputedResult>.broadcast(sync: true);
  StreamController<ComputedResult> htmlTemplatesController =
      new StreamController<ComputedResult>.broadcast(sync: true);
  AnalysisDomain analysisDomain = new AnalysisDomainMock();

  void setUp() {
    when(target1.source).thenReturn(source1);
    // configure AnalysisDomain mock
    when(analysisDomain.onResultComputed(DART_TEMPLATES))
        .thenReturn(dartTemplatesController.stream);
    when(analysisDomain.onResultComputed(HTML_TEMPLATES))
        .thenReturn(htmlTemplatesController.stream);
    contributor.setAnalysisDomain(analysisDomain);
  }

  void test_onResult_htmlTemplates() {
    dartTemplatesController
        .add(new ComputedResult(analysisContext, HTML_TEMPLATES, target1, []));
    verify(analysisDomain.scheduleNotification(
            analysisContext, source1, protocol.AnalysisService.NAVIGATION))
        .times(1);
    verify(analysisDomain.scheduleNotification(
            analysisContext, source1, protocol.AnalysisService.OCCURRENCES))
        .times(1);
  }

  void test_setAnalysisDomain() {
    verify(analysisDomain.onResultComputed(DART_TEMPLATES)).times(1);
    verify(analysisDomain.onResultComputed(HTML_TEMPLATES)).times(1);
  }
}

class AnalysisDomainMock extends TypedMock implements AnalysisDomain {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AnalysisTargetMock extends TypedMock implements AnalysisTarget {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

@reflectiveTest
class AngularNavigationContributorTest extends _AbstractAngularTaskTest {
  String code;

  List<_RecordedNavigationRegion> regions = <_RecordedNavigationRegion>[];
  NavigationCollector collector = new NavigationCollectorMock();

  _RecordedNavigationRegion region;
  protocol.Location targetLocation;

  void setUp() {
    super.setUp();
    when(collector.addRegion(anyInt, anyInt, anyObject, anyObject)).thenInvoke(
        (int offset, int length, protocol.ElementKind targetKind,
            protocol.Location targetLocation) {
      regions.add(new _RecordedNavigationRegion(
          offset, length, targetKind, targetLocation));
    });
  }

  void test_dart_templates() {
    _addAngularSources();
    code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'text-panel', inputs: const ['text: my-text'])
@View(template: r"<div>some text</div>")
class TextPanel {
  String text; // 1
}

@Component(selector: 'UserPanel')
@View(template: r"""
<div>
  <text-panel [my-text]='user.name'></text-panel> // close
</div>
""", directives: [TextPanel])
class UserPanel {
  User user; // 2
}

class User {
  String name; // 3
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    // compute navigation regions
    new AngularNavigationContributor()
        .computeNavigation(collector, context, source, null, null);
    // input references setter
    {
      _findRegionString('text', ': my-text');
      expect(region.targetKind, protocol.ElementKind.SETTER);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf('text; // 1'));
    }
    // template references component (open tag)
    {
      _findRegionString('text-panel', ' [my-text]');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("text-panel', inputs"));
    }
    // template references component (close tag)
    {
      _findRegionString('text-panel', '> // close');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("text-panel', inputs"));
    }
    // template references input
    {
      _findRegionString('my-text', ']=');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("my-text'])"));
    }
    // template references field
    {
      _findRegionString('user', ".name'><");
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("user; // 2"));
    }
    // template references field
    {
      _findRegionString('name', "'><");
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, code.indexOf("name; // 3"));
    }
  }

  void test_dart_view_templateUrl() {
    _addAngularSources();
    code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'text-panel')
@View(templateUrl: 'text_panel.html')
class TextPanel {}
''';
    Source dartSource = newSource('/test.dart', code);
    Source htmlSource = newSource('/text_panel.html', "");
    // compute views, so that we have the TEMPLATE_VIEWS result
    {
      LibrarySpecificUnit target =
          new LibrarySpecificUnit(dartSource, dartSource);
      _computeResult(target, VIEWS_WITH_HTML_TEMPLATES);
    }
    // compute Angular templates
    _computeResult(htmlSource, HTML_TEMPLATES);
    // compute navigation regions
    new AngularNavigationContributor()
        .computeNavigation(collector, context, dartSource, null, null);
    // input references setter
    {
      _findRegionString("'text_panel.html'", ')');
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/text_panel.html');
      expect(targetLocation.offset, 0);
    }
  }

  void test_html_templates() {
    _addAngularSources();
    String dartCode = r'''
import '/angular2/metadata.dart';

@Component(selector: 'text-panel')
@View(templateUrl: 'text_panel.html')
class TextPanel {
  String text; // 1
}
''';
    String htmlCode = r"""
<div>
  {{text}}
</div>
""";
    Source dartSource = newSource('/test.dart', dartCode);
    Source htmlSource = newSource('/text_panel.html', htmlCode);
    // compute views, so that we have the TEMPLATE_VIEWS result
    {
      LibrarySpecificUnit target =
          new LibrarySpecificUnit(dartSource, dartSource);
      _computeResult(target, VIEWS_WITH_HTML_TEMPLATES);
    }
    // compute Angular templates
    _computeResult(htmlSource, HTML_TEMPLATES);
    // compute navigation regions
    new AngularNavigationContributor()
        .computeNavigation(collector, context, htmlSource, null, null);
    // template references field
    {
      _findRegionString('text', "}}", codeOverride: htmlCode);
      expect(region.targetKind, protocol.ElementKind.UNKNOWN);
      expect(targetLocation.file, '/test.dart');
      expect(targetLocation.offset, dartCode.indexOf("text; // 1"));
    }
  }

  void _findRegion(int offset, int length) {
    for (_RecordedNavigationRegion region in regions) {
      if (region.offset == offset && region.length == length) {
        this.region = region;
        this.targetLocation = region.targetLocation;
        return;
      }
    }
    String regionsString = regions.join('\n');
    fail('Unable to find a region at ($offset, $length) in $regionsString');
  }

  void _findRegionString(String str, String suffix, {String codeOverride}) {
    String code = codeOverride != null ? codeOverride : this.code;
    String search = str + suffix;
    int offset = code.indexOf(search);
    expect(offset, isNonNegative, reason: 'Cannot find |$search| in |$code|');
    _findRegion(offset, str.length);
  }
}

@reflectiveTest
class AngularOccurrencesContributorTest extends _AbstractAngularTaskTest {
  String code;

  OccurrencesCollector collector = new OccurrencesCollectorMock();
  List<protocol.Occurrences> occurrencesList = <protocol.Occurrences>[];

  protocol.Occurrences occurrences;

  void setUp() {
    super.setUp();
    when(collector.addOccurrences(anyObject)).thenInvoke(occurrencesList.add);
  }

  void test_dart_templates() {
    _addAngularSources();
    code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'text-panel', inputs: const ['text: my-text'])
@View(template: r"<div>some text</div>")
class TextPanel {
  String text; // 1
}

@Component(selector: 'UserPanel')
@View(template: r"""
<div>
  <text-panel [my-text]='user.value'></text-panel> // cl
</div>
""", directives: [TextPanel])
class UserPanel {
  ObjectContainer<String> user; // 2
}

class ObjectContainer<T> {
  T value; // 3
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    // compute navigation regions
    new AngularOccurrencesContributor()
        .computeOccurrences(collector, context, source);
    // "text" field
    {
      _findOccurrences(code.indexOf('text: my-text'));
      expect(occurrences.element.name, 'text');
      expect(occurrences.length, 'text'.length);
      expect(occurrences.offsets, contains(code.indexOf('text; // 1')));
    }
    // "text-panel" component
    {
      _findOccurrences(code.indexOf("text-panel', "));
      expect(occurrences.element.name, 'text-panel');
      expect(occurrences.length, 'text-panel'.length);
      expect(occurrences.offsets, contains(code.indexOf("text-panel [")));
      expect(occurrences.offsets, contains(code.indexOf("text-panel> // cl")));
    }
    // "user" field
    {
      _findOccurrences(code.indexOf("user.value'><"));
      expect(occurrences.element.name, 'user');
      expect(occurrences.length, 'user'.length);
      expect(occurrences.offsets, contains(code.indexOf('user; // 2')));
    }
    // "value" field
    {
      _findOccurrences(code.indexOf("value'><"));
      expect(occurrences.element.name, 'value');
      expect(occurrences.length, 'value'.length);
      expect(occurrences.offsets, contains(code.indexOf('value; // 3')));
    }
  }

  void _findOccurrences(int offset) {
    for (protocol.Occurrences occurrences in occurrencesList) {
      if (occurrences.offsets.contains(offset)) {
        this.occurrences = occurrences;
        return;
      }
    }
    String listStr = occurrencesList.join('\n');
    fail('Unable to find occurrences at $offset in $listStr');
  }
}

/**
 * Instances of the class [GatheringErrorListener] implement an error listener
 * that collects all of the errors passed to it for later examination.
 */
class GatheringErrorListener implements AnalysisErrorListener {
  /**
   * A list containing the errors that were collected.
   */
  List<AnalysisError> _errors = new List<AnalysisError>();

  @override
  void onError(AnalysisError error) {
    _errors.add(error);
  }
}

class NavigationCollectorMock extends TypedMock implements NavigationCollector {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class OccurrencesCollectorMock extends TypedMock
    implements OccurrencesCollector {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class SourceMock extends TypedMock implements Source {
  @override
  final String fullPath;

  SourceMock([String name = 'mocked.dart']) : fullPath = name;

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  String toString() => fullPath;
}

class _AbstractAngularTaskTest {
  MemoryResourceProvider resourceProvider = new MemoryResourceProvider();
  Source emptySource;

  DartSdk sdk = new MockSdk();
  AnalysisContextImpl context;

  TaskManager taskManager = new TaskManager();
  AnalysisDriver analysisDriver;

  AnalysisTask task;
  Map<ResultDescriptor<dynamic>, dynamic> outputs;
  GatheringErrorListener errorListener = new GatheringErrorListener();

  Source newSource(String path, [String content = '']) {
    File file = resourceProvider.newFile(path, content);
    return file.createSource();
  }

  void setUp() {
    AnalysisEngine.instance.userDefinedPlugins = [new AngularAnalyzerPlugin()];
    emptySource = newSource('/test.dart');
    // prepare AnalysisContext
    context = new AnalysisContextImpl();
    context.sourceFactory = new SourceFactory(<UriResolver>[
      new DartUriResolver(sdk),
      new ResourceUriResolver(resourceProvider)
    ]);
    // configure AnalysisDriver
    analysisDriver = context.driver;
  }

  void tearDown() {
    AnalysisEngine.instance.userDefinedPlugins = null;
  }

  void _addAngularSources() {
    newSource(
        '/angular2/angular2.dart',
        r'''
library angular2;

export 'async.dart';
export 'metadata.dart';
export 'ng_if.dart';
export 'ng_for.dart';
''');
    newSource(
        '/angular2/metadata.dart',
        r'''
library angular2.src.core.metadata;

import 'dart:async';

abstract class Directive {
  const Directive(
      {String selector,
      List<String> inputs,
      List<String> outputs,
      @Deprecated('Use `inputs` or `@Input` instead') List<String> properties,
      @Deprecated('Use `outputs` or `@Output` instead') List<String> events,
      Map<String, String> host,
      @Deprecated('Use `providers` instead') List bindings,
      List providers,
      String exportAs,
      String moduleId,
      Map<String, dynamic> queries})
      : super(
            selector: selector,
            inputs: inputs,
            outputs: outputs,
            properties: properties,
            events: events,
            host: host,
            bindings: bindings,
            providers: providers,
            exportAs: exportAs,
            moduleId: moduleId,
            queries: queries);
}

class Component extends Directive {
  const Component(
      {String selector,
      List<String> inputs,
      List<String> outputs,
      @Deprecated('Use `inputs` or `@Input` instead') List<String> properties,
      @Deprecated('Use `outputs` or `@Output` instead') List<String> events,
      Map<String, String> host,
      @Deprecated('Use `providers` instead') List bindings,
      List providers,
      String exportAs,
      String moduleId,
      Map<String, dynamic> queries,
      @Deprecated('Use `viewProviders` instead') List viewBindings,
      List viewProviders,
      ChangeDetectionStrategy changeDetection,
      String templateUrl,
      String template,
      dynamic directives,
      dynamic pipes,
      ViewEncapsulation encapsulation,
      List<String> styles,
      List<String> styleUrls});
}

class View {
  const View(
      {String templateUrl,
      String template,
      dynamic directives,
      dynamic pipes,
      ViewEncapsulation encapsulation,
      List<String> styles,
      List<String> styleUrls});
}

class Input {
  final String bindingPropertyName;
  const InputMetadata([this.bindingPropertyName]);
}

class Output {
  final String bindingPropertyName;
  const OutputMetadata([this.bindingPropertyName]);
}
''');
    newSource(
        '/angular2/async.dart',
        r'''
library angular2.core.facade.async;
import 'dart:async';

class EventEmitter<T> extends Stream<T> {
  StreamController<dynamic> _controller;

  /// Creates an instance of [EventEmitter], which depending on [isAsync],
  /// delivers events synchronously or asynchronously.
  EventEmitter([bool isAsync = true]) {
    _controller = new StreamController.broadcast(sync: !isAsync);
  }

  StreamSubscription listen(void onData(dynamic line),
      {void onError(Error error), void onDone(), bool cancelOnError}) {
    return _controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  void add(value) {
    _controller.add(value);
  }

  void addError(error) {
    _controller.addError(error);
  }

  void close() {
    _controller.close();
  }
}
''');
    newSource(
        '/angular2/ng_if.dart',
        r'''
library angular2.ng_if;
import 'metadata.dart';

@Directive(selector: "[ng-if]", inputs: const ["ngIf"])
class NgIf {
  set ngIf(newCondition) {}
}
''');
    newSource(
        '/angular2/ng_for.dart',
        r'''
library angular2.ng_for;
import 'metadata.dart';

@Directive(
    selector: "[ng-for][ng-for-of]",
    inputs: const ["ngForOf"])
class NgFor {
  set ngForOf(dynamic value) {}
}
''');
  }

  void _computeResult(AnalysisTarget target, ResultDescriptor result) {
    task = analysisDriver.computeResult(target, result);
    expect(task.caughtException, isNull);
    outputs = task.outputs;
  }
}

class _RecordedNavigationRegion {
  final int offset;
  final int length;
  final protocol.ElementKind targetKind;
  final protocol.Location targetLocation;

  _RecordedNavigationRegion(
      this.offset, this.length, this.targetKind, this.targetLocation);

  @override
  String toString() {
    return '$offset $length $targetKind $targetLocation';
  }
}
