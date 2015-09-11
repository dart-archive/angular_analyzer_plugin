library angular2.src.analysis.analyzer_plugin.src.tasks_test;

import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer/file_system/memory_file_system.dart';
import 'package:analyzer/src/context/cache.dart';
import 'package:analyzer/src/context/context.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisEngine;
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
import 'package:angular2_analyzer_plugin/tasks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';

import 'mock_sdk.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(BuildUnitDirectivesTaskTest);
  defineReflectiveTests(BuildUnitViewsTaskTest);
  defineReflectiveTests(ResolveDartTemplatesTaskTest);
}

Component _getComponentByClassName(
    List<AbstractDirective> directives, String className) {
  return _getDirectiveByClassName(directives, className);
}

AbstractDirective _getDirectiveByClassName(
    List<AbstractDirective> directives, String className) {
  return directives.firstWhere(
      (directive) => directive.classElement.name == className, orElse: () {
    fail('DirectiveMetadata with the class "$className" was not found.');
    return null;
  });
}

View _getViewByClassName(List<View> views, String className) {
  return views.firstWhere((view) => view.classElement.name == className,
      orElse: () {
    fail('View with the class "$className" was not found.');
    return null;
  });
}

@reflectiveTest
class BuildUnitDirectivesTaskTest extends _AbstractDartTaskTest {
  void test_Component() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
import '/angular2/metadata.dart';

@Component(selector: 'comp-a')
class ComponentA {
}

@Component(selector: 'comp-b')
class ComponentB {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DIRECTIVES);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES];
    expect(directives, hasLength(2));
    {
      Component component = directives[0];
      expect(component, new isInstanceOf<Component>());
      {
        Selector selector = component.selector;
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-a');
      }
    }
    {
      Component component = directives[1];
      expect(component, new isInstanceOf<Component>());
      {
        Selector selector = component.selector;
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-b');
      }
    }
  }

  void test_Directive() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
import '/angular2/metadata.dart';

@Directive(selector: 'dir-a')
class DirectiveA {
}

@Directive(selector: 'dir-b')
class DirectiveB {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DIRECTIVES);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES];
    expect(directives, hasLength(2));
    {
      AbstractDirective directive = directives[0];
      expect(directive, new isInstanceOf<Directive>());
      {
        Selector selector = directive.selector;
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-a');
      }
    }
    {
      AbstractDirective directive = directives[1];
      expect(directive, new isInstanceOf<Directive>());
      {
        Selector selector = directive.selector;
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-b');
      }
    }
  }

  void test_hasError_ArgumentSelectorMissing() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
import '/angular2/metadata.dart';

@Component()
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DIRECTIVES);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    _fillErrorListener(DIRECTIVES_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.ARGUMENT_SELECTOR_MISSING]);
  }

  void test_hasError_CannotParseSelector() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
import '/angular2/metadata.dart';

@Component(selector: '+bad')
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DIRECTIVES);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    _fillErrorListener(DIRECTIVES_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.CANNOT_PARSE_SELECTOR]);
  }

  void test_hasError_notStringValue() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
import '/angular2/metadata.dart';

@Component(selector: 'comp' + '-a')
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DIRECTIVES);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    _fillErrorListener(DIRECTIVES_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.STRING_VALUE_EXPECTED]);
  }

  void test_noDirectives() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
class A {}
class B {}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DIRECTIVES);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES];
    expect(directives, isEmpty);
  }

  void test_properties_OK() {
    _addAngularSources();
    String code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'my-component', properties: const ['aaa', 'bbb: myBbb'])
