import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_ast/angular_ast.dart';
import 'package:angular_analyzer_plugin/src/from_file_prefixed_error.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/options.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/errors.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/view_extraction.dart';
import 'package:angular_analyzer_plugin/src/directive_linking.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:test/test.dart';

import 'abstract_angular.dart';

// ignore_for_file: deprecated_member_use

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AngularParseHtmlTest);
    defineReflectiveTests(BuildStandardHtmlComponentsTest);
    defineReflectiveTests(BuildStandardHtmlTest);
    defineReflectiveTests(BuildStandardAngularTest);
    defineReflectiveTests(GatherAnnotationsTest);
    defineReflectiveTests(GatherAnnotationsOnFutureAngularTest);
    defineReflectiveTests(BuildUnitViewsTest);
    defineReflectiveTests(ResolveDartTemplatesTest);
    defineReflectiveTests(LinkDirectivesTest);
    defineReflectiveTests(ResolveHtmlTemplatesTest);
    defineReflectiveTests(ResolveHtmlTemplateTest);
  });
}

@reflectiveTest
class AngularParseHtmlTest extends AbstractAngularTest {
  // ignore: non_constant_identifier_names
  void test_perform() {
    final code = r'''
<!DOCTYPE html>
<html>
  <head>
    <title> test page </title>
  </head>
  <body>
    <h1 myAttr='my value'>Test</h1>
  </body>
</html>
    ''';
    final source = newSource('/test.html', code);
    final tplParser = new TemplateParser()..parse(code, source);
    expect(tplParser.parseErrors, isEmpty);
    // HTML_DOCUMENT
    {
      final asts = tplParser.rawAst;
      expect(asts, isNotNull);
      // verify that attributes are not lower-cased
      final element = asts[1].childNodes[3].childNodes[1] as ElementAst;
      expect(element.attributes.length, 1);
      expect(element.attributes[0].name, 'myAttr');
      expect(element.attributes[0].value, 'my value');
    }
  }

  // ignore: non_constant_identifier_names
  void test_perform_noDocType() {
    final code = r'''
<div>AAA</div>
<span>BBB</span>
''';
    final source = newSource('/test.html', code);
    final tplParser = new TemplateParser()..parse(code, source);
    // validate Document
    {
      final asts = tplParser.rawAst;
      expect(asts, isNotNull);
      expect(asts.length, 4);
      expect((asts[0] as ElementAst).name, 'div');
      expect((asts[2] as ElementAst).name, 'span');
    }
    // it's OK to don't have DOCTYPE
    expect(tplParser.parseErrors, isEmpty);
  }

  // ignore: non_constant_identifier_names
  // ignore: non_constant_identifier_names
  void test_perform_noDocType_with_dangling_unclosed_tag() {
    final code = r'''
<div>AAA</div>
<span>BBB</span>
<di''';
    final source = newSource('/test.html', code);
    final tplParser = new TemplateParser()..parse(code, source);
    // quick validate Document
    {
      final asts = tplParser.rawAst;
      expect(asts, isNotNull);
      expect(asts.length, 5);
      expect((asts[0] as ElementAst).name, 'div');
      expect((asts[2] as ElementAst).name, 'span');
      expect((asts[4] as ElementAst).name, 'di');
    }
  }
}

@reflectiveTest
class BuildStandardHtmlComponentsTest extends AbstractAngularTest {
  // ignore: non_constant_identifier_names
  // ignore: non_constant_identifier_names
  Future test_perform() async {
    final stdhtml = await angularDriver.getStandardHtml();
    // validate
    final map = stdhtml.components;
    expect(map, isNotNull);
    // a
    {
      final component = map['a'];
      expect(component, isNotNull);
      expect(component.classElement.displayName, 'AnchorElement');
      expect(component.selector.toString(), 'a');
      final inputs = component.inputs;
      final outputElements = component.outputs;
      {
        final input = inputs.singleWhere((i) => i.name == 'href');
        expect(input, isNotNull);
        expect(input.setter, isNotNull);
        expect(input.setterType.toString(), equals("String"));
        expect(input.securityContext, isNotNull);
        expect(input.securityContext.safeType.toString(), equals('SafeUrl'));
        expect(input.securityContext.sanitizationAvailable, equals(true));
      }
      expect(outputElements, hasLength(0));
      expect(inputs.where((i) => i.name == '_privateField'), hasLength(0));
    }
    // button
    {
      final component = map['button'];
      expect(component, isNotNull);
      expect(component.classElement.displayName, 'ButtonElement');
      expect(component.selector.toString(), 'button');
      final inputs = component.inputs;
      final outputElements = component.outputs;
      {
        final input = inputs.singleWhere((i) => i.name == 'autofocus');
        expect(input, isNotNull);
        expect(input.setter, isNotNull);
        expect(input.setterType.toString(), equals("bool"));
        expect(input.securityContext, isNull);
      }
      expect(outputElements, hasLength(0));
    }
    // iframe
    {
      final component = map['iframe'];
      expect(component, isNotNull);
      expect(component.classElement.displayName, 'IFrameElement');
      expect(component.selector.toString(), 'iframe');
      final inputs = component.inputs;
      {
        final input = inputs.singleWhere((i) => i.name == 'src');
        expect(input, isNotNull);
        expect(input.setter, isNotNull);
        expect(input.setterType.toString(), equals("String"));
        expect(input.securityContext, isNotNull);
        expect(input.securityContext.safeType.toString(),
            equals('SafeResourceUrl'));
        expect(input.securityContext.sanitizationAvailable, equals(false));
      }
    }
    // input
    {
      final component = map['input'];
      expect(component, isNotNull);
      expect(component.classElement.displayName, 'InputElement');
      expect(component.selector.toString(), 'input');
      final outputElements = component.outputs;
      expect(outputElements, hasLength(0));
    }
    // body is one of the few elements with special events
    {
      final component = map['body'];
      expect(component, isNotNull);
      expect(component.classElement.displayName, 'BodyElement');
      expect(component.selector.toString(), 'body');
      final outputElements = component.outputs;
      expect(outputElements, hasLength(1));
      {
        final output = outputElements[0];
        expect(output.name, equals("unload"));
        expect(output.getter, isNotNull);
        expect(output.eventType, isNotNull);
      }
    }
    // h1, h2, h3
    expect(map['h1'], isNotNull);
    expect(map['h2'], isNotNull);
    expect(map['h3'], isNotNull);
    // has no mention of 'option' in the source, is hardcoded
    expect(map['option'], isNotNull);
    // <template> is special, not actually a TemplateElement
    expect(map['template'], isNull);
    // <audio> is a "specialElementClass", its ctor isn't analyzable.
    expect(map['audio'], isNotNull);
  }

  // ignore: non_constant_identifier_names
  Future test_buildStandardHtmlEvents() async {
    final stdhtml = await angularDriver.getStandardHtml();
    final outputElements = stdhtml.events;
    {
      // This one is important because it proves we're using @DomAttribute
      // to generate the output name and not the method in the sdk.
      final outputElement = outputElements['keyup'];
      expect(outputElement, isNotNull);
      expect(outputElement.getter, isNotNull);
      expect(outputElement.eventType, isNotNull);
    }
    {
      final outputElement = outputElements['cut'];
      expect(outputElement, isNotNull);
      expect(outputElement.getter, isNotNull);
      expect(outputElement.eventType, isNotNull);
    }
    {
      final outputElement = outputElements['click'];
      expect(outputElement, isNotNull);
      expect(outputElement.getter, isNotNull);
      expect(outputElement.eventType, isNotNull);
      expect(outputElement.eventType.toString(), 'MouseEvent');
    }
    {
      final outputElement = outputElements['change'];
      expect(outputElement, isNotNull);
      expect(outputElement.getter, isNotNull);
      expect(outputElement.eventType, isNotNull);
    }
    {
      // used to happen from "id" which got truncated by 'on'.length
      final outputElement = outputElements[''];
      expect(outputElement, isNull);
    }
    {
      // used to happen from "hidden" which got truncated by 'on'.length
      final outputElement = outputElements['dden'];
      expect(outputElement, isNull);
    }
    {
      // missing from dart:html, and supplied manually (with no getter)
      final outputElement = outputElements['focusin'];
      expect(outputElement, isNotNull);
      expect(outputElement.eventType, isNotNull);
      expect(outputElement.eventType.toString(), 'FocusEvent');
    }
    {
      // missing from dart:html, and supplied manually (with no getter)
      final outputElement = outputElements['focusout'];
      expect(outputElement, isNotNull);
      expect(outputElement.eventType, isNotNull);
      expect(outputElement.eventType.toString(), 'FocusEvent');
    }
  }

  // ignore: non_constant_identifier_names
  Future test_buildStandardHtmlAttributes() async {
    final stdhtml = await angularDriver.getStandardHtml();
    final inputElements = stdhtml.attributes;
    {
      final input = inputElements['tabIndex'];
      expect(input, isNotNull);
      expect(input.setter, isNotNull);
      expect(input.setterType.toString(), equals("int"));
    }
    {
      final input = inputElements['hidden'];
      expect(input, isNotNull);
      expect(input.setter, isNotNull);
      expect(input.setterType.toString(), equals("bool"));
    }
    {
      final input = inputElements['innerHtml'];
      expect(input, isNotNull);
      expect(identical(input, inputElements['innerHTML']), true);
      expect(input.setter, isNotNull);
      expect(input.setterType.toString(), equals('String'));
      expect(input.securityContext, isNotNull);
      expect(input.securityContext.safeType.toString(), equals('SafeHtml'));
      expect(input.securityContext.sanitizationAvailable, equals(true));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_buildStandardHtmlClasses() async {
    final stdhtml = await angularDriver.getStandardHtml();
    expect(stdhtml.elementClass, isNotNull);
    expect(stdhtml.elementClass.name, 'Element');
    expect(stdhtml.htmlElementClass, isNotNull);
    expect(stdhtml.htmlElementClass.name, 'HtmlElement');
  }
}

@reflectiveTest
class BuildStandardHtmlTest extends AbstractAngularTest {
  @override
  void setUp() {
    // Don't perform setup before tests. Tests will run `super.setUp()`.
  }

  // ignore: non_constant_identifier_names
  Future test_perform() async {
    super.setUp();
    final html = await angularDriver.getStandardHtml();
    // validate
    expect(html, isNotNull);
    expect(html.events, isNotNull);
    expect(html.standardEvents, isNotNull);
    expect(html.customEvents, isNotNull);
  }

  // ignore: non_constant_identifier_names
  Future test_customEvents_untyped() async {
    ngOptions = new AngularOptions.fromString(r'''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_events:
        foo:
        bar:
''', null);

    super.setUp();
    final html = await angularDriver.getStandardHtml();
    // validate
    expect(html, isNotNull);
    expect(html.customEvents, isNotNull);
    expect(html.customEvents, hasLength(2));
    {
      final event = html.customEvents['foo'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'dynamic');
    }
    {
      final event = html.customEvents['bar'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'dynamic');
    }
  }

  // ignore: non_constant_identifier_names
  Future test_customEvents_coreTypes() async {
    ngOptions = new AngularOptions.fromString(r'''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_events:
        strEventImplicitCore:
          type: String
        strEventExplicitCore:
          type: String
          path: 'dart:core'
        boolEventImplicitCore:
          type: bool
        boolEventExplicitCore:
          type: bool
          path: 'dart:core'
''', null);

    super.setUp();

    final html = await angularDriver.getStandardHtml();
    // validate
    expect(html, isNotNull);
    expect(html.customEvents, isNotNull);
    expect(html.customEvents, hasLength(4));
    {
      final event = html.customEvents['strEventImplicitCore'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'String');
      expect(
          event.eventType.element.source.fullName, '/sdk/lib/core/core.dart');
    }
    {
      final event = html.customEvents['strEventExplicitCore'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'String');
      expect(
          event.eventType.element.source.fullName, '/sdk/lib/core/core.dart');
    }
    {
      final event = html.customEvents['boolEventImplicitCore'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'bool');
      expect(
          event.eventType.element.source.fullName, '/sdk/lib/core/core.dart');
    }
    {
      final event = html.customEvents['boolEventExplicitCore'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'bool');
      expect(
          event.eventType.element.source.fullName, '/sdk/lib/core/core.dart');
    }
  }

  // ignore: non_constant_identifier_names
  Future test_customEvents_noSource_dynamic() async {
    ngOptions = new AngularOptions.fromString(r'''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_events:
        noSuchSource:
          typePath: nonexist.dart
''', null);

    super.setUp();
    final html = await angularDriver.getStandardHtml();
    // validate
    expect(html, isNotNull);
    expect(html.customEvents, isNotNull);
    expect(html.customEvents, hasLength(1));
    {
      final event = html.customEvents['noSuchSource'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'dynamic');
    }
  }

  // ignore: non_constant_identifier_names
  Future test_customEvents_noSuchIdentifier_dynamic() async {
    ngOptions = new AngularOptions.fromString(r'''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_events:
        noSuchIdentifier:
          type: NonExistEvent
          path: 'package:test_package/customevent.dart'
''', null);

    super.setUp();

    newSource('/customevent.dart', r'''
class NotTheCorrectEvent {}
''');

    final html = await angularDriver.getStandardHtml();
    // validate
    expect(html, isNotNull);
    expect(html.customEvents, isNotNull);
    expect(html.customEvents, hasLength(1));
    {
      final event = html.customEvents['noSuchIdentifier'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'dynamic');
    }
  }

  // ignore: non_constant_identifier_names
  Future test_customEvents_typeIsNotAType_dynamic() async {
    ngOptions = new AngularOptions.fromString(r'''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_events:
        notAType:
          type: foo
          path: 'package:test_package/customevent.dart'
''', null);

    super.setUp();

    newSource('/customevent.dart', r'''
int foo;
''');
    final html = await angularDriver.getStandardHtml();
    // validate
    expect(html, isNotNull);
    expect(html.customEvents, isNotNull);
    expect(html.customEvents, hasLength(1));
    {
      final event = html.customEvents['notAType'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'dynamic');
    }
  }

  // ignore: non_constant_identifier_names
  Future test_customEvents_resolved() async {
    ngOptions = new AngularOptions.fromString(r'''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_events:
        bar:
          type: BarEvent
          path: 'package:test_package/bar.dart'
''', null);

    super.setUp();

    newSource('/bar.dart', r'''
class BarEvent {}
''');
    final html = await angularDriver.getStandardHtml();
    // validate
    expect(html, isNotNull);
    expect(html.customEvents, isNotNull);
    expect(html.customEvents, hasLength(1));
    {
      final event = html.customEvents['bar'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'BarEvent');
      expect(event.eventType.element.source.fullName, '/bar.dart');
    }
  }

  // ignore: non_constant_identifier_names
  Future test_customEvents_enum() async {
    ngOptions = new AngularOptions.fromString(r'''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_events:
        enumType:
          type: EnumType
          path: 'package:test_package/enum.dart'
''', null);

    super.setUp();

    newSource('/enum.dart', r'''
enum EnumType {}
''');
    final html = await angularDriver.getStandardHtml();
    // validate
    expect(html, isNotNull);
    expect(html.customEvents, isNotNull);
    expect(html.customEvents, hasLength(1));
    {
      final event = html.customEvents['enumType'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'EnumType');
      expect(event.eventType.element.source.fullName, '/enum.dart');
    }
  }

  // ignore: non_constant_identifier_names
  Future test_customEvents_typedef() async {
    ngOptions = new AngularOptions.fromString(r'''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_events:
        typedef:
          type: TypeDef
          path: 'package:test_package/typedef.dart'
''', null);

    super.setUp();

    newSource('/typedef.dart', r'''
typedef TypeDef = int Function<T>();
''');
    final html = await angularDriver.getStandardHtml();
    // validate
    expect(html, isNotNull);
    expect(html.customEvents, isNotNull);
    expect(html.customEvents, hasLength(1));
    {
      final event = html.customEvents['typedef'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), '() → int');
      expect(event.eventType.element.source.fullName, '/typedef.dart');
    }
  }

  // ignore: non_constant_identifier_names
  Future test_customEvents_generic() async {
    ngOptions = new AngularOptions.fromString(r'''
analyzer:
  plugins:
    angular:
      enabled: true
      custom_events:
        generic:
          type: Generic
          path: 'package:test_package/generic.dart'
''', null);

    super.setUp();

    newSource('/generic.dart', r'''
class Generic<T> {}
''');
    final html = await angularDriver.getStandardHtml();
    // validate
    expect(html, isNotNull);
    expect(html.customEvents, isNotNull);
    expect(html.customEvents, hasLength(1));
    {
      final event = html.customEvents['generic'];
      expect(event, isNotNull);
      expect(event.getter, isNull);
      expect(event.eventType, isNotNull);
      expect(event.eventType.toString(), 'Generic<dynamic>');
      expect(event.eventType.element.source.fullName, '/generic.dart');
    }
  }
}

@reflectiveTest
class BuildStandardAngularTest extends AbstractAngularTest {
  // ignore: non_constant_identifier_names
  Future test_perform() async {
    final ng = await angularDriver.getStandardAngular();
    // validate
    expect(ng, isNotNull);
    expect(ng.templateRef, isNotNull);
    expect(ng.elementRef, isNotNull);
    expect(ng.queryList, isNotNull);
    expect(ng.pipeTransform, isNotNull);
    expect(ng.component, isNotNull);
  }

