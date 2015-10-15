library angular2.src.analysis.analyzer_plugin.src.angular_base;

import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/src/context/context.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart'
    show AnalysisEngine, ChangeSet;
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/sdk.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/task/driver.dart';
import 'package:analyzer/src/task/manager.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/model.dart';
import 'package:angular2_analyzer_plugin/plugin.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/selector.dart';
import 'package:angular2_analyzer_plugin/src/tasks.dart';
import 'package:unittest/unittest.dart';

import 'mock_sdk.dart';

void assertComponentReference(
    ResolvedRange resolvedRange, Component component) {
  ElementNameSelector selector = component.selector;
  AngularElement element = resolvedRange.element;
  expect(element, selector.nameElement);
  expect(resolvedRange.range.length, selector.nameElement.name.length);
}

PropertyAccessorElement assertGetter(ResolvedRange resolvedRange) {
  PropertyAccessorElement element =
      (resolvedRange.element as DartElement).element;
  expect(element.isGetter, isTrue);
  return element;
}

MethodElement assertMethod(ResolvedRange resolvedRange) {
  AngularElement element = resolvedRange.element;
  expect(element, new isInstanceOf<DartElement>());
  Element dartElement = (element as DartElement).element;
  expect(dartElement, new isInstanceOf<MethodElement>());
  return dartElement;
}

void assertPropertyReference(
    ResolvedRange resolvedRange, AbstractDirective directive, String name) {
  var element = resolvedRange.element;
  for (PropertyElement property in directive.properties) {
    if (property.name == name) {
      expect(element, same(property));
      return;
    }
  }
  fail('Expected property "$name", but ${element} found.');
}

PropertyAccessorElement assertSetter(ResolvedRange resolvedRange) {
  PropertyAccessorElement element =
      (resolvedRange.element as DartElement).element;
  expect(element.isSetter, isTrue);
  return element;
}

Component getComponentByClassName(
    List<AbstractDirective> directives, String className) {
  return getDirectiveByClassName(directives, className);
}

AbstractDirective getDirectiveByClassName(
    List<AbstractDirective> directives, String className) {
  return directives.firstWhere(
      (directive) => directive.classElement.name == className, orElse: () {
    fail('DirectiveMetadata with the class "$className" was not found.');
    return null;
  });
}

ResolvedRange getResolvedRangeAtString(
    String code, List<ResolvedRange> ranges, String str) {
  int offset = code.indexOf(str);
  return ranges.firstWhere((_) => _.range.offset == offset, orElse: () {
    fail('ResolvedRange at $offset was not found in [\n${ranges.join('\n')}]');
    return null;
  });
}

View getViewByClassName(List<View> views, String className) {
  return views.firstWhere((view) => view.classElement.name == className,
      orElse: () {
    fail('View with the class "$className" was not found.');
    return null;
  });
}

class AbstractAngularTest {
  MemoryResourceProvider resourceProvider = new MemoryResourceProvider();

  DartSdk sdk = new MockSdk();
  AnalysisContextImpl context;

  TaskManager taskManager = new TaskManager();
  AnalysisDriver analysisDriver;

  AnalysisTask task;
  Map<ResultDescriptor<dynamic>, dynamic> outputs;
  GatheringErrorListener errorListener = new GatheringErrorListener();

  List<AbstractDirective> computeLibraryDirectives(Source dartSource) {
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, DIRECTIVES);
    return outputs[DIRECTIVES];
  }

  List<View> computeLibraryViews(Source dartSource) {
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS_WITH_HTML_TEMPLATES);
    return outputs[VIEWS_WITH_HTML_TEMPLATES];
  }

  void computeResult(AnalysisTarget target, ResultDescriptor result) {
    task = analysisDriver.computeResult(target, result);
    expect(task.caughtException, isNull);
    outputs = task.outputs;
  }

  /**
   * Fill [errorListener] with [result] errors in the current [task].
   */
  void fillErrorListener(ResultDescriptor<List<AnalysisError>> result) {
    List<AnalysisError> errors = task.outputs[result];
    expect(errors, isNotNull, reason: result.name);
    errorListener = new GatheringErrorListener();
    errorListener.addAll(errors);
  }

  Source newSource(String path, [String content = '']) {
    File file = resourceProvider.newFile(path, content);
    return file.createSource();
  }

  void setUp() {
    _addAngularSources();
    AnalysisEngine.instance.userDefinedPlugins = [new AngularAnalyzerPlugin()];
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
  final String selector;
  final dynamic properties;
  final dynamic hostListeners;
  final List lifecycle;
  const Directive({selector, properties, hostListeners, lifecycle})
  : selector = selector,
    properties = properties,
    hostListeners = hostListeners,
    lifecycle = lifecycle,
    super();
}