class MyComponent {
  int aaa;
  String bbb;
}
''';
    Source source = _newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DIRECTIVES);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES];
    Component component = directives.single;
    List<PropertyElement> properties = component.properties;
    expect(properties, hasLength(2));
    {
      PropertyElement property = properties[0];
      expect(property.name, 'aaa');
      expect(property.nameOffset, code.indexOf("aaa',"));
      expect(property.setterRange.offset, property.nameOffset);
      expect(property.setterRange.length, 'aaa'.length);
      expect(property.setter, isNotNull);
      expect(property.setter.isSetter, isTrue);
      expect(property.setter.displayName, 'aaa');
    }
    {
      PropertyElement property = properties[1];
      expect(property.name, 'myBbb');
      expect(property.nameOffset, code.indexOf("myBbb']"));
      expect(property.setterRange.offset, code.indexOf("bbb: "));
      expect(property.setterRange.length, 'bbb'.length);
      expect(property.setter, isNotNull);
      expect(property.setter.isSetter, isTrue);
      expect(property.setter.displayName, 'bbb');
    }
  }
}

@reflectiveTest
class BuildUnitViewsTaskTest extends _AbstractDartTaskTest {
  void test_hasError_ComponentAnnotationMissing() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
import '/angular2/metadata.dart';

@View(template: 'AAA')
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    _fillErrorListener(VIEWS_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.COMPONENT_ANNOTATION_MISSING]);
  }

  void test_hasError_DirectiveTypeLiteralExpected() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
import '/angular2/metadata.dart';

@Component(selector: 'aaa')
@View(template: 'AAA', directives: [int])
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    _fillErrorListener(VIEWS_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.DIRECTIVE_TYPE_LITERAL_EXPECTED]);
  }

  void test_hasError_StringValueExpected() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
import '/angular2/metadata.dart';

@Component(selector: 'aaa')
@View(template: 'bad' + 'template')
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    _fillErrorListener(VIEWS_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.STRING_VALUE_EXPECTED]);
  }

  void test_hasError_TypeLiteralExpected() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
import '/angular2/metadata.dart';

@Component(selector: 'aaa')
@View(template: 'AAA', directives: [42])
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    _fillErrorListener(VIEWS_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TYPE_LITERAL_EXPECTED]);
  }

  void test_hasTemplate() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
import '/angular2/metadata.dart';

@Component(selector: 'compA')
@View(template: 'AAA')
class ComponentA {
}

@Directive(selector: 'dirA')
class DirectiveA {
}

@Component(selector: 'compB')
@View(templateUrl: 'compB.html', directives: [ComponentA, DirectiveA])
class ComponentB {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    List<AbstractDirective> directives =
        context.analysisCache.getValue(target, DIRECTIVES);
    // validate
    List<View> views = outputs[VIEWS];
    expect(views, hasLength(2));
    {
      View view = _getViewByClassName(views, 'ComponentA');
      expect(view.templateText, 'AAA');
      expect(view.templateUrl, isNull);
      expect(view.directives, isEmpty);
      expect(
          view.component, _getComponentByClassName(directives, 'ComponentA'));
    }
    {
      View view = _getViewByClassName(views, 'ComponentB');
      expect(view.templateText, isNull);
      expect(view.templateUrl, 'compB.html');
      expect(view.directives, hasLength(2));
      List<String> directiveNames = view.directives
          .map((directive) => directive.classElement.name)
          .toList();
      expect(directiveNames, unorderedEquals(['ComponentA', 'DirectiveA']));
    }
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

@reflectiveTest
class ResolveDartTemplatesTaskTest extends _AbstractDartTaskTest {
  void test_componentReference() {
    _addAngularSources();
    var code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'my-aaa')
@View(template: '<div>AAA</div>')
class ComponentA {
}

@Component(selector: 'my-bbb')
@View(template: '<div>BBB</div>')
class ComponentB {
}

@Component(selector: 'my-ccc')
@View(template: r"""
<div>
  <my-aaa></my-aaa>1
  <my-bbb></my-bbb>2
</div>
""", directives: [ComponentA, ComponentB])
class ComponentC {
}
''';
    Source source = _newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // prepare directives
    List<AbstractDirective> directives =
        context.analysisCache.getValue(target, DIRECTIVES);
    Component componentA = _getComponentByClassName(directives, 'ComponentA');
    Component componentB = _getComponentByClassName(directives, 'ComponentB');
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(3));
    {
      Template template = _getDartTemplateByClassName(templates, 'ComponentA');
      expect(template.ranges, isEmpty);
    }
    {
      Template template = _getDartTemplateByClassName(templates, 'ComponentB');
      expect(template.ranges, isEmpty);
    }
    {
      Template template = _getDartTemplateByClassName(templates, 'ComponentC');
      List<ResolvedRange> ranges = template.ranges;
      expect(ranges, hasLength(4));
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, 'my-aaa></');
        assertComponentReference(resolvedRange, componentA);
      }
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, 'my-aaa>1');
        assertComponentReference(resolvedRange, componentA);
      }
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, 'my-bbb></');
        assertComponentReference(resolvedRange, componentB);
      }
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, 'my-bbb>2');
        assertComponentReference(resolvedRange, componentB);
      }
    }
    // no errors
    _fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_hasError_expression_ArgumentTypeNotAssignable() {
    _addAngularSources();
    String code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'text-panel')