  // ignore: non_constant_identifier_names
  Future test_securitySchema() async {
    final ng = await angularDriver.getStandardAngular();
    // validate
    expect(ng, isNotNull);
    expect(ng.securitySchema, isNotNull);

    final imgSrcSecurity = ng.securitySchema.lookup('img', 'src');
    expect(imgSrcSecurity, isNotNull);
    expect(imgSrcSecurity.safeType.toString(), 'SafeUrl');
    expect(imgSrcSecurity.sanitizationAvailable, true);

    final aHrefSecurity = ng.securitySchema.lookup('a', 'href');
    expect(aHrefSecurity, isNotNull);
    expect(aHrefSecurity.safeType.toString(), 'SafeUrl');
    expect(aHrefSecurity.sanitizationAvailable, true);

    final innerHtmlSecurity = ng.securitySchema.lookupGlobal('innerHTML');
    expect(innerHtmlSecurity, isNotNull);
    expect(innerHtmlSecurity.safeType.toString(), 'SafeHtml');
    expect(innerHtmlSecurity.sanitizationAvailable, true);

    final iframeSrcdocSecurity = ng.securitySchema.lookup('iframe', 'srcdoc');
    expect(iframeSrcdocSecurity, isNotNull);
    expect(iframeSrcdocSecurity.safeType.toString(), 'SafeHtml');
    expect(iframeSrcdocSecurity.sanitizationAvailable, true);

    final styleSecurity = ng.securitySchema.lookupGlobal('style');
    expect(styleSecurity, isNotNull);
    expect(styleSecurity.safeType.toString(), 'SafeStyle');
    expect(styleSecurity.sanitizationAvailable, true);

    final iframeSrcSecurity = ng.securitySchema.lookup('iframe', 'src');
    expect(iframeSrcSecurity, isNotNull);
    expect(iframeSrcSecurity.safeType.toString(), 'SafeResourceUrl');
    expect(iframeSrcSecurity.sanitizationAvailable, false);

    final scriptSrcSecurity = ng.securitySchema.lookup('script', 'src');
    expect(scriptSrcSecurity, isNotNull);
    expect(scriptSrcSecurity.safeType.toString(), 'SafeResourceUrl');
    expect(scriptSrcSecurity.sanitizationAvailable, false);
  }
}

abstract class GatherAnnotationsTestMixin implements AbstractAngularTest {
  List<AbstractDirective> directives;
  List<Pipe> pipes;
  List<AnalysisError> errors;

  Future getDirectives(final Source source) async {
    final dartResult = await dartDriver.getResult(source.fullName);
    fillErrorListener(dartResult.errors);
    final result = await angularDriver.getAngularTopLevels(source.fullName);
    directives = result.directives;
    pipes = result.pipes;
    errors = result.errors;
    fillErrorListener(errors);
  }
}

@reflectiveTest
class GatherAnnotationsTest extends AbstractAngularTest
    with GatherAnnotationsTestMixin {
  // ignore: non_constant_identifier_names
  Future test_Component() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'comp-a', template:'')
class ComponentA {
}

@Component(selector: 'comp-b', template:'')
class ComponentB {
}
''');
    await getDirectives(source);
    expect(directives, hasLength(2));
    {
      final component = directives[0];
      expect(component, const isInstanceOf<Component>());
      {
        final selector = component.selector;
        expect(selector, const isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-a');
      }
      {
        expect(component.elementTags, hasLength(1));
        final selector = component.elementTags[0];
        expect(selector, const isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-a');
      }
    }
    {
      final component = directives[1];
      expect(component, const isInstanceOf<Component>());
      {
        final selector = component.selector;
        expect(selector, const isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-b');
      }
      {
        expect(component.elementTags, hasLength(1));
        final selector = component.elementTags[0];
        expect(selector, const isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-b');
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_Directive() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Directive(selector: 'dir-a')
class DirectiveA {
}

@Directive(selector: 'dir-b')
class DirectiveB {
}
''');
    await getDirectives(source);
    expect(directives, hasLength(2));
    {
      final directive = directives[0];
      expect(directive, const isInstanceOf<Directive>());
      {
        final selector = directive.selector;
        expect(selector, const isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-a');
      }
      {
        expect(directive.elementTags, hasLength(1));
        final selector = directive.elementTags[0];
        expect(selector, const isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-a');
      }
    }
    {
      final directive = directives[1];
      expect(directive, const isInstanceOf<Directive>());
      {
        final selector = directive.selector;
        expect(selector, const isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-b');
      }
      {
        expect(directive.elementTags, hasLength(1));
        final selector = directive.elementTags[0];
        expect(selector, const isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-b');
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_Directive_elementTags_OrSelector() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Directive(selector: 'dir-a1, dir-a2, dir-a3')
class DirectiveA {
}

@Directive(selector: 'dir-b1, dir-b2')
class DirectiveB {
}
''');
    await getDirectives(source);
    expect(directives, hasLength(2));
    {
      final directive = directives[0];
      expect(directive, const isInstanceOf<Directive>());
      {
        final selector = directive.selector;
        expect(selector, const isInstanceOf<OrSelector>());
        expect((selector as OrSelector).selectors, hasLength(3));
      }
      {
        expect(directive.elementTags, hasLength(3));
        expect(directive.elementTags[0],
            const isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-a1');
        expect(directive.elementTags[1],
            const isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[1].toString(), 'dir-a2');
        expect(directive.elementTags[2],
            const isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[2].toString(), 'dir-a3');
      }
    }
    {
      final directive = directives[1];
      expect(directive, const isInstanceOf<Directive>());
      {
        final selector = directive.selector;
        expect(selector, const isInstanceOf<OrSelector>());
        expect((selector as OrSelector).selectors, hasLength(2));
      }
      {
        expect(directive.elementTags, hasLength(2));
        expect(directive.elementTags[0],
            const isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-b1');
        expect(directive.elementTags[1],
            const isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[1].toString(), 'dir-b2');
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_Directive_elementTags_AndSelector() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Directive(selector: 'dir-a.myClass[myAttr]')
class DirectiveA {
}

@Directive(selector: 'dir-b[myAttr]')
class DirectiveB {
}
''');
    await getDirectives(source);
    expect(directives, hasLength(2));
    {
      final directive = directives[0];
      expect(directive, const isInstanceOf<Directive>());
      {
        final selector = directive.selector;
        expect(selector, const isInstanceOf<AndSelector>());
        expect((selector as AndSelector).selectors, hasLength(3));
      }
      {
        expect(directive.elementTags, hasLength(1));
        expect(directive.elementTags[0],
            const isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-a');
      }
    }
    {
      final directive = directives[1];
      expect(directive, const isInstanceOf<Directive>());
      {
        final selector = directive.selector;
        expect(selector, const isInstanceOf<AndSelector>());
        expect((selector as AndSelector).selectors, hasLength(2));
      }
      {
        expect(directive.elementTags, hasLength(1));
        expect(directive.elementTags[0],
            const isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-b');
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_Directive_elementTags_CompoundSelector() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Directive(selector: 'dir-a1.myClass[myAttr], dir-a2.otherClass')
class DirectiveA {
}

@Directive(selector: 'dir-b1[myAttr], dir-b2')
class DirectiveB {
}
''');
    await getDirectives(source);
    expect(directives, hasLength(2));
    {
      final directive = directives[0];
      expect(directive, const isInstanceOf<Directive>());
      {
        final selector = directive.selector;
        expect(selector, const isInstanceOf<OrSelector>());
        expect((selector as OrSelector).selectors, hasLength(2));
      }
      {
        expect(directive.elementTags, hasLength(2));
        expect(directive.elementTags[0],
            const isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-a1');
        expect(directive.elementTags[1],
            const isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[1].toString(), 'dir-a2');
      }
    }
    {
      final directive = directives[1];
      expect(directive, const isInstanceOf<Directive>());
      {
        final selector = directive.selector;
        expect(selector, const isInstanceOf<OrSelector>());
        expect((selector as OrSelector).selectors, hasLength(2));
      }
      {
        expect(directive.elementTags, hasLength(2));
        expect(directive.elementTags[0],
            const isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-b1');
        expect(directive.elementTags[1],
            const isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[1].toString(), 'dir-b2');
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_FunctionalDirective() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Directive(selector: 'dir-a.myClass[myAttr]')
void directiveA() {
}
''');
    await getDirectives(source);
    expect(directives, hasLength(1));
    final directive = directives.single;
    expect(directive, const isInstanceOf<FunctionalDirective>());
    expect(directive.name, "directiveA");
    final selector = directive.selector;
    expect(selector, const isInstanceOf<AndSelector>());
    expect((selector as AndSelector).selectors, hasLength(3));
    expect(directive.elementTags, hasLength(1));
    expect(directive.elementTags[0], const isInstanceOf<ElementNameSelector>());
    expect(directive.elementTags[0].toString(), 'dir-a');
  }

  // ignore: non_constant_identifier_names
  Future test_FunctionalDirective_notAllowedValues() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Directive(selector: 'dir-a.myClass[myAttr]',
  exportAs: 'foo')
void directiveA() {
}
''');
    await getDirectives(source);
    errorListener.assertErrorsWithCodes(
        [AngularWarningCode.FUNCTIONAL_DIRECTIVES_CANT_BE_EXPORTED]);
  }

  // ignore: non_constant_identifier_names
  Future test_Pipe() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Pipe('pipeA')
class PipeA extends PipeTransform {
  int transform(int blah) => blah;
}

@Pipe('pipeB', pure: false)
class PipeB extends PipeTransform {
  String transform(int a1, String a2, bool a3) => 'someString';
}
''');
    await getDirectives(source);
    expect(pipes, hasLength(2));
    {
      final pipe = pipes[0];
      expect(pipe, const isInstanceOf<Pipe>());
      final pipeName = pipe.pipeName;
      final pure = pipe.isPure;
      expect(pipeName, const isInstanceOf<String>());
      expect(pipeName, 'pipeA');
      expect(pure, true);

      expect(pipe.requiredArgumentType.toString(), 'int');
      expect(pipe.transformReturnType.toString(), 'int');
      expect(pipe.optionalArgumentTypes, hasLength(0));
    }
    {
      final pipe = pipes[1];
      expect(pipe, const isInstanceOf<Pipe>());
      final pipeName = pipe.pipeName;
      final pure = pipe.isPure;
      expect(pipeName, const isInstanceOf<String>());
      expect(pipeName, 'pipeB');
      expect(pure, false);

      expect(pipe.requiredArgumentType.toString(), 'int');
      expect(pipe.transformReturnType.toString(), 'String');

      final opArgs = pipe.optionalArgumentTypes;
      expect(opArgs, hasLength(2));
      expect(opArgs[0].toString(), 'String');
      expect(opArgs[1].toString(), 'bool');
    }
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_pipeInheritance() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

class BasePipe extends PipeTransform {
  int transform(int blah) => blah;
}

@Pipe('pipe', pure: false)
class MyPipe extends BasePipe {
}
''');
    await getDirectives(source);
    expect(pipes, hasLength(1));
    {
      final pipe = pipes[0];
      expect(pipe, const isInstanceOf<Pipe>());
      final pipeName = pipe.pipeName;
      final pure = pipe.isPure;
      expect(pipeName, const isInstanceOf<String>());
      expect(pipeName, 'pipe');
      expect(pure, false);

      expect(pipe.requiredArgumentType.toString(), 'int');
      expect(pipe.transformReturnType.toString(), 'int');
      expect(pipe.optionalArgumentTypes, hasLength(0));
    }

    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_Pipe_error_no_pipeTransform() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Pipe('pipeA')
class PipeA {
  int transform(int blah) => blah;
}
''');
    await getDirectives(source);
    expect(pipes, hasLength(1));
    final pipe = pipes[0];
    expect(pipe, const isInstanceOf<Pipe>());
    final pipeName = pipe.pipeName;
    final pure = pipe.isPure;
    expect(pipeName, const isInstanceOf<String>());
    expect(pipeName, 'pipeA');
    expect(pure, true);

    expect(pipe.transformReturnType.toString(), 'int');
    expect(pipe.requiredArgumentType.toString(), 'int');
    expect(pipe.optionalArgumentTypes, hasLength(0));

    errorListener.assertErrorsWithCodes(
        [AngularWarningCode.PIPE_REQUIRES_PIPETRANSFORM]);
  }

  // ignore: non_constant_identifier_names
  Future test_Pipe_error_bad_extends() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

class Trouble {}

@Pipe('pipeA')
class PipeA extends Trouble{
  int transform(int blah) => blah;
}
''');
    await getDirectives(source);
    expect(pipes, hasLength(1));
    final pipe = pipes[0];
    expect(pipe, const isInstanceOf<Pipe>());
    final pipeName = pipe.pipeName;
    final pure = pipe.isPure;
    expect(pipeName, const isInstanceOf<String>());
    expect(pipeName, 'pipeA');
    expect(pure, true);

    expect(pipe.transformReturnType.toString(), 'int');
    expect(pipe.requiredArgumentType.toString(), 'int');
    expect(pipe.optionalArgumentTypes, hasLength(0));

    errorListener.assertErrorsWithCodes(
        [AngularWarningCode.PIPE_REQUIRES_PIPETRANSFORM]);
  }

  // ignore: non_constant_identifier_names
  Future test_Pipe_is_abstract() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

class Trouble {}

@Pipe('pipeA')
abstract class PipeA extends PipeTransform{
  int transform(int blah) => blah;
}
''');
    await getDirectives(source);
    expect(pipes, hasLength(1));
    final pipe = pipes[0];
    expect(pipe, const isInstanceOf<Pipe>());
    final pipeName = pipe.pipeName;
    final pure = pipe.isPure;
    expect(pipeName, const isInstanceOf<String>());
    expect(pipeName, 'pipeA');
    expect(pure, true);

    expect(pipe.transformReturnType.toString(), 'int');
    expect(pipe.requiredArgumentType.toString(), 'int');
    expect(pipe.optionalArgumentTypes, hasLength(0));

    errorListener
        .assertErrorsWithCodes([AngularWarningCode.PIPE_CANNOT_BE_ABSTRACT]);
  }

  // ignore: non_constant_identifier_names
  Future test_Pipe_error_no_transform() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

class Trouble {}

@Pipe('pipeA')
class PipeA extends PipeTransform{}
''');
    await getDirectives(source);
    expect(pipes, hasLength(1));
    final pipe = pipes[0];
    expect(pipe, const isInstanceOf<Pipe>());
    final pipeName = pipe.pipeName;
    final pure = pipe.isPure;
    expect(pipeName, const isInstanceOf<String>());
    expect(pipeName, 'pipeA');
    expect(pure, true);

    expect(pipe.requiredArgumentType, null);
    expect(pipe.transformReturnType, null);
    expect(pipe.optionalArgumentTypes, hasLength(0));

    errorListener.assertErrorsWithCodes(
        [AngularWarningCode.PIPE_REQUIRES_TRANSFORM_METHOD]);
  }

  // ignore: non_constant_identifier_names
  Future test_Pipe_error_named_args() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Pipe('pipeA')
class PipeA extends PipeTransform{
  transform({named}) {}
}
''');
    await getDirectives(source);
    expect(pipes, hasLength(1));
    final pipe = pipes[0];
    expect(pipe, const isInstanceOf<Pipe>());

    errorListener.assertErrorsWithCodes(
        [AngularWarningCode.PIPE_TRANSFORM_NO_NAMED_ARGS]);
  }

  // ignore: non_constant_identifier_names
  Future test_Pipe_allowedOptionalArgs() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Pipe('pipeA')