class Component extends Directive {
  final String changeDetection;
  final List injectables;
  const Component({selector, properties, events, hostListeners,
      injectables, lifecycle, changeDetection: 'DEFAULT'})
      : changeDetection = changeDetection,
        injectables = injectables,
        super(
            selector: selector,
            properties: properties,
            events: events,
            hostListeners: hostListeners,
            lifecycle: lifecycle);
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

class EventEmitter extends Stream {
}
''');
    newSource(
        '/angular2/ng_if.dart',
        r'''
library angular2.ng_if;
import 'metadata.dart';

@Directive(selector: "[ng-if]", properties: const ["ngIf"])
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
    properties: const ["ngForOf"])
class NgFor {
  set ngForOf(dynamic value) {}
}
''');
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

  /**
   * Add all of the given errors to this listener.
   */
  void addAll(List<AnalysisError> errors) {
    for (AnalysisError error in errors) {
      onError(error);
    }
  }

  /**
   * Assert that the number of errors that have been gathered matches the number
   * of errors that are given and that they have the expected error codes. The
   * order in which the errors were gathered is ignored.
   */
  void assertErrorsWithCodes(
      [List<ErrorCode> expectedErrorCodes = ErrorCode.EMPTY_LIST]) {
    StringBuffer buffer = new StringBuffer();
    //
    // Verify that the expected error codes have a non-empty message.
    //
    for (ErrorCode errorCode in expectedErrorCodes) {
      expect(errorCode.message.isEmpty, isFalse,
          reason: "Empty error code message");
    }
    //
    // Compute the expected number of each type of error.
    //
    Map<ErrorCode, int> expectedCounts = <ErrorCode, int>{};
    for (ErrorCode code in expectedErrorCodes) {
      int count = expectedCounts[code];
      if (count == null) {
        count = 1;
      } else {
        count = count + 1;
      }
      expectedCounts[code] = count;
    }
    //
    // Compute the actual number of each type of error.
    //
    Map<ErrorCode, List<AnalysisError>> errorsByCode =
        <ErrorCode, List<AnalysisError>>{};
    for (AnalysisError error in _errors) {
      ErrorCode code = error.errorCode;
      List<AnalysisError> list = errorsByCode[code];
      if (list == null) {
        list = new List<AnalysisError>();
        errorsByCode[code] = list;
      }
      list.add(error);
    }
    //
    // Compare the expected and actual number of each type of error.
    //
    expectedCounts.forEach((ErrorCode code, int expectedCount) {
      int actualCount;
      List<AnalysisError> list = errorsByCode.remove(code);
      if (list == null) {
        actualCount = 0;
      } else {
        actualCount = list.length;
      }
      if (actualCount != expectedCount) {
        if (buffer.length == 0) {
          buffer.write("Expected ");
        } else {
          buffer.write("; ");
        }
        buffer.write(expectedCount);
        buffer.write(" errors of type ");
        buffer.write(code.uniqueName);
        buffer.write(", found ");
        buffer.write(actualCount);
      }
    });
    //
    // Check that there are no more errors in the actual-errors map,
    // otherwise record message.
    //
    errorsByCode.forEach((ErrorCode code, List<AnalysisError> actualErrors) {
      int actualCount = actualErrors.length;
      if (buffer.length == 0) {
        buffer.write("Expected ");
      } else {
        buffer.write("; ");
      }
      buffer.write("0 errors of type ");
      buffer.write(code.uniqueName);
      buffer.write(", found ");
      buffer.write(actualCount);
      buffer.write(" (");
      for (int i = 0; i < actualErrors.length; i++) {
        AnalysisError error = actualErrors[i];
        if (i > 0) {
          buffer.write(", ");
        }
        buffer.write(error.offset);
      }
      buffer.write(")");
    });
    if (buffer.length > 0) {
      fail(buffer.toString());
    }
  }

  /**
   * Assert that no errors have been gathered.
   */
  void assertNoErrors() {
    assertErrorsWithCodes();
  }

  @override
  void onError(AnalysisError error) {
    _errors.add(error);
  }
}