@View(template: r"<div> {{text.length + text}} </div>")
class TextPanel {
  String text;
}
''';
    Source source = _newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // has errors
    _fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertErrorsWithCodes(
        [StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE]);
  }

  void test_hasError_expression_UndefinedIdentifier() {
    _addAngularSources();
    String code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'text-panel', properties: const ['text'])
@View(template: r"<div>some text</div>")
class TextPanel {
  String text;
}

@Component(selector: 'UserPanel')
@View(template: r"""
<div>
  <text-panel [text]='noSuchName'></text-panel>
</div>
""", directives: [TextPanel])
class UserPanel {
}
''';
    Source source = _newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // has errors
    _fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener
        .assertErrorsWithCodes([StaticWarningCode.UNDEFINED_IDENTIFIER]);
  }

  void test_hasError_UnresolvedTag() {
    _addAngularSources();
    Source source = _newSource(
        '/test.dart',
        r'''
import '/angular2/metadata.dart';

@Component(selector: 'my-aaa')
@View(template: '<unresolved-tag></unresolved-tag>')
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    _fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener
        .assertErrorsWithCodes(<ErrorCode>[AngularWarningCode.UNRESOLVED_TAG]);
  }

  void test_htmlParsing_hasError() {
    _addAngularSources();
    String code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'text-panel')
@View(template: r"<div> <h2> Expected closing H2 </h3> </div>")
class TextPanel {
}
''';
    Source source = _newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // has errors
    _fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertErrorsWithCodes([HtmlErrorCode.PARSE_ERROR]);
  }

  void test_property_OK_event() {
    _addAngularSources();
    String code = r'''
import 'dart:html';
import '/angular2/metadata.dart';

@Component(selector: 'UserPanel')
@View(template: r"""
<div>
  <input (keyup)='doneTyping($event)'>
</div>
""")
class TodoList {
  doneTyping(KeyboardEvent event) {}
}
''';
    Source source = _newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(1));
    {
      Template template = _getDartTemplateByClassName(templates, 'TodoList');
      List<ResolvedRange> ranges = template.ranges;
      expect(ranges, hasLength(2));
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, r'doneTyping($');
        expect(resolvedRange.range.length, 'doneTyping'.length);
        Element element = (resolvedRange.element as DartElement).element;
        expect(element, new isInstanceOf<MethodElement>());
        expect(element.name, 'doneTyping');
        expect(element.nameOffset,
            code.indexOf('doneTyping(KeyboardEvent event)'));
      }
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, r"$event)'>");
        expect(resolvedRange.range.length, r'$event'.length);
        Element element = (resolvedRange.element as DartElement).element;
        expect(element, new isInstanceOf<LocalVariableElement>());
        expect(element.name, r'$event');
        expect(element.nameOffset, -1);
      }
    }
    // no errors
    _fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_property_OK_reference_expression() {
    _addAngularSources();
    String code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'text-panel', properties: const ['text'])
@View(template: r"<div>some text</div>")
class TextPanel {
  String text;
}

@Component(selector: 'UserPanel')
@View(template: r"""
<div>
  <text-panel [text]='user.name'></text-panel>
</div>
""", directives: [TextPanel])
class UserPanel {
  User user; // 1
}

class User {
  String name; // 2
}
''';
    Source source = _newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // prepare directives
    List<AbstractDirective> directives =
        context.analysisCache.getValue(target, DIRECTIVES);
    Component textPanel = _getComponentByClassName(directives, 'TextPanel');
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(2));
    {
      Template template = _getDartTemplateByClassName(templates, 'UserPanel');
      List<ResolvedRange> ranges = template.ranges;
      expect(ranges, hasLength(5));
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, 'text]=');
        expect(resolvedRange.range.length, 'text'.length);
        assertPropertyReference(resolvedRange, textPanel, 'text');
      }
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, 'user.');
        expect(resolvedRange.range.length, 'user'.length);
        Element element = (resolvedRange.element as DartElement).element;
        expect(element, new isInstanceOf<PropertyAccessorElement>());
        expect(element.name, 'user');
        expect(element.nameOffset, code.indexOf('user; // 1'));
      }
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, "name'>");
        expect(resolvedRange.range.length, 'name'.length);
        Element element = (resolvedRange.element as DartElement).element;
        expect(element, new isInstanceOf<PropertyAccessorElement>());
        expect(element.name, 'name');
        expect(element.nameOffset, code.indexOf('name; // 2'));
      }
    }
    // no errors
    _fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_property_OK_reference_text() {
    _addAngularSources();
    String code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'comp-a', properties: const ['first', 'vtoroy: second'])
@View(template: r"<div>AAA</div>")
class ComponentA {
  int first;
  int vtoroy;
}

@Component(selector: 'comp-b')
@View(template: r"""
<div>
  <comp-a first='1' second='2'></comp-a>
</div>
""", directives: [ComponentA])
class ComponentB {
}
''';
    Source source = _newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // prepare directives
    List<AbstractDirective> directives =
        context.analysisCache.getValue(target, DIRECTIVES);
    Component componentA = _getComponentByClassName(directives, 'ComponentA');
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(2));
    {
      Template template = _getDartTemplateByClassName(templates, 'ComponentB');
      List<ResolvedRange> ranges = template.ranges;
      expect(ranges, hasLength(4));
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, 'first=');
        expect(resolvedRange.range.length, 'first'.length);
        assertPropertyReference(resolvedRange, componentA, 'first');
      }
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, 'second=');
        expect(resolvedRange.range.length, 'second'.length);
        assertPropertyReference(resolvedRange, componentA, 'second');
      }
    }
    // no errors
    _fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_textExpression_hasError_UnterminatedMustache() {
    _addAngularSources();
    String code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'text-panel')