class PipeA extends PipeTransform{
  transform([named]) {}
}
''');
    await getDirectives(source);
    expect(pipes, hasLength(1));
    final pipe = pipes[0];
    expect(pipe, const isInstanceOf<Pipe>());

    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_Pipe_dynamic() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Pipe('pipeA')
class PipeA extends PipeTransform{
  dynamic transform(dynamic x, [dynamic more]) {}
}
''');
    await getDirectives(source);
    expect(pipes, hasLength(1));
    final pipe = pipes[0];
    expect(pipe, const isInstanceOf<Pipe>());

    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_exportAs_Component() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', exportAs: 'export-name', template:'')
class ComponentA {
}

@Component(selector: 'bbb', template:'')
class ComponentB {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(directives, hasLength(2));
    {
      final component = getComponentByName(directives, 'ComponentA');
      {
        final exportAs = component.exportAs;
        expect(exportAs.name, 'export-name');
        expect(exportAs.nameOffset, code.indexOf('export-name'));
      }
    }
    {
      final component = getComponentByName(directives, 'ComponentB');
      {
        final exportAs = component.exportAs;
        expect(exportAs, isNull);
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_exportAs_Directive() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: '[aaa]', exportAs: 'export-name')
class DirectiveA {
}

@Directive(selector: '[bbb]')
class DirectiveB {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(directives, hasLength(2));
    {
      final directive = getDirectiveByName(directives, 'DirectiveA');
      {
        final exportAs = directive.exportAs;
        expect(exportAs.name, 'export-name');
        expect(exportAs.nameOffset, code.indexOf('export-name'));
      }
    }
    {
      final directive = getDirectiveByName(directives, 'DirectiveB');
      {
        final exportAs = directive.exportAs;
        expect(exportAs, isNull);
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_exportAs_hasError_notStringValue() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', exportAs: 42, template:'')
class ComponentA {
}
''');
    await getDirectives(source);
    expect(directives, hasLength(1));
    // has an error
    errorListener.assertErrorsWithCodes(<ErrorCode>[
      AngularWarningCode.STRING_VALUE_EXPECTED,
      StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_exportAs_constantStringExpressionOk() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', exportAs: 'a' + 'b', template:'')
class ComponentA {
}
''');
    await getDirectives(source);
    expect(directives, hasLength(1));
    // has no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_ArgumentSelectorMissing() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(template:'')
class ComponentA {
}
''');
    await getDirectives(source);
    // validate
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.ARGUMENT_SELECTOR_MISSING]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_CannotParseSelector() async {
    final code = r'''
import 'package:angular2/angular2.dart';
@Component(selector: 'a+bad selector', template: '')
class ComponentA {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.CANNOT_PARSE_SELECTOR, code, "+");
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_selector_notStringValue() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 55, template: '')
class ComponentA {
}
''');
    await getDirectives(source);
    // validate
    errorListener.assertErrorsWithCodes(<ErrorCode>[
      AngularWarningCode.STRING_VALUE_EXPECTED,
      StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_selector_constantExpressionOk() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'a' + '[b]', template: '')
class ComponentA {
}
''');
    await getDirectives(source);
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_UndefinedSetter_fullSyntax() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', inputs: const ['noSetter: no-setter'], template: '')
class ComponentA {
}
''');
    await getDirectives(source);
    final component = directives.single;
    final inputs = component.inputs;
    // the bad input should NOT show up, it is not usable see github #183
    expect(inputs, hasLength(0));
    // validate
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[StaticTypeWarningCode.UNDEFINED_SETTER]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_UndefinedSetter_shortSyntax() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', inputs: const ['noSetter'], template: '')
class ComponentA {
}
''');
    await getDirectives(source);
    // validate
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[StaticTypeWarningCode.UNDEFINED_SETTER]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_UndefinedSetter_shortSyntax_noInputMade() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', inputs: const ['noSetter'], template: '')
class ComponentA {
}
''');
    await getDirectives(source);
    final component = directives.single;
    final inputs = component.inputs;
    // the bad input should NOT show up, it is not usable see github #183
    expect(inputs, hasLength(0));
    // validate
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[StaticTypeWarningCode.UNDEFINED_SETTER]);
  }

  // ignore: non_constant_identifier_names
  Future test_inputs() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(
    selector: 'my-component',
    template: '<p></p>',
    inputs: const ['leadingText', 'trailingText: tailText'])
class MyComponent {
  String leadingText;
  int trailingText;
  @Input()
  bool firstField;
  @Input('secondInput')
  String secondField;
  @Input()
  set someSetter(String x) { }
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final inputs = component.inputs;
    expect(inputs, hasLength(5));
    {
      final input = inputs[0];
      expect(input.name, 'leadingText');
      expect(input.nameOffset, code.indexOf("leadingText',"));
      expect(input.setterRange.offset, input.nameOffset);
      expect(input.setterRange.length, 'leadingText'.length);
      expect(input.setter, isNotNull);
      expect(input.setter.isSetter, isTrue);
      expect(input.setter.displayName, 'leadingText');
      expect(input.setterType.toString(), equals("String"));
    }
    {
      final input = inputs[1];
      expect(input.name, 'tailText');
      expect(input.nameOffset, code.indexOf("tailText']"));
      expect(input.setterRange.offset, code.indexOf("trailingText: "));
      expect(input.setterRange.length, 'trailingText'.length);
      expect(input.setter, isNotNull);
      expect(input.setter.isSetter, isTrue);
      expect(input.setter.displayName, 'trailingText');
      expect(input.setterType.toString(), equals("int"));
    }
    {
      final input = inputs[2];
      expect(input.name, 'firstField');
      expect(input.nameOffset, code.indexOf('firstField'));
      expect(input.nameLength, 'firstField'.length);
      expect(input.setterRange.offset, input.nameOffset);
      expect(input.setterRange.length, input.name.length);
      expect(input.setter, isNotNull);
      expect(input.setter.isSetter, isTrue);
      expect(input.setter.displayName, 'firstField');
      expect(input.setterType.toString(), equals("bool"));
    }
    {
      final input = inputs[3];
      expect(input.name, 'secondInput');
      expect(input.nameOffset, code.indexOf('secondInput'));
      expect(input.setterRange.offset, code.indexOf('secondField'));
      expect(input.setterRange.length, 'secondField'.length);
      expect(input.setter, isNotNull);
      expect(input.setter.isSetter, isTrue);
      expect(input.setter.displayName, 'secondField');
      expect(input.setterType.toString(), equals("String"));
    }
    {
      final input = inputs[4];
      expect(input.name, 'someSetter');
      expect(input.nameOffset, code.indexOf('someSetter'));
      expect(input.setterRange.offset, input.nameOffset);
      expect(input.setterRange.length, input.name.length);
      expect(input.setter, isNotNull);
      expect(input.setter.isSetter, isTrue);
      expect(input.setter.displayName, 'someSetter');
      expect(input.setterType.toString(), equals("String"));
    }

    // assert no syntax errors, etc
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_inputs_deprecatedProperties() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(
    selector: 'my-component',
    template: '<p></p>',
    properties: const ['leadingText', 'trailingText: tailText'])
class MyComponent {
  String leadingText;
  String trailingText;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final inputs = component.inputs;
    expect(inputs, hasLength(2));
    {
      final input = inputs[0];
      expect(input.name, 'leadingText');
      expect(input.nameOffset, code.indexOf("leadingText',"));
      expect(input.setterRange.offset, input.nameOffset);
      expect(input.setterRange.length, 'leadingText'.length);
      expect(input.setter, isNotNull);
      expect(input.setter.isSetter, isTrue);
      expect(input.setter.displayName, 'leadingText');
    }
    {
      final input = inputs[1];
      expect(input.name, 'tailText');
      expect(input.nameOffset, code.indexOf("tailText']"));
      expect(input.setterRange.offset, code.indexOf("trailingText: "));
      expect(input.setterRange.length, 'trailingText'.length);
      expect(input.setter, isNotNull);
      expect(input.setter.isSetter, isTrue);
      expect(input.setter.displayName, 'trailingText');
    }
  }

  // ignore: non_constant_identifier_names
  Future test_outputs() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(
    selector: 'my-component',
    template: '<p></p>',
    outputs: const ['outputOne', 'secondOutput: outputTwo'])
class MyComponent {
  EventEmitter<MyComponent> outputOne;
  EventEmitter<String> secondOutput;
  @Output()
  EventEmitter<int> outputThree;
  @Output('outputFour')
  EventEmitter fourthOutput;
  @Output()
  EventEmitter get someGetter => null;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(5));
    {
      final output = compOutputs[0];
      expect(output.name, 'outputOne');
      expect(output.nameOffset, code.indexOf("outputOne"));
      expect(output.getterRange.offset, output.nameOffset);
      expect(output.getterRange.length, 'outputOne'.length);
      expect(output.getter, isNotNull);
      expect(output.getter.isGetter, isTrue);
      expect(output.getter.displayName, 'outputOne');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("MyComponent"));
    }
    {
      final output = compOutputs[1];
      expect(output.name, 'outputTwo');
      expect(output.nameOffset, code.indexOf("outputTwo']"));
      expect(output.getterRange.offset, code.indexOf("secondOutput: "));
      expect(output.getterRange.length, 'secondOutput'.length);
      expect(output.getter, isNotNull);
      expect(output.getter.isGetter, isTrue);
      expect(output.getter.displayName, 'secondOutput');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("String"));
    }
    {
      final output = compOutputs[2];
      expect(output.name, 'outputThree');
      expect(output.nameOffset, code.indexOf('outputThree'));
      expect(output.nameLength, 'outputThree'.length);
      expect(output.getterRange.offset, output.nameOffset);
      expect(output.getterRange.length, output.nameLength);
      expect(output.getter, isNotNull);
      expect(output.getter.isGetter, isTrue);
      expect(output.getter.displayName, 'outputThree');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("int"));
    }
    {
      final output = compOutputs[3];
      expect(output.name, 'outputFour');
      expect(output.nameOffset, code.indexOf('outputFour'));
      expect(output.getterRange.offset, code.indexOf('fourthOutput'));
      expect(output.getterRange.length, 'fourthOutput'.length);
      expect(output.getter, isNotNull);
      expect(output.getter.isGetter, isTrue);
      expect(output.getter.displayName, 'fourthOutput');
      expect(output.eventType, isNotNull);
      expect(output.eventType.isDynamic, isTrue);
    }
    {
      final output = compOutputs[4];
      expect(output.name, 'someGetter');
      expect(output.nameOffset, code.indexOf('someGetter'));
      expect(output.getterRange.offset, output.nameOffset);
      expect(output.getterRange.length, output.name.length);
      expect(output.getter, isNotNull);
      expect(output.getter.isGetter, isTrue);
      expect(output.getter.displayName, 'someGetter');
      expect(output.eventType, isNotNull);
      expect(output.eventType.isDynamic, isTrue);
    }

    // assert no syntax errors, etc
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_outputs_streamIsOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';
import 'dart:async';

@Component(
    selector: 'my-component',
    template: '<p></p>')
class MyComponent {
  @Output()
  Stream<int> myOutput;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      final output = compOutputs[0];
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("int"));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_outputs_extendStreamIsOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';
import 'dart:async';

abstract class MyStream<T> implements Stream<T> { }

@Component(
    selector: 'my-component',
    template: '<p></p>')
class MyComponent {
  @Output()
  MyStream<int> myOutput;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      final output = compOutputs[0];
      expect(output.eventType, isNotNull);
    }
  }

  // ignore: non_constant_identifier_names
  Future test_outputs_extendStreamSpecializedIsOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';
import 'dart:async';

class MyStream extends Stream<int> { }

@Component(
    selector: 'my-component',
    template: '<p></p>')
class MyComponent {
  @Output()
  MyStream myOutput;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      final output = compOutputs[0];
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("int"));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_outputs_extendStreamUntypedIsOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';
import 'dart:async';

class MyStream extends Stream { }

@Component(
    selector: 'my-component',
    template: '<p></p>')
class MyComponent {
  @Output()
  MyStream myOutput;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      final output = compOutputs[0];
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("dynamic"));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_outputs_notEventEmitterTypeError() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(
    selector: 'my-component',
    template: '<p></p>')
class MyComponent {
  @Output()
  int badOutput;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_MUST_BE_STREAM, code, "badOutput");
  }

  // ignore: non_constant_identifier_names
  Future test_outputs_extendStreamNotStreamHasDynamicEventType() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(
    selector: 'my-component',
    template: '<p></p>')
class MyComponent {
  @Output()
  int badOutput;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    final component = directives.single;
    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      final output = compOutputs[0];
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("dynamic"));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_parameterizedInputsOutputs() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(
    selector: 'my-component',
    template: '<p></p>')
class MyComponent<T, A extends String, B extends A> {
  @Output() EventEmitter<T> dynamicOutput;
  @Input() T dynamicInput;
  @Output() EventEmitter<A> stringOutput;
  @Input() A stringInput;
  @Output() EventEmitter<B> stringOutput2;
  @Input() B stringInput2;
  @Output() EventEmitter<List<B>> listOutput;
  @Input() List<B> listInput;
}

''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    final component = directives.single;
    final compInputs = component.inputs;
    expect(compInputs, hasLength(4));
    {
      final input = compInputs[0];
      expect(input.name, 'dynamicInput');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("dynamic"));
    }
    {
      final input = compInputs[1];
      expect(input.name, 'stringInput');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("String"));
    }
    {
      final input = compInputs[2];
      expect(input.name, 'stringInput2');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("String"));
    }
    {
      final input = compInputs[3];
      expect(input.name, 'listInput');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("List<String>"));
    }

    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(4));
    {
      final output = compOutputs[0];
      expect(output.name, 'dynamicOutput');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("dynamic"));
    }
    {
      final output = compOutputs[1];
      expect(output.name, 'stringOutput');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("String"));
    }
    {
      final output = compOutputs[2];
      expect(output.name, 'stringOutput2');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("String"));
    }
    {
      final output = compOutputs[3];
      expect(output.name, 'listOutput');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("List<String>"));
    }

    // assert no syntax errors, etc
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_finalPropertyInputError() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '<p></p>')
class MyComponent {
  @Input() final int immutable = 1;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_ANNOTATION_PLACEMENT_INVALID,
        code,
        "@Input()");
  }

  // ignore: non_constant_identifier_names
  Future test_finalPropertyInputErrorNonDirective() async {
    final code = r'''
import 'package:angular2/angular2.dart';

class MyNonDirective {
  @Input() final int immutable = 1;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_ANNOTATION_PLACEMENT_INVALID,
        code,
        "@Input()");
  }

  // ignore: non_constant_identifier_names
  Future test_finalPropertyInputStringError() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '<p></p>', inputs: const ['immutable'])