@View(template: r"<div> {{text </div>")
class TextPanel {
}
''';
    Source source = _newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(1));
    // has errors
    _fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener
        .assertErrorsWithCodes([AngularWarningCode.UNTERMINATED_MUSTACHE]);
  }

  void test_textExpression_OK() {
    _addAngularSources();
    String code = r'''
import '/angular2/metadata.dart';

@Component(selector: 'text-panel', properties: const ['text'])
@View(template: r"<div> <h2> {{text}}  </h2> and {{text.length}} </div>")
class TextPanel {
  String text; // 1
}
''';
    Source source = _newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    _computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(1));
    {
      Template template = _getDartTemplateByClassName(templates, 'TextPanel');
      List<ResolvedRange> ranges = template.ranges;
      expect(ranges, hasLength(3));
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, 'text}}');
        expect(resolvedRange.range.length, 'text'.length);
        PropertyAccessorElement element =
            (resolvedRange.element as DartElement).element;
        expect(element.isGetter, isTrue);
        expect(element.name, 'text');
        expect(element.nameOffset, code.indexOf('text; // 1'));
      }
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, 'text.length');
        expect(resolvedRange.range.length, 'text'.length);
        PropertyAccessorElement element =
            (resolvedRange.element as DartElement).element;
        expect(element.isGetter, isTrue);
        expect(element.name, 'text');
        expect(element.nameOffset, code.indexOf('text; // 1'));
      }
      {
        ResolvedRange resolvedRange =
            _getResolvedRangeAtString(code, ranges, 'length}}');
        expect(resolvedRange.range.length, 'length'.length);
        PropertyAccessorElement element =
            (resolvedRange.element as DartElement).element;
        expect(element.isGetter, isTrue);
        expect(element.name, 'length');
        expect(element.enclosingElement.name, 'String');
      }
    }
    // no errors
    _fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertNoErrors();
  }

  static void assertComponentReference(
      ResolvedRange resolvedRange, Component component) {
    ElementNameSelector selector = component.selector;
    AngularElement element = resolvedRange.element;
    expect(element, selector.nameElement);
    expect(resolvedRange.range.length, selector.nameElement.name.length);
  }

  static void assertPropertyReference(
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

  static Template _getDartTemplateByClassName(
      List<Template> templates, String className) {
    return templates.firstWhere(
        (template) => template.view.classElement.name == className, orElse: () {
      fail('Template with the class "$className" was not found.');
      return null;
    });
  }

  static ResolvedRange _getResolvedRangeAtString(
      String code, List<ResolvedRange> ranges, String str) {
    int offset = code.indexOf(str);
    return ranges.firstWhere((_) => _.range.offset == offset, orElse: () {
      fail('ResolvedRange at $offset was not found.');
      return null;
    });
  }
}

class _AbstractDartTaskTest {
  MemoryResourceProvider resourceProvider = new MemoryResourceProvider();
  Source emptySource;

  DartSdk sdk = new MockSdk();
  AnalysisContextImpl context;
  Map<AnalysisTarget, CacheEntry> entryMap = <AnalysisTarget, CacheEntry>{};

  TaskManager taskManager = new TaskManager();
  AnalysisDriver analysisDriver;

  AnalysisTask task;
  Map<ResultDescriptor<dynamic>, dynamic> outputs;
  GatheringErrorListener errorListener = new GatheringErrorListener();

  void setUp() {
    AnalysisEngine.instance.userDefinedPlugins = [new AngularAnalyzerPlugin()];
    emptySource = _newSource('/test.dart');
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
    _newSource(
        '/angular2/metadata.dart',
        r'''
library angular2.src.core.metadata;

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
''');
  }

  void _computeResult(AnalysisTarget target, ResultDescriptor result) {
    task = analysisDriver.computeResult(target, result);
    expect(task.caughtException, isNull);
    outputs = task.outputs;
  }

  /**
   * Fill [errorListener] with [result] errors in the current [task].
   */
  void _fillErrorListener(ResultDescriptor<List<AnalysisError>> result) {
    List<AnalysisError> errors = task.outputs[result];
    expect(errors, isNotNull, reason: result.name);
    errorListener = new GatheringErrorListener();
    errorListener.addAll(errors);
  }

  Source _newSource(String path, [String content = '']) {
    File file = resourceProvider.newFile(path, content);
    return file.createSource();
  }
}