class MyComponent {
  final int immutable = 1;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate. Can't easily assert position though because its all 'immutable'
    errorListener
        .assertErrorsWithCodes([StaticTypeWarningCode.UNDEFINED_SETTER]);
  }

  // ignore: non_constant_identifier_names
  Future test_noDirectives() async {
    final source = newSource('/test.dart', r'''
class A {}
class B {}
''');
    await getDirectives(source);
    expect(directives, isEmpty);
  }

  // ignore: non_constant_identifier_names
  Future test_inputOnGetterIsError() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class MyComponent {
  @Input()
  String get someGetter => null;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_ANNOTATION_PLACEMENT_INVALID,
        code,
        "@Input()");
  }

  // ignore: non_constant_identifier_names
  Future test_outputOnSetterIsError() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class MyComponent {
  @Output()
  set someSetter(x) { }
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_ANNOTATION_PLACEMENT_INVALID,
        code,
        "@Output()");
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildDirective() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ContentChildComp)
  ContentChildComp contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.first;
    final childFields = component.contentChildFields;
    expect(childFields, hasLength(1));
    final child = childFields.first;
    expect(child.fieldName, equals("contentChild"));
    expect(child.nameRange.offset, equals(code.indexOf("ContentChildComp)")));
    expect(child.nameRange.length, equals("ContentChildComp".length));
    expect(child.typeRange.offset, equals(code.indexOf("ContentChildComp ")));
    expect(child.typeRange.length, equals("ContentChildComp".length));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  List<ContentChildComp> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.first;
    final childrenFields = component.contentChildrenFields;
    expect(childrenFields, hasLength(1));
    final children = childrenFields.first;
    expect(children.fieldName, equals("contentChildren"));
    expect(
        children.nameRange.offset, equals(code.indexOf("ContentChildComp)")));
    expect(children.nameRange.length, equals("ContentChildComp".length));
    expect(children.typeRange.offset,
        equals(code.indexOf("List<ContentChildComp>")));
    expect(children.typeRange.length, equals("List<ContentChildComp>".length));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective_QueryList() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  QueryList<ContentChildComp> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.first;
    final childrenFields = component.contentChildrenFields;
    expect(childrenFields, hasLength(1));
    final children = childrenFields.first;
    expect(children.fieldName, equals("contentChildren"));
    expect(
        children.nameRange.offset, equals(code.indexOf("ContentChildComp)")));
    expect(children.nameRange.length, equals("ContentChildComp".length));
    expect(children.typeRange.offset,
        equals(code.indexOf("QueryList<ContentChildComp>")));
    expect(children.typeRange.length,
        equals("QueryList<ContentChildComp>".length));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildChildrenNoRangeNotRecorded() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren()
  List<ContentChildComp> contentChildren;
  @ContentChild()
  ContentChildComp contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.first;
    final childrenFields = component.contentChildrenFields;
    expect(childrenFields, hasLength(0));
    final childFields = component.contentChildFields;
    expect(childFields, hasLength(0));
    // validate
    errorListener.assertErrorsWithCodes([
      CompileTimeErrorCode.NOT_ENOUGH_REQUIRED_ARGUMENTS,
      CompileTimeErrorCode.NOT_ENOUGH_REQUIRED_ARGUMENTS
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildChildrenSetter() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ContentChildComp) // 1
  void set contentChild(ContentChildComp contentChild) => null;
  @ContentChildren(ContentChildComp) // 2
  void set contentChildren(List<ContentChildComp> contentChildren) => null;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.first;

    final childFields = component.contentChildFields;
    expect(childFields, hasLength(1));
    final child = childFields.first;
    expect(child.fieldName, equals("contentChild"));
    expect(
        child.nameRange.offset, equals(code.indexOf("ContentChildComp) // 1")));
    expect(child.nameRange.length, equals("ContentChildComp".length));
    expect(child.typeRange.offset, equals(code.indexOf("ContentChildComp ")));
    expect(child.typeRange.length, equals("ContentChildComp".length));

    final childrenFields = component.contentChildrenFields;
    expect(childrenFields, hasLength(1));
    final children = childrenFields.first;
    expect(children.fieldName, equals("contentChildren"));
    expect(children.nameRange.offset,
        equals(code.indexOf("ContentChildComp) // 2")));
    expect(children.nameRange.length, equals("ContentChildComp".length));
    expect(children.typeRange.offset,
        equals(code.indexOf("List<ContentChildComp>")));
    expect(children.typeRange.length, equals("List<ContentChildComp>".length));

    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasExports() async {
    final code = r'''
import 'package:angular2/angular2.dart';

const foo = null;
void bar() {}
class MyClass {}

@Component(selector: 'my-component', template: '',
    exports: const [foo, bar, MyClass])
class ComponentA {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final Component component = directives.first;
    expect(component.view, isNotNull);
    expect(component.view.exports, hasLength(3));
    {
      final export = component.view.exports[0];
      expect(export.identifier, equals('foo'));
      expect(export.prefix, equals(''));
      expect(export.span.offset, equals(code.indexOf('foo,')));
      expect(export.span.length, equals('foo'.length));
      expect(export.element, isNull); // not yet linked
    }
    {
      final export = component.view.exports[1];
      expect(export.identifier, equals('bar'));
      expect(export.prefix, equals(''));
      expect(export.span.offset, equals(code.indexOf('bar,')));
      expect(export.span.length, equals('bar'.length));
      expect(export.element, isNull); // not yet linked
    }
    {
      final export = component.view.exports[2];
      expect(export.identifier, equals('MyClass'));
      expect(export.prefix, equals(''));
      expect(export.span.offset, equals(code.indexOf('MyClass]')));
      expect(export.span.length, equals('MyClass'.length));
      expect(export.element, isNull); // not yet linked
    }
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_prefixedExport() async {
    newSource('/prefixed.dart', 'const foo = null;');
    final code = r'''
import 'package:angular2/angular2.dart';
import '/prefixed.dart' as prefixed;

const foo = null;

@Component(selector: 'my-component', template: '',
    exports: const [prefixed.foo, foo])
class ComponentA {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final Component component = directives.first;
    expect(component.view, isNotNull);
    expect(component.view.exports, hasLength(2));
    {
      final export = component.view.exports[0];
      expect(export.identifier, equals('foo'));
      expect(export.prefix, equals('prefixed'));
      expect(export.span.offset, equals(code.indexOf('prefixed.foo')));
      expect(export.span.length, equals('prefixed.foo'.length));
      expect(export.element, isNull); // not yet linked
    }
    {
      final export = component.view.exports[1];
      expect(export.identifier, equals('foo'));
      expect(export.prefix, equals(''));
      expect(export.span.offset, equals(code.indexOf('foo]')));
      expect(export.span.length, equals('foo'.length));
      expect(export.element, isNull); // not yet linked
    }

    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasNonIdentifierExport() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '', exports: const [1])
class ComponentA {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.EXPORTS_MUST_BE_PLAIN_IDENTIFIERS, code, '1');
  }

  // ignore: non_constant_identifier_names
  Future test_hasRepeatedExports() async {
    final code = r'''
import 'package:angular2/angular2.dart';

const foo = null;

@Component(selector: 'my-component', template: '', exports: const [foo, foo])
class ComponentA {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate. Can't validate position because foo occurs so many times
    errorListener.assertErrorsWithCodes([AngularWarningCode.DUPLICATE_EXPORT]);
  }
}

@reflectiveTest
class GatherAnnotationsOnFutureAngularTest extends AbstractAngularTest
    with GatherAnnotationsTestMixin {
  GatherAnnotationsOnFutureAngularTest() : super.future();

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective_worksInFuture() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  List<ContentChildComp> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.first;
    final childrenFields = component.contentChildrenFields;
    expect(childrenFields, hasLength(1));
    final children = childrenFields.first;
    expect(children.fieldName, equals("contentChildren"));
    expect(
        children.nameRange.offset, equals(code.indexOf("ContentChildComp)")));
    expect(children.nameRange.length, equals("ContentChildComp".length));
    expect(children.typeRange.offset,
        equals(code.indexOf("List<ContentChildComp>")));
    expect(children.typeRange.length, equals("List<ContentChildComp>".length));
    // validate
    errorListener.assertNoErrors();
  }
}

@reflectiveTest
class BuildUnitViewsTest extends AbstractAngularTest {
  List<AbstractDirective> directives;
  List<Pipe> pipes;
  List<View> views;
  List<AnalysisError> errors;

  Future getViews(final Source source) async {
    final dartResult = await dartDriver.getResult(source.fullName);
    fillErrorListener(dartResult.errors);
    final result = await angularDriver.getAngularTopLevels(source.fullName);
    directives = result.directives;
    pipes = result.pipes;

    final linker = new ChildDirectiveLinker(
        angularDriver,
        angularDriver,
        await angularDriver.getStandardAngular(),
        await angularDriver.getStandardHtml(),
        new ErrorReporter(errorListener, source));
    await linker.linkDirectivesAndPipes(
        directives, pipes, dartResult.unit.element.library);
    views = directives
        .map((d) => d is Component ? d.view : null)
        .where((d) => d != null)
        .toList();
    errors = result.errors;
    fillErrorListener(errors);
  }

  // ignore: non_constant_identifier_names
  Future test_buildViewsDoesntGetDependentDirectives() async {
    final code = r'''
import 'package:angular2/angular2.dart';
import 'other_file.dart';

@Component(selector: 'my-component', template: 'My template',
    directives: const [OtherComponent])
class MyComponent {}
''';
    final otherCode = r'''
import 'package:angular2/angular2.dart';
@Component(selector: 'other-component', template: 'My template',
    directives: const [NgFor])
class OtherComponent {}
''';
    final source = newSource('/test.dart', code);
    newSource('/other_file.dart', otherCode);
    await getViews(source);
    {
      final view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.directives, hasLength(1));
      }

      // shouldn't be run yet
      for (final directive in view.directives) {
        if (directive is Component) {
          expect(directive.view.directives, hasLength(0));
        }
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_directives() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: '[aaa]')
class DirectiveA {}

@Directive(selector: '[bbb]')
class DirectiveB {}

@Directive(selector: '[ccc]')
class DirectiveC {}

const DIR_AB = const [DirectiveA, DirectiveB];

@Component(selector: 'my-component', template: 'My template',
    directives: const [DIR_AB, DirectiveC])
class MyComponent {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    {
      final view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.directives, hasLength(3));
        final directiveClassNames =
            view.directives.map((directive) => directive.name).toList();
        expect(directiveClassNames,
            unorderedEquals(['DirectiveA', 'DirectiveB', 'DirectiveC']));
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_directives_not_list_syntax() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: '[aaa]')
class DirectiveA {}

@Directive(selector: '[bbb]')
class DirectiveB {}

const VARIABLE = const [DirectiveA, DirectiveB];

@Component(selector: 'my-component', template: 'My template',
    directives: VARIABLE)
class MyComponent {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final view = getViewByClassName(views, 'MyComponent');
    expect(
        view.directivesStrategy, const isInstanceOf<UseConstValueStrategy>());
    final directiveClassNames =
        view.directives.map((directive) => directive.name).toList();
    expect(directiveClassNames, unorderedEquals(['DirectiveA', 'DirectiveB']));
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_directives_not_list_syntax_errorWithinVariable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: 'My template',
    directives: VARIABLE)
class MyComponent {}

// A non-array is a type error in the analyzer; a non-component in an array is
// not so we must test it. Define below usage for asserting position.
const VARIABLE = const [Object];
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final view = getViewByClassName(views, 'MyComponent');
    expect(
        view.directivesStrategy, const isInstanceOf<UseConstValueStrategy>());
    assertErrorInCodeAtPosition(
        AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE, code, 'VARIABLE');
  }

  // ignore: non_constant_identifier_names
  Future test_prefixedDirectives() async {
    final otherCode = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: '[aaa]')
class DirectiveA {}

@Directive(selector: '[bbb]')
class DirectiveB {}

@Directive(selector: '[ccc]')
class DirectiveC {}

const DIR_AB = const [DirectiveA, DirectiveB];
''';

    final code = r'''
import 'package:angular2/angular2.dart';
import 'other.dart' as other;

@Component(selector: 'my-component', template: 'My template',
    directives: const [other.DIR_AB, other.DirectiveC])
class MyComponent {}
''';
    final source = newSource('/test.dart', code);
    newSource('/other.dart', otherCode);
    await getViews(source);
    {
      final view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.directives, hasLength(3));
        final directiveClassNames =
            view.directives.map((directive) => directive.name).toList();
        expect(directiveClassNames,
            unorderedEquals(['DirectiveA', 'DirectiveB', 'DirectiveC']));
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_recursiveDirectivesList() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: '[aaa]')
class DirectiveA {}

@Directive(selector: '[bbb]')
class DirectiveB {}

const DIR_AB_DEEP = const [ const [ const [DirectiveA, DirectiveB]]];

@Component(selector: 'my-component', template: 'My template',
    directives: const [DIR_AB_DEEP])
class MyComponent {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    {
      final view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.directives, hasLength(2));
        final directiveClassNames =
            view.directives.map((directive) => directive.name).toList();
        expect(
            directiveClassNames, unorderedEquals(['DirectiveA', 'DirectiveB']));
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_validFunctionalDirectivesList() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: '[aaa]')
void directiveA() {}

@Directive(selector: '[bbb]')
void directiveB() {}

const DIR_AB_DEEP = const [ const [ const [directiveA, directiveB]]];

@Component(selector: 'my-component', template: 'My template',
    directives: const [DIR_AB_DEEP])
class MyComponent {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    errorListener.assertNoErrors();
    {
      final view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.directives, hasLength(2));
        final directiveNames =
            view.directives.map((directive) => directive.name).toList();
        expect(directiveNames, unorderedEquals(['directiveA', 'directiveB']));
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_directivesList_invalidDirectiveEntries() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: '[aaa]')
class DirectiveA {}

@Directive(selector: '[bbb]')
void directiveB() {}

void notADirective() {}
class NotADirectiveEither {}

const DIR_AB_DEEP = const [ const [ const [
    DirectiveA, directiveB, notADirective, NotADirectiveEither]]];

@Component(selector: 'my-component', template: 'My template',
    directives: const [DIR_AB_DEEP])
class MyComponent {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    {
      final view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.directives, hasLength(2));
        final directiveNames =
            view.directives.map((directive) => directive.name).toList();
        expect(directiveNames, unorderedEquals(['DirectiveA', 'directiveB']));
      }
    }

    errorListener.assertErrorsWithCodes([
      AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE,
      AngularWarningCode.FUNCTION_IS_NOT_A_DIRECTIVE
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_directives_hasError_notListVariable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

const NOT_DIRECTIVE_LIST = 42;

@Component(selector: 'my-component', template: 'My template',
   directives: const [NOT_DIRECTIVE_LIST])
class MyComponent {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_StringValueExpected() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', template: 55)
class ComponentA {
}
''');
    await getViews(source);
    errorListener.assertErrorsWithCodes(<ErrorCode>[
      AngularWarningCode.STRING_VALUE_EXPECTED,
      StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_constantExpressionTemplateOk() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', template: 'abc' + 'bcd')
class ComponentA {
}
''');
    await getViews(source);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_constantExpressionTemplateComplexIsOnlyError() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

const String tooComplex = 'bcd';

@Component(selector: 'aaa', template: 'abc' + tooComplex + "{{invalid {{stuff")
class ComponentA {
}
''');
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularHintCode.OFFSETS_CANNOT_BE_CREATED]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_TypeLiteralExpected() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', template: 'AAA', directives: const [42])
class ComponentA {
}
''');
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TYPE_LITERAL_EXPECTED]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_TemplateAndTemplateUrlDefined() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', template: 'AAA', templateUrl: 'a.html')
class ComponentA {
}
''');
    newSource('/a.html', '');
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TEMPLATE_URL_AND_TEMPLATE_DEFINED]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_NeitherTemplateNorTemplateUrlDefined() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa')
class ComponentA {
}
''');
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.NO_TEMPLATE_URL_OR_TEMPLATE_DEFINED]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_missingHtmlFile() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', templateUrl: 'missing-template.html')
class MyComponent {}
''';
    final dartSource = newSource('/test.dart', code);
    await getViews(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.REFERENCED_HTML_FILE_DOESNT_EXIST,
        code,
        "'missing-template.html'");
  }

  // ignore: non_constant_identifier_names
  Future test_templateExternal() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', templateUrl: 'my-template.html')
class MyComponent {}
''';
    final dartSource = newSource('/test.dart', code);
    final htmlSource = newSource('/my-template.html', '');
    await getViews(dartSource);
    expect(views, hasLength(1));
    // MyComponent
    final view = getViewByClassName(views, 'MyComponent');
    expect(view.component, getComponentByName(directives, 'MyComponent'));
    expect(view.templateText, isNull);
    expect(view.templateUriSource, isNotNull);
    expect(view.templateUriSource, htmlSource);
    expect(view.templateSource, htmlSource);
    {
      final url = "'my-template.html'";
      expect(view.templateUrlRange,
          new SourceRange(code.indexOf(url), url.length));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_templateInline() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: 'my-directive')
class MyDirective {}

@Component(selector: 'other-component', template: 'Other template')
class OtherComponent {}

@Component(selector: 'my-component', template: 'My template',
    directives: const [MyDirective, OtherComponent])
class MyComponent {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    expect(views, hasLength(2));
    {
      final view = getViewByClassName(views, 'MyComponent');
      expect(view.component, getComponentByName(directives, 'MyComponent'));
      expect(view.templateText, ' My template '); // spaces preserve offsets
      expect(view.templateOffset, code.indexOf('My template') - 1);
      expect(view.templateUriSource, isNull);
      expect(view.templateSource, source);
      {
        expect(view.directives, hasLength(2));
        final directiveClassNames =
            view.directives.map((directive) => directive.name).toList();
        expect(directiveClassNames,
            unorderedEquals(['OtherComponent', 'MyDirective']));
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_template_relativeToLibForParts() async {
    final libCode = r'''
import 'package:angular2/angular2.dart';
part 'parts/part.dart';
    ''';
    final partCode = r'''
part of '../lib.dart';
@Component(selector: 'my-component', templateUrl: 'parts/my-template.html')
class MyComponent {}
''';
    final dartLibSource = newSource('/lib.dart', libCode);
    final dartPartSource = newSource('/parts/part.dart', partCode);
    final htmlSource = newSource('/parts/my-template.html', '');
    await getViews(dartPartSource);
    errorListener.assertNoErrors();
    expect(views, hasLength(1));
    // MyComponent
    final view = getViewByClassName(views, 'MyComponent');
    expect(view.component, getComponentByName(directives, 'MyComponent'));
    expect(view.templateText, isNull);
    expect(view.templateUriSource, isNotNull);
    expect(view.templateUriSource, htmlSource);
    expect(view.templateSource, htmlSource);
    {
      final url = "'parts/my-template.html'";
      expect(view.templateUrlRange,
          new SourceRange(partCode.indexOf(url), url.length));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_useFunctionalDirective() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: 'my-directive')
void myDirective() {}

@Component(selector: 'my-component', template: 'My template',
    directives: const [myDirective])
class MyComponent {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    errorListener.assertNoErrors();
    expect(views, hasLength(1));
    final view = views.single;
    expect(view.component.name, 'MyComponent');
    expect(view.directives, hasLength(1));
    final directive = view.directives.single;
    expect(directive.name, 'myDirective');
    expect(directive, const isInstanceOf<FunctionalDirective>());
  }

  // ignore: non_constant_identifier_names
  Future test_useFunctionNotFunctionalDirective() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: 'My template',
    directives: const [notDirective])
class MyComponent {}

// put this after component, so indexOf works in assertErrorInCodeAtPosition
void notDirective() {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    assertErrorInCodeAtPosition(
        AngularWarningCode.FUNCTION_IS_NOT_A_DIRECTIVE, code, 'notDirective');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildComponent() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ContentChildComp)
  ContentChildComp contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType child = childs.first.query;

    expect(child.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  List<ContentChildComp> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildChildrenSetter() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ContentChildComp) // 1
  void set contentChild(ContentChildComp contentChild) => null;
  @ContentChildren(ContentChildComp) // 2
  void set contentChildren(List<ContentChildComp> contentChildren) => null;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;

    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));

    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType child = childs.first.query;

    expect(child.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildLetBound() async {
    final code = r'''
import 'dart:html';
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild('foo')
  ContentChildComp contentChildDirective;
  @ContentChild('fooTpl')
  TemplateRef contentChildTpl;
  @ContentChild('fooElemRef')
  ElementRef contentChildElemRef;
  @ContentChild('fooElem', read: Element)
  Element contentChildElem;
  @ContentChild('fooHtmlElem', read: HtmlElement)
  HtmlElement contentChildHtmlElem;
  @ContentChild('fooDynamic')
  dynamic contentChildDynamic;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(6));

    final LetBoundQueriedChildType childDirective = childs
        .singleWhere((c) => c.field.fieldName == "contentChildDirective")
        .query;
    expect(childDirective, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childDirective.letBoundName, equals("foo"));
    expect(childDirective.containerType.toString(), equals("ContentChildComp"));

    final LetBoundQueriedChildType childTemplate =
        childs.singleWhere((c) => c.field.fieldName == "contentChildTpl").query;
    expect(childTemplate, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childTemplate.letBoundName, equals("fooTpl"));
    expect(childTemplate.containerType.toString(), equals("TemplateRef"));

    final LetBoundQueriedChildType childElement = childs
        .singleWhere((c) => c.field.fieldName == "contentChildElem")
        .query;
    expect(childElement, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childElement.letBoundName, equals("fooElem"));
    expect(childElement.containerType.toString(), equals("Element"));

    final LetBoundQueriedChildType childHtmlElement = childs
        .singleWhere((c) => c.field.fieldName == "contentChildHtmlElem")
        .query;
    expect(childHtmlElement, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childHtmlElement.letBoundName, equals("fooHtmlElem"));
    expect(childHtmlElement.containerType.toString(), equals("HtmlElement"));

    final LetBoundQueriedChildType childElementRef = childs
        .singleWhere((c) => c.field.fieldName == "contentChildElemRef")
        .query;
    expect(childElementRef, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childElementRef.letBoundName, equals("fooElemRef"));
    expect(childElementRef.containerType.toString(), equals("ElementRef"));

    final LetBoundQueriedChildType childDynamic = childs
        .singleWhere((c) => c.field.fieldName == "contentChildDynamic")
        .query;
    expect(childDynamic, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childDynamic.letBoundName, equals("fooDynamic"));
    expect(childDynamic.containerType.toString(), equals("dynamic"));

    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenLetBound() async {
    final code = r'''
import 'dart:html';
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren('foo')
  List<ContentChildComp> contentChildDirective;
  @ContentChildren('fooTpl')
  List<TemplateRef> contentChildTpl;
  @ContentChildren('fooElem', read: Element)
  List<Element> contentChildElem;
  @ContentChildren('fooHtmlElem', read: HtmlElement)
  List<HtmlElement> contentChildHtmlElem;
  @ContentChildren('fooElemRef')
  List<ElementRef> contentChildElemRef;
  @ContentChildren('fooDynamic')
  List contentChildDynamic;
  @ContentChildren('fooQueryList')
  QueryList<ContentChildComp> contentChildQueryList;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(7));

    final LetBoundQueriedChildType childrenDirective = childrens
        .singleWhere((c) => c.field.fieldName == "contentChildDirective")
        .query;
    expect(childrenDirective, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childrenDirective.letBoundName, equals("foo"));
    expect(
        childrenDirective.containerType.toString(), equals("ContentChildComp"));

    final LetBoundQueriedChildType childrenTemplate = childrens
        .singleWhere((c) => c.field.fieldName == "contentChildTpl")
        .query;
    expect(childrenTemplate, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childrenTemplate.letBoundName, equals("fooTpl"));
    expect(childrenTemplate.containerType.toString(), equals("TemplateRef"));

    final LetBoundQueriedChildType childrenElement = childrens
        .singleWhere((c) => c.field.fieldName == "contentChildElem")
        .query;
    expect(childrenElement, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childrenElement.letBoundName, equals("fooElem"));
    expect(childrenElement.containerType.toString(), equals("Element"));

    final LetBoundQueriedChildType childrenHtmlElement = childrens
        .singleWhere((c) => c.field.fieldName == "contentChildHtmlElem")
        .query;
    expect(childrenHtmlElement, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childrenHtmlElement.letBoundName, equals("fooHtmlElem"));
    expect(childrenHtmlElement.containerType.toString(), equals("HtmlElement"));

    final LetBoundQueriedChildType childrenElementRef = childrens
        .singleWhere((c) => c.field.fieldName == "contentChildElemRef")
        .query;
    expect(childrenElementRef, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childrenElementRef.letBoundName, equals("fooElemRef"));
    expect(childrenElementRef.containerType.toString(), equals("ElementRef"));

    final LetBoundQueriedChildType childrenDynamic = childrens
        .singleWhere((c) => c.field.fieldName == "contentChildDynamic")
        .query;
    expect(childrenDynamic, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childrenDynamic.letBoundName, equals("fooDynamic"));
    expect(childrenDynamic.containerType.toString(), equals("dynamic"));

    final LetBoundQueriedChildType childrenQueryList = childrens
        .singleWhere((c) => c.field.fieldName == "contentChildQueryList")
        .query;
    expect(childrenQueryList, const isInstanceOf<LetBoundQueriedChildType>());
    expect(childrenQueryList.letBoundName, equals("fooQueryList"));
    expect(
        childrenQueryList.containerType.toString(), equals("ContentChildComp"));

    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenLetBound_elementWithoutReadError() async {
    final code = r'''
import 'dart:html';
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren('el') // missing read: Element
  List<Element> contentChildrenElem;
  @ContentChild('el') // missing read: Element
  Element contentChildElem;
  @ContentChild('el') // missing read: HtmlElement
  HtmlElement contentChildHtmlElem;
  @ContentChildren('el') // missing read: HtmlElement
  List<HtmlElement> contentChildrenHtmlElem;
  @ContentChildren('el', read: Element) // not HtmlElement
  List<HtmlElement> contentChildrenNotHtmlElem;
  @ContentChild('el', read: Element) // not HtmlElement
  HtmlElement contentChildNotHtmlElem;
}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);

    errorListener.assertErrorsWithCodes([
      AngularWarningCode.CHILD_QUERY_TYPE_REQUIRES_READ,
      AngularWarningCode.CHILD_QUERY_TYPE_REQUIRES_READ,
      AngularWarningCode.CHILD_QUERY_TYPE_REQUIRES_READ,
      AngularWarningCode.CHILD_QUERY_TYPE_REQUIRES_READ,
      AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
      AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenLetBound_elementReadDoesntMatchType() async {
    final code = r'''
import 'dart:html';
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild('el', read: Element)
  ElementRef elemRefNotElem;
  @ContentChild('el', read: HtmlElement)
  ElementRef elemRefNotHtmlElem;
  @ContentChild('el', read: Element)
  HtmlElement htmlElemNotElem;
}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);

    errorListener.assertErrorsWithCodes([
      AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
      AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
      AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenLetBound_readSubtypeOfAttribute() async {
    final code = r'''
import 'dart:html';
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild('el', read: Element)
  Object objectNotElem;
  @ContentChild('el', read: HtmlElement)
  Element elemNotHtmlElem;
  @ContentChild('el', read: HtmlElement)
  Object objectNotHtmlElem;
}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final children = component.contentChilds;
    expect(children, hasLength(3));

    final LetBoundQueriedChildType objectNotElem =
        children.singleWhere((c) => c.field.fieldName == 'objectNotElem').query;
    expect(objectNotElem, const isInstanceOf<LetBoundQueriedChildType>());
    expect(objectNotElem.letBoundName, equals('el'));
    expect(objectNotElem.containerType.toString(), equals('Element'));

    final LetBoundQueriedChildType elemNotHtmlElem = children
        .singleWhere((c) => c.field.fieldName == 'elemNotHtmlElem')
        .query;
    expect(elemNotHtmlElem, const isInstanceOf<LetBoundQueriedChildType>());
    expect(elemNotHtmlElem.letBoundName, equals('el'));
    expect(elemNotHtmlElem.containerType.toString(), equals('HtmlElement'));

    final LetBoundQueriedChildType objectNotHtmlElem = children
        .singleWhere((c) => c.field.fieldName == 'objectNotHtmlElem')
        .query;
    expect(objectNotHtmlElem, const isInstanceOf<LetBoundQueriedChildType>());
    expect(objectNotHtmlElem.letBoundName, equals('el'));
    expect(objectNotHtmlElem.containerType.toString(), equals('HtmlElement'));

    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildElementRef() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ElementRef)
  ElementRef contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, const isInstanceOf<ElementQueriedChildType>());

    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenElementRef() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ElementRef)
  List<ElementRef> contentChildren;
}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, const isInstanceOf<ElementQueriedChildType>());

    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenTemplateRef() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(TemplateRef)
  List<TemplateRef> contentChildren;
}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(childrens.first.query,
        const isInstanceOf<TemplateRefQueriedChildType>());

    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildTemplateRef() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(TemplateRef)
  TemplateRef contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(
        childs.first.query, const isInstanceOf<TemplateRefQueriedChildType>());

    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildDirective_notRecognizedType() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(String)
  ElementRef contentChild;
}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(0));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNKNOWN_CHILD_QUERY_TYPE, code, 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildDirective_htmlNotAllowed() async {
    final code = r'''
import 'package:angular2/angular2.dart';
import 'dart:html';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(AnchorElement)
  AnchorElement contentChild;
}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(0));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNKNOWN_CHILD_QUERY_TYPE, code, 'AnchorElement');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildDirective_notTypeOrString() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(const [])
  ElementRef contentChild;
}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(0));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNKNOWN_CHILD_QUERY_TYPE, code, 'const []');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildDirective_notAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ContentChildComp)
  String contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType child = childs.first.query;
    expect(child.directive, equals(directives[1]));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY, code, 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildDirective_dynamicOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ContentChildComp)
  dynamic contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType child = childs.first.query;

    expect(child.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildDirective_subTypeNotAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ContentChildComp)
  ContentChildCompSub contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}

class ContentChildCompSub extends ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType child = childs.first.query;
    expect(child.directive, equals(directives[1]));

    // validate
    assertErrorInCodeAtPosition(AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
        code, 'ContentChildCompSub');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective_notList() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  String contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;
    expect(children.directive, equals(directives[1]));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_OR_VIEW_CHILDREN_REQUIRES_LIST,
        code,
        'String');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective_dynamicOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  dynamic contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective_notAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  List<String> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY, code, 'List<String>');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective_dynamicListOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  List contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective_iterableOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  Iterable<ContentChildComp> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective_iterableNotAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  Iterable<String> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
        code, 'Iterable<String>');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective_dynamicIterableOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  Iterable contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective_subtypingListNotOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  // this is not allowed. Angular makes a List, regardless of your subtype
  CannotSubtypeList contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}

abstract class CannotSubtypeList extends List {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, const isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;
    expect(children.directive, equals(directives[1]));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_OR_VIEW_CHILDREN_REQUIRES_LIST,
        code,
        'CannotSubtypeList');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildTemplateRef_notAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(TemplateRef)
  String contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY, code, 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenTemplateRef_notAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(TemplateRef)
  List<String> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY, code, 'List<String>');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildElementRef_notAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ElementRef)
  String contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY, code, 'String');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenElementRef_notAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ElementRef)
  List<String> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY, code, 'List<String>');
  }

  // ignore: non_constant_identifier_names
  Future test_hasContentChildrenDirective_withReadSet() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ContentChildComp, read: ViewContainerRef)
  ViewContainerRef contentChild;
  @ContentChildren(ContentChildComp, read: ViewContainerRef)
  List<ViewContainerRef> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(childrens.first.read.toString(), equals('ViewContainerRef'));
    final childs = component.contentChildren;
    expect(childs, hasLength(1));
    expect(childs.first.read.toString(), equals('ViewContainerRef'));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_pipes() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Pipe('pipeA')
class PipeA extends PipeTransform {
  int transform(int blah) => blah;
}

@Pipe('pipeB', pure: false)
class PipeB extends PipeTransform {
  int transform(int blah) => blah;
}

@Component(selector: 'my-component', template: 'MyTemplate',
    pipes: const [PipeA, PipeB])
class MyComponent {}
    ''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    {
      final view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.pipes, hasLength(2));
        final pipeNames =
            view.pipes.map((pipe) => pipe.classElement.name).toList();
        expect(pipeNames, unorderedEquals(['PipeA', 'PipeB']));
      }
    }
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_pipes_selective() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Pipe('pipeA')
class PipeA extends PipeTransform {
  int transform(int blah) => blah;
}

@Pipe('pipeB', pure: false)
class PipeB extends PipeTransform {
  int transform(int blah) => blah;
}

@Pipe('pipeC')
class PipeC extends PipeTransform {
  int transform(int blah) => blah;
}

@Component(selector: 'my-component', template: 'MyTemplate',
    pipes: const [PipeC, PipeB])
class MyComponent {}
    ''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    {
      final view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.pipes, hasLength(2));
        final pipeNames =
            view.pipes.map((pipe) => pipe.classElement.name).toList();
        expect(pipeNames, unorderedEquals(['PipeC', 'PipeB']));
      }
    }
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_pipes_list_recursive() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Pipe('pipeA')
class PipeA extends PipeTransform {
  int transform(int blah) => blah;
}

@Pipe('pipeB', pure: false)
class PipeB extends PipeTransform {
  int transform(int blah) => blah;
}

@Pipe('pipeC')
class PipeC extends PipeTransform {
  int transform(int blah) => blah;
}

@Pipe('pipeD')
class PipeD extends PipeTransform {
  int transform(int blah) => blah;
}

const PIPELIST_ONE = const [ const [PipeA, PipeB]];
const PIPELIST_TWO = const [ const [ const [PipeC, PipeD]]];
const BIGPIPELIST = const [PIPELIST_ONE, PIPELIST_TWO];

@Component(selector: 'my-component', template: 'MyTemplate',
    pipes: const [BIGPIPELIST])
class MyComponent {}
    ''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    {
      final view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.pipes, hasLength(4));
        final pipeNames =
            view.pipes.map((pipe) => pipe.classElement.name).toList();
        expect(
            pipeNames, unorderedEquals(['PipeA', 'PipeB', 'PipeC', 'PipeD']));
      }
    }
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_pipes_hasError_notListVariable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

const NOT_PIPES_LIST = 42;

@Component(selector: 'my-component', template: 'My template',
    pipes: const [NOT_PIPES_LIST])
class MyComponent {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TYPE_IS_NOT_A_PIPE]);
  }

  // ignore: non_constant_identifier_names
  Future test_pipe_hasError_TypeLiteralExpected() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', template: 'AAA', pipes: const [42])
class ComponentA {
}
''');
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TYPE_LITERAL_EXPECTED]);
  }
}

@reflectiveTest
class LinkDirectivesTest extends AbstractAngularTest {
  List<AbstractDirective> directives;
  List<Template> templates;
  List<AnalysisError> errors;

  Future getDirectives(final Source source) async {
    final dartResult = await dartDriver.getResult(source.fullName);
    fillErrorListener(dartResult.errors);
    final ngResult = await angularDriver.requestDartResult(source.fullName);
    directives = ngResult.directives;
    errors = ngResult.errors;
    fillErrorListener(errors);
    templates = directives
        .map((d) => d is Component ? d.view?.template : null)
        .where((d) => d != null)
        .toList();
  }

  // ignore: non_constant_identifier_names
  Future test_inheritMetadata() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'foo', template: '')
class BaseComponent {
  @Input()
  String input;
  @Output()
  EventEmitter<String> output;

  @ViewChild(BaseComponent)
  BaseComponent queryView;
  @ViewChildren(BaseComponent)
  List<BaseComponent> queryListView;
  @ContentChild(BaseComponent)
  BaseComponent queryContent;
  @ContentChildren(BaseComponent)
  List<BaseComponent> queryListContent;

  // TODO host properties & listeners
}

@Component( selector: 'my-component', template: '<p></p>')
class MyComponent extends BaseComponent {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.firstWhere((d) => d.name == 'MyComponent');
    final compInputs = component.inputs;
    expect(compInputs, hasLength(1));
    {
      final input = compInputs[0];
      expect(input.name, 'input');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("String"));
    }

    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      final output = compOutputs[0];
      expect(output.name, 'output');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("String"));
    }

    final compChildrenFields = component.contentChildrenFields;
    expect(compChildrenFields, hasLength(1));
    {
      final children = compChildrenFields[0];
      expect(children.fieldName, 'queryListContent');
    }

    final compChildFields = component.contentChildFields;
    expect(compChildFields, hasLength(1));
    {
      final child = compChildFields[0];
      expect(child.fieldName, 'queryContent');
    }

    // TODO asert viewchild is inherited once that's supported
  }

  // ignore: non_constant_identifier_names
  Future test_inheritMetadataChildDirective() async {
    final childCode = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'foo', template: '')
class BaseComponent {
  @Input()
  String input;
  @Output()
  EventEmitter<String> output;

  @ViewChild(BaseComponent)
  BaseComponent queryView;
  @ViewChildren(BaseComponent)
  List<BaseComponent> queryListView;
  @ContentChild(BaseComponent)
  BaseComponent queryContent;
  @ContentChildren(BaseComponent)
  List<BaseComponent> queryListContent;

  // TODO host properties & listeners
}

@Component( selector: 'child-component', template: '<p></p>')
class ChildComponent extends BaseComponent {
}
''';
    newSource('/child.dart', childCode);

    final code = r'''
import 'package:angular2/angular2.dart';
import 'child.dart';

@Component(selector: 'my-component', template: '<p></p>',
    directives: const [ChildComponent])
class MyComponent {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component =
        (directives.firstWhere((d) => d.name == 'MyComponent') as Component)
            .view
            .directives
            .first;
    final compInputs = component.inputs;
    expect(compInputs, hasLength(1));
    {
      final input = compInputs[0];
      expect(input.name, 'input');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("String"));
    }

    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      final output = compOutputs[0];
      expect(output.name, 'output');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("String"));
    }

    final compChildren = component.contentChildren;
    expect(compChildren, hasLength(1));
    {
      final children = compChildren[0];
      expect(children.field.fieldName, 'queryListContent');
    }

    final compChilds = component.contentChilds;
    expect(compChilds, hasLength(1));
    {
      final child = compChilds[0];
      expect(child.field.fieldName, 'queryContent');
    }

    // TODO asert viewchild is inherited once that's supported
  }

  // ignore: non_constant_identifier_names
  Future test_inheritMetadataInheritanceDeep() async {
    final code = r'''
import 'package:angular2/angular2.dart';

class BaseBaseComponent {
  @Input()
  int someInput;
}

class BaseComponent extends BaseBaseComponent {
}

@Component(selector: 'my-component', template: '<p></p>')
class FinalComponent
   extends BaseComponent {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.firstWhere((d) => d.name == 'FinalComponent');
    final compInputs = component.inputs;
    expect(compInputs, hasLength(1));
    {
      final input = compInputs[0];
      expect(input.name, 'someInput');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("int"));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_inheritMetadataMixinsInterfaces() async {
    final code = r'''
import 'package:angular2/angular2.dart';

class MixinComponent1 {
  @Input()
  int mixin1Input;
}

class MixinComponent2 {
  @Input()
  int mixin2Input;
}

class ComponentInterface1 {
  @Input()
  int interface1Input;
}

class ComponentInterface2 {
  @Input()
  int interface2Input;
}

@Component( selector: 'my-component', template: '<p></p>')
class FinalComponent
   extends Object
   with MixinComponent1, MixinComponent2
   implements ComponentInterface1, ComponentInterface2 {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.firstWhere((d) => d.name == 'FinalComponent');
    final inputNames = component.inputs.map((input) => input.name);
    expect(
        inputNames,
        unorderedEquals([
          'mixin1Input',
          'mixin2Input',
          'interface1Input',
          'interface2Input'
        ]));
  }

  // ignore: non_constant_identifier_names
  Future test_inheritMetadata_overriddenWithVariance() async {
    final code = r'''
import 'package:angular2/angular2.dart';
import 'dart:async';

abstract class BaseComponent {
  @Input()
  set someInput(int x);

  @Output()
  Stream<Object> get someOutput;
}

@Component(selector: 'my-component', template: '<p></p>')
class VarianceComponent extends BaseComponent {
  set someInput(Object x) => null; // contravariance -- allowed on params

  Stream<int> someOutput; // covariance -- allowed on returns
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component =
        directives.firstWhere((d) => d.name == 'VarianceComponent');
    final compInputs = component.inputs;
    final compOutputs = component.outputs;
    expect(compInputs, hasLength(1));
    {
      final input = compInputs[0];
      expect(input.name, 'someInput');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("Object"));
    }
    expect(compOutputs, hasLength(1));
    {
      final input = compOutputs[0];
      expect(input.name, 'someOutput');
      expect(input.eventType, isNotNull);
      expect(input.eventType.toString(), equals("int"));
    }
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_inheritMetadata_notReimplemented_stillSurfacesAPI() async {
    final code = r'''
import 'package:angular2/angular2.dart';
import 'dart:async';

abstract class BaseComponent {
  @Input()
  set someInput(int x);

  @Output()
  Stream<int> get someOutput;
}

@Component(selector: 'my-component', template: '<p></p>')
class ImproperlyDefinedComponent extends BaseComponent {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component =
        directives.firstWhere((d) => d.name == 'ImproperlyDefinedComponent');
    final compInputs = component.inputs;
    final compOutputs = component.outputs;
    expect(compInputs, hasLength(1));
    {
      final input = compInputs[0];
      expect(input.name, 'someInput');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("int"));
    }
    expect(compOutputs, hasLength(1));
    {
      final input = compOutputs[0];
      expect(input.name, 'someOutput');
      expect(input.eventType, isNotNull);
      expect(input.eventType.toString(), equals("int"));
    }
    errorListener.assertErrorsWithCodes(
        [StaticWarningCode.NON_ABSTRACT_CLASS_INHERITS_ABSTRACT_MEMBER_TWO]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_DirectiveTypeLiteralExpected() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', template: 'AAA', directives: const [int])
class ComponentA {
}
''');
    await getDirectives(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE]);
  }

  // ignore: non_constant_identifier_names
  Future test_parameterizedInheritedInputsOutputs() async {
    final code = r'''
import 'package:angular2/angular2.dart';

class Generic<T> {
  T inputViaChildDecl;
  EventEmitter<T> outputViaChildDecl;
  @Input()
  T inputViaParentDecl;
  @Output()
  EventEmitter<T> outputViaParentDecl;
}

@Component(
    selector: 'my-component',
    template: '<p></p>',
    inputs: const ['inputViaChildDecl'],
    outputs: const ['outputViaChildDecl'])
class MyComponent extends Generic {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final compInputs = component.inputs;
    expect(compInputs, hasLength(2));
    {
      final input =
          compInputs.singleWhere((i) => i.name == 'inputViaChildDecl');
      expect(input, isNotNull);
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("dynamic"));
    }
    {
      final input =
          compInputs.singleWhere((i) => i.name == 'inputViaParentDecl');
      expect(input, isNotNull);
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("dynamic"));
    }

    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(2));
    {
      final output =
          compOutputs.singleWhere((o) => o.name == 'outputViaChildDecl');
      expect(output, isNotNull);
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("dynamic"));
    }
    {
      final output =
          compOutputs.singleWhere((o) => o.name == 'outputViaParentDecl');
      expect(output, isNotNull);
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("dynamic"));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_parameterizedInheritedInputsOutputsSpecified() async {
    final code = r'''
import 'package:angular2/angular2.dart';

class Generic<T> {
  T inputViaChildDecl;
  EventEmitter<T> outputViaChildDecl;
  @Input()
  T inputViaParentDecl;
  @Output()
  EventEmitter<T> outputViaParentDecl;
}

@Component(
    selector: 'my-component',
    template: '<p></p>',
    inputs: const ['inputViaChildDecl'],
    outputs: const ['outputViaChildDecl'])
class MyComponent extends Generic<String> {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final compInputs = component.inputs;
    expect(compInputs, hasLength(2));
    {
      final input =
          compInputs.singleWhere((i) => i.name == 'inputViaChildDecl');
      expect(input, isNotNull);
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("String"));
    }
    {
      final input =
          compInputs.singleWhere((i) => i.name == 'inputViaParentDecl');
      expect(input, isNotNull);
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("String"));
    }

    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(2));
    {
      final output =
          compOutputs.singleWhere((o) => o.name == 'outputViaChildDecl');
      expect(output, isNotNull);
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("String"));
    }
    {
      final output =
          compOutputs.singleWhere((o) => o.name == 'outputViaParentDecl');
      expect(output, isNotNull);
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("String"));
    }
  }
}

@reflectiveTest
class ResolveDartTemplatesTest extends AbstractAngularTest {
  List<AbstractDirective> directives;
  List<Template> templates;
  List<AnalysisError> errors;

  Future getDirectives(final Source source) async {
    final dartResult = await dartDriver.getResult(source.fullName);
    fillErrorListener(dartResult.errors);
    final ngResult = await angularDriver.requestDartResult(source.fullName);
    directives = ngResult.directives;
    errors = ngResult.errors;
    fillErrorListener(errors);
    templates = directives
        .map((d) => d is Component ? d.view?.template : null)
        .where((d) => d != null)
        .toList();
  }

  // ignore: non_constant_identifier_names
  Future test_componentReference() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa', template: '<div>AAA</div>')
class ComponentA {
}

@Component(selector: 'my-bbb', template: '<div>BBB</div>')
class ComponentB {
}

@Component(selector: 'my-ccc', template: r"""
<div>
  <my-aaa></my-aaa>1
  <my-bbb></my-bbb>2
</div>
""", directives: const [ComponentA, ComponentB])
class ComponentC {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final componentA = getComponentByName(directives, 'ComponentA');
    final componentB = getComponentByName(directives, 'ComponentB');
    // validate
    expect(templates, hasLength(3));
    {
      final template = _getDartTemplateByClassName(templates, 'ComponentA');
      expect(template.ranges, isEmpty);
    }
    {
      final template = _getDartTemplateByClassName(templates, 'ComponentB');
      expect(template.ranges, isEmpty);
    }
    {
      final template = _getDartTemplateByClassName(templates, 'ComponentC');
      final ranges = template.ranges;
      expect(ranges, hasLength(4));
      {
        final resolvedRange =
            getResolvedRangeAtString(code, ranges, 'my-aaa></');
        assertComponentReference(resolvedRange, componentA);
      }
      {
        final resolvedRange =
            getResolvedRangeAtString(code, ranges, 'my-aaa>1');
        assertComponentReference(resolvedRange, componentA);
      }
      {
        final resolvedRange =
            getResolvedRangeAtString(code, ranges, 'my-bbb></');
        assertComponentReference(resolvedRange, componentB);
      }
      {
        final resolvedRange =
            getResolvedRangeAtString(code, ranges, 'my-bbb>2');
        assertComponentReference(resolvedRange, componentB);
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_expression_ArgumentTypeNotAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel',
    template: r"<div> {{text.length + text}} </div>")
class TextPanel {
  String text;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertErrorsWithCodes(
        [StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_expression_UndefinedIdentifier() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', inputs: const ['text'],
    template: r"<div>some text</div>")
class TextPanel {
  String text;
}

@Component(selector: 'UserPanel', template: r"""
<div>
  <text-panel [text]='noSuchName'></text-panel>
</div>
""", directives: const [TextPanel])
class UserPanel {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener
        .assertErrorsWithCodes([StaticWarningCode.UNDEFINED_IDENTIFIER]);
  }

  Future
      // ignore: non_constant_identifier_names
      test_hasError_expression_UndefinedIdentifier_OutsideFirstHtmlTag() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '<h1></h1>{{noSuchName}}')
class MyComponent {
}
''';

    final source = newSource('/test.dart', code);
    await getDirectives(source);
    assertErrorInCodeAtPosition(
        StaticWarningCode.UNDEFINED_IDENTIFIER, code, 'noSuchName');
  }

  // ignore: non_constant_identifier_names
  Future test_hasError_UnresolvedTag() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa',
    template: "<unresolved-tag attr='value'></unresolved-tag>")
class ComponentA {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNRESOLVED_TAG, code, 'unresolved-tag');
  }

  // ignore: non_constant_identifier_names
  Future test_suppressError_UnresolvedTag() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa',
    template: """
<!-- @ngIgnoreErrors: UNRESOLVED_TAG -->
<unresolved-tag attr='value'></unresolved-tag>""")
class ComponentA {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_suppressError_NotCaseSensitive() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa',
    template: """
<!-- @ngIgnoreErrors: UnReSoLvEd_tAg -->
<unresolved-tag attr='value'></unresolved-tag>""")
class ComponentA {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_suppressError_UnresolvedTagAndInput() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa',
    template: """
<!-- @ngIgnoreErrors: UNRESOLVED_TAG, NONEXIST_INPUT_BOUND -->
<unresolved-tag [attr]='value'></unresolved-tag>""")
class ComponentA {
  Object value;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_htmlParsing_hasError() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel',
    template: r"<div> <h2> Expected closing H2 </h3> </div>")
class TextPanel {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // has errors
    errorListener.assertErrorsWithCodes([
      NgParserWarningCode.DANGLING_CLOSE_ELEMENT,
      NgParserWarningCode.CANNOT_FIND_MATCHING_CLOSE,
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_input_OK_event() async {
    final code = r'''
import 'dart:html';
    import 'package:angular2/angular2.dart';

@Component(selector: 'UserPanel', template: r"""
<div>
  <input (click)='gotClicked($event)'>
</div>
""")
class TodoList {
  gotClicked(MouseEvent event) {}
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(templates, hasLength(1));
    {
      final template = _getDartTemplateByClassName(templates, 'TodoList');
      final ranges = template.ranges;
      expect(ranges, hasLength(4));
      {
        final resolvedRange =
            getResolvedRangeAtString(code, ranges, r'gotClicked($');
        expect(resolvedRange.range.length, 'gotClicked'.length);
        final element = (resolvedRange.element as DartElement).element;
        expect(element, const isInstanceOf<MethodElement>());
        expect(element.name, 'gotClicked');
        expect(
            element.nameOffset, code.indexOf('gotClicked(MouseEvent event)'));
      }
      {
        final resolvedRange =
            getResolvedRangeAtString(code, ranges, r"$event)'>");
        expect(resolvedRange.range.length, r'$event'.length);
        final element = (resolvedRange.element as LocalVariable).dartVariable;
        expect(element, const isInstanceOf<LocalVariableElement>());
        expect(element.name, r'$event');
        expect(element.nameOffset, -1);
      }
      {
        final resolvedRange = getResolvedRangeAtString(code, ranges, 'click');
        expect(resolvedRange.range.length, 'click'.length);
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_input_OK_reference_expression() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', inputs: const ['text'],
    template: r"<div>some text</div>")
class TextPanel {
  String text;
}

@Component(selector: 'UserPanel', template: r"""
<div>
  <text-panel [text]='user.name'></text-panel>
</div>
""", directives: const [TextPanel])
class UserPanel {
  User user; // 1
}

class User {
  String name; // 2
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final textPanel = getComponentByName(directives, 'TextPanel');
    // validate
    expect(templates, hasLength(2));
    {
      final template = _getDartTemplateByClassName(templates, 'UserPanel');
      final ranges = template.ranges;
      expect(ranges, hasLength(5));
      {
        final resolvedRange = getResolvedRangeAtString(code, ranges, 'text]=');
        expect(resolvedRange.range.length, 'text'.length);
        assertPropertyReference(resolvedRange, textPanel, 'text');
      }
      {
        final resolvedRange = getResolvedRangeAtString(code, ranges, 'user.');
        expect(resolvedRange.range.length, 'user'.length);
        final element = (resolvedRange.element as DartElement).element;
        expect(element, const isInstanceOf<PropertyAccessorElement>());
        expect(element.name, 'user');
        expect(element.nameOffset, code.indexOf('user; // 1'));
      }
      {
        final resolvedRange = getResolvedRangeAtString(code, ranges, "name'>");
        expect(resolvedRange.range.length, 'name'.length);
        final element = (resolvedRange.element as DartElement).element;
        expect(element, const isInstanceOf<PropertyAccessorElement>());
        expect(element.name, 'name');
        expect(element.nameOffset, code.indexOf('name; // 2'));
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_input_OK_reference_text() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(
    selector: 'comp-a',
    inputs: const ['firstValue', 'vtoroy: second'],
    template: r"<div>AAA</div>")
class ComponentA {
  int firstValue;
  int vtoroy;
}

@Component(selector: 'comp-b', template: r"""
<div>
  <comp-a [firstValue]='1' [second]='2'></comp-a>
</div>
""", directives: const [ComponentA])
class ComponentB {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final componentA = getComponentByName(directives, 'ComponentA');
    // validate
    expect(templates, hasLength(2));
    {
      final template = _getDartTemplateByClassName(templates, 'ComponentB');
      final ranges = template.ranges;
      expect(ranges, hasLength(4));
      {
        final resolvedRange =
            getResolvedRangeAtString(code, ranges, 'firstValue]=');
        expect(resolvedRange.range.length, 'firstValue'.length);
        assertPropertyReference(resolvedRange, componentA, 'firstValue');
      }
      {
        final resolvedRange =
            getResolvedRangeAtString(code, ranges, 'second]=');
        expect(resolvedRange.range.length, 'second'.length);
        assertPropertyReference(resolvedRange, componentA, 'second');
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_noRootElement() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel',
    template: r'Often used without an element in tests.')
class TextPanel {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(templates, hasLength(1));
    // has errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_noTemplateContents() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel',
    template: '')
class TextPanel {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(templates, hasLength(1));
    // has errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_textExpression_hasError_UnterminatedMustache() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"{{text")
class TextPanel {
  String text = "text";
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // has errors
    errorListener
        .assertErrorsWithCodes([AngularWarningCode.UNTERMINATED_MUSTACHE]);
  }

  // ignore: non_constant_identifier_names
  Future test_textExpression_hasError_UnopenedMustache() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"<div> text}} </div>")
class TextPanel {
  String text;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // has errors
    errorListener.assertErrorsWithCodes([AngularWarningCode.UNOPENED_MUSTACHE]);
  }

  // ignore: non_constant_identifier_names
  Future test_textExpression_hasError_DoubleOpenedMustache() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"<div> {{text {{ error}} </div>")
class TextPanel {
  String text;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertErrorsWithCodes([
      AngularWarningCode.UNTERMINATED_MUSTACHE,
      StaticWarningCode.UNDEFINED_IDENTIFIER
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_textExpression_hasError_MultipleUnclosedMustaches() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"<div> {{open {{error {{text}} close}} close}} </div>")
class TextPanel {
  String text, open, close;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertErrorsWithCodes([
      AngularWarningCode.UNTERMINATED_MUSTACHE,
      AngularWarningCode.UNTERMINATED_MUSTACHE,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      AngularWarningCode.UNOPENED_MUSTACHE,
      AngularWarningCode.UNOPENED_MUSTACHE,
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_textExpression_OK() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', inputs: const ['text'],
    template: r"<div> <h2> {{text}}  </h2> and {{text.length}} </div>")
class TextPanel {
  String text; // 1
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(templates, hasLength(1));
    {
      final template = _getDartTemplateByClassName(templates, 'TextPanel');
      final ranges = template.ranges;
      expect(ranges, hasLength(5));
      {
        final resolvedRange = getResolvedRangeAtString(code, ranges, 'text}}');
        expect(resolvedRange.range.length, 'text'.length);
        final element = assertGetter(resolvedRange);
        expect(element.name, 'text');
        expect(element.nameOffset, code.indexOf('text; // 1'));
      }
      {
        final resolvedRange =
            getResolvedRangeAtString(code, ranges, 'text.length');
        expect(resolvedRange.range.length, 'text'.length);
        final element = assertGetter(resolvedRange);
        expect(element.name, 'text');
        expect(element.nameOffset, code.indexOf('text; // 1'));
      }
      {
        final resolvedRange =
            getResolvedRangeAtString(code, ranges, 'length}}');
        expect(resolvedRange.range.length, 'length'.length);
        final element = assertGetter(resolvedRange);
        expect(element.name, 'length');
        expect(element.enclosingElement.name, 'String');
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_resolveGetChildDirectivesNgContentSelectors() async {
    final code = r'''
import 'package:angular2/angular2.dart';
import 'child_file.dart';

@Component(selector: 'my-component', template: 'My template',
    directives: const [ChildComponent])
class MyComponent {}
''';
    final childCode = r'''
import 'package:angular2/angular2.dart';
@Component(selector: 'child-component',
    template: 'My template <ng-content></ng-content>',
    directives: const [])
class ChildComponent {}
''';
    final source = newSource('/test.dart', code);
    newSource('/child_file.dart', childCode);
    await getDirectives(source);
    expect(templates, hasLength(1));
    // no errors
    errorListener.assertNoErrors();

    final childDirectives = templates.first.view.directives;
    expect(childDirectives, hasLength(1));

    final childViews = childDirectives
        .map((d) => d is Component ? d.view : null)
        .where((v) => v != null)
        .toList();
    expect(childViews, hasLength(1));
    final childView = childViews.first;
    expect(childView.component, isNotNull);
    expect(childView.component.ngContents, hasLength(1));
  }

  // ignore: non_constant_identifier_names
  Future test_attributes() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class MyComponent {
  MyComponent(@Attribute("my-attr") String foo);
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final attributes = component.attributes;
    expect(attributes, hasLength(1));
    {
      final attribute = attributes[0];
      expect(attribute.name, 'my-attr');
      // TODO better offsets here. But its really not that critical
      expect(attribute.nameOffset, code.indexOf("foo"));
      expect(attribute.nameLength, "foo".length);
    }
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_attributeNotString() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class MyComponent {
  MyComponent(@Attribute("my-attr") int foo);
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final attributes = component.attributes;
    expect(attributes, hasLength(1));
    {
      final attribute = attributes[0];
      expect(attribute.name, 'my-attr');
      // TODO better offsets here. But its really not that critical
      expect(attribute.nameOffset, code.indexOf("foo"));
      expect(attribute.nameLength, "foo".length);
    }
    assertErrorInCodeAtPosition(
        AngularWarningCode.ATTRIBUTE_PARAMETER_MUST_BE_STRING, code, 'foo');
  }

  // ignore: non_constant_identifier_names
  Future test_constantExpressionTemplateVarDoesntCrash() async {
    final source = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

const String tplText = "we don't analyze this";

@Component(selector: 'aaa', template: tplText)
class ComponentA {
}
''');
    await getDirectives(source);
    expect(templates, hasLength(0));
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularHintCode.OFFSETS_CANNOT_BE_CREATED]);
  }

  // ignore: non_constant_identifier_names
  Future test_hasExports() async {
    final code = r'''
import 'package:angular2/angular2.dart';

const String foo = 'foo';
int bar() { return 2; }
class MyClass {}

@Component(selector: 'my-component', template: '',
    exports: const [foo, bar, MyClass])
class ComponentA {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final Component component = directives.first;
    expect(component.view, isNotNull);
    expect(component.view.exports, hasLength(3));
    {
      final export = component.view.exports[0];
      expect(export.identifier, equals('foo'));
      expect(export.prefix, equals(''));
      expect(export.span.offset, equals(code.indexOf('foo,')));
      expect(export.span.length, equals('foo'.length));
      expect(export.element.toString(), equals('get foo → String'));
    }
    {
      final export = component.view.exports[1];
      expect(export.identifier, equals('bar'));
      expect(export.prefix, equals(''));
      expect(export.span.offset, equals(code.indexOf('bar,')));
      expect(export.span.length, equals('bar'.length));
      expect(export.element.toString(), equals('bar() → int'));
    }
    {
      final export = component.view.exports[2];
      expect(export.identifier, equals('MyClass'));
      expect(export.prefix, equals(''));
      expect(export.span.offset, equals(code.indexOf('MyClass]')));
      expect(export.span.length, equals('MyClass'.length));
      expect(export.element.toString(), equals('class MyClass'));
    }
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_prefixedExport() async {
    newSource('/prefixed.dart', 'const double foo = 2.0;');
    final code = r'''
import 'package:angular2/angular2.dart';
import '/prefixed.dart' as prefixed;

const int foo = 2;

@Component(selector: 'my-component', template: '',
    exports: const [prefixed.foo, foo])
class ComponentA {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final Component component = directives.first;
    expect(component.view, isNotNull);
    expect(component.view.exports, hasLength(2));
    {
      final export = component.view.exports[0];
      expect(export.identifier, equals('foo'));
      expect(export.prefix, equals('prefixed'));
      expect(export.span.offset, equals(code.indexOf('prefixed.foo')));
      expect(export.span.length, equals('prefixed.foo'.length));
      expect(export.element.toString(), equals('get foo → double'));
    }
    {
      final export = component.view.exports[1];
      expect(export.identifier, equals('foo'));
      expect(export.prefix, equals(''));
      expect(export.span.offset, equals(code.indexOf('foo]')));
      expect(export.span.length, equals('foo'.length));
      expect(export.element.toString(), equals('get foo → int'));
    }

    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_hasWrongTypeOfPrefixedIdentifierExport() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '',
    exports: const [ComponentA.foo])
class ComponentA {
  static void foo(){}
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.EXPORTS_MUST_BE_PLAIN_IDENTIFIERS,
        code,
        'ComponentA.foo');
  }

  // ignore: non_constant_identifier_names
  Future test_cannotExportComponentClassItself() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '',
    exports: const [ComponentA])
class ComponentA {
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.COMPONENTS_CANT_EXPORT_THEMSELVES,
        code,
        'ComponentA');
  }

  // ignore: non_constant_identifier_names
  Future test_misspelledPrefixSuppressesWrongPrefixTypeError() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '',
    exports: const [garbage.garbage])
class ComponentA {
  static void foo(){}
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    errorListener.assertErrorsWithCodes(<ErrorCode>[
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      CompileTimeErrorCode.CONST_WITH_NON_CONSTANT_ARGUMENT,
      CompileTimeErrorCode.NON_CONSTANT_LIST_ELEMENT
    ]);
  }

  static Template _getDartTemplateByClassName(
          List<Template> templates, String className) =>
      templates.firstWhere(
          (template) => template.view.classElement.name == className,
          orElse: () {
        fail('Template with the class "$className" was not found.');
      });
}

@reflectiveTest
class ResolveHtmlTemplatesTest extends AbstractAngularTest {
  List<Template> templates;
  Future getDirectives(Source htmlSource, List<Source> dartSources) async {
    for (final dartSource in dartSources) {
      final result = await angularDriver.requestDartResult(dartSource.fullName);
      fillErrorListener(result.errors);
    }
    final result2 = await angularDriver.requestHtmlResult(htmlSource.fullName);
    fillErrorListener(result2.errors);
    templates = result2.directives
        .map((d) => d is Component ? d.view?.template : null)
        .where((d) => d != null)
        .toList();
  }

  // ignore: non_constant_identifier_names
  Future test_multipleViewsWithTemplate() async {
    final dartCodeOne = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panelA', templateUrl: 'text_panel.html')
class TextPanelA {
  String text; // A
}
''';

    final dartCodeTwo = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panelB', templateUrl: 'text_panel.html')
class TextPanelB {
  String text; // B
}
''';
    final htmlCode = r"""
<div>
  {{text}}
</div>
""";
    final dartSourceOne = newSource('/test1.dart', dartCodeOne);
    final dartSourceTwo = newSource('/test2.dart', dartCodeTwo);
    final htmlSource = newSource('/text_panel.html', htmlCode);
    await getDirectives(htmlSource, [dartSourceOne, dartSourceTwo]);
    expect(templates, hasLength(2));
    // validate templates
    var hasTextPanelA = false;
    var hasTextPanelB = false;
    for (final template in templates) {
      final viewClassName = template.view.classElement.name;
      int textLocation;
      if (viewClassName == 'TextPanelA') {
        hasTextPanelA = true;
        textLocation = dartCodeOne.indexOf('text; // A');
      }
      if (viewClassName == 'TextPanelB') {
        hasTextPanelB = true;
        textLocation = dartCodeTwo.indexOf('text; // B');
      }
      expect(template.ranges, hasLength(1));
      {
        final resolvedRange =
            getResolvedRangeAtString(htmlCode, template.ranges, 'text}}');
        final element = assertGetter(resolvedRange);
        expect(element.name, 'text');
        expect(element.nameOffset, textLocation);
      }
    }
    expect(hasTextPanelA, isTrue);
    expect(hasTextPanelB, isTrue);
  }
}

@reflectiveTest
class ResolveHtmlTemplateTest extends AbstractAngularTest {
  List<View> views;
  Future getDirectives(Source htmlSource, Source dartSource) async {
    final result = await angularDriver.requestDartResult(dartSource.fullName);
    fillErrorListener(result.errors);
    final result2 = await angularDriver.requestHtmlResult(htmlSource.fullName);
    fillErrorListener(result2.errors);
    views = result2.directives
        .map((d) => d is Component ? d.view : null)
        .where((v) => v != null)
        .toList();
  }

  // ignore: non_constant_identifier_names
  Future test_suppressError_UnresolvedTagHtmlTemplate() async {
    final dartSource = newSource('/test.dart', r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa', templateUrl: 'test.html')
class ComponentA {
}
''');
    final htmlSource = newSource('/test.html', '''
<!-- @ngIgnoreErrors: UNRESOLVED_TAG -->
<unresolved-tag attr='value'></unresolved-tag>""")
''');
    await getDirectives(htmlSource, dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_errorFromWeirdInclude_includesFromPath() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa', templateUrl: "test.html")
class WeirdComponent {
}
''';
    final dartSource = newSource('/weird.dart', code);
    final htmlSource =
        newSource('/test.html', "<unresolved-tag></unresolved-tag>");
    await getDirectives(htmlSource, dartSource);
    final errors = errorListener.errors;
    expect(errors, hasLength(1));
    expect(errors.first, const isInstanceOf<FromFilePrefixedError>());
    expect(
        errors.first.message,
        equals('In WeirdComponent:'
            ' Unresolved tag "unresolved-tag" (from /weird.dart)'));
  }

  // ignore: non_constant_identifier_names
  Future test_hasViewWithTemplate() async {
    final dartCode = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', templateUrl: 'text_panel.html')
class TextPanel {
  String text; // 1
}
''';
    final htmlCode = r"""
<div>
  {{text}}
</div>
""";
    final dartSource = newSource('/test.dart', dartCode);
    final htmlSource = newSource('/text_panel.html', htmlCode);
    // compute
    await getDirectives(htmlSource, dartSource);
    expect(views, hasLength(1));
    {
      final view = getViewByClassName(views, 'TextPanel');
      expect(view.templateUriSource, isNotNull);
      // resolve this View
      final template = view.template;
      expect(template, isNotNull);
      expect(template.view, view);
      expect(template.ranges, hasLength(1));
      {
        final resolvedRange =
            getResolvedRangeAtString(htmlCode, template.ranges, 'text}}');
        final element = assertGetter(resolvedRange);
        expect(element.name, 'text');
        expect(element.nameOffset, dartCode.indexOf('text; // 1'));
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_hasView_withTemplate_relativeToLibForParts() async {
    final libCode = r'''
import 'package:angular2/angular2.dart';
part 'parts/part.dart';
    ''';
    final partCode = r'''
part of '../lib.dart';
@Component(selector: 'my-component', templateUrl: 'parts/my-template.html')
class MyComponent {
  String text; // 1
}
''';
    final htmlCode = r'''
<div>
  {{text}}
</div>
''';
    final dartLibSource = newSource('/lib.dart', libCode);
    final dartPartSource = newSource('/parts/part.dart', partCode);
    final htmlSource = newSource('/parts/my-template.html', htmlCode);
    await getDirectives(htmlSource, dartPartSource);
    errorListener.assertNoErrors();
    expect(views, hasLength(1));
    {
      final view = getViewByClassName(views, 'MyComponent');
      expect(view.templateUriSource, isNotNull);
      // resolve this View
      final template = view.template;
      expect(template, isNotNull);
      expect(template.view, view);
      expect(template.ranges, hasLength(1));
      {
        final resolvedRange =
            getResolvedRangeAtString(htmlCode, template.ranges, 'text}}');
        final element = assertGetter(resolvedRange);
        expect(element.name, 'text');
        expect(element.nameOffset, partCode.indexOf('text; // 1'));
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_resolveGetChildDirectivesNgContentSelectors() async {
    final code = r'''
import 'package:angular2/angular2.dart';
import 'child_file.dart';

import 'package:angular2/angular2.dart';
@Component(selector: 'my-component', templateUrl: 'test.html',
    directives: const [ChildComponent])
class MyComponent {}
''';
    final childCode = r'''
import 'package:angular2/angular2.dart';
@Component(selector: 'child-component',
    template: 'My template <ng-content></ng-content>',
    directives: const [])
class ChildComponent {}
''';
    final dartSource = newSource('/test.dart', code);
    newSource('/child_file.dart', childCode);
    final htmlSource = newSource('/test.html', '');
    await getDirectives(htmlSource, dartSource);

    final childDirectives = views.first.directives;
    expect(childDirectives, hasLength(1));

    final childView = (views.first.directives.first as Component).view;
    expect(childView.component, isNotNull);
    expect(childView.component.ngContents, hasLength(1));
  }

  // ignore: non_constant_identifier_names
  Future test_contentChildAnnotatedConstructor() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'a', templateUrl: 'test.html')
class A {
  @ContentChild(X)
  A(){}
}
''';
    final dartSource = newSource('/test.dart', code);
    final htmlSource = newSource('/test.html', '');
    await getDirectives(htmlSource, dartSource);

    final component = views.first.component;

    expect(component.contentChilds, hasLength(0));
  }
}
