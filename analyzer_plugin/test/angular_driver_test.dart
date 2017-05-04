library angular2.src.analysis.analyzer_plugin.src.tasks_test;

import 'dart:async';

import 'package:angular_analyzer_plugin/src/standard_components.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/from_file_prefixed_error.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/view_extraction.dart';
import 'package:angular_analyzer_plugin/src/directive_linking.dart';
import 'package:html/dom.dart' as html;
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';

import 'abstract_angular.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AngularParseHtmlTest);
    defineReflectiveTests(BuildStandardHtmlComponentsTest);
    defineReflectiveTests(BuildUnitDirectivesTest);
    defineReflectiveTests(BuildUnitViewsTest);
    defineReflectiveTests(ResolveDartTemplatesTest);
    defineReflectiveTests(ResolveHtmlTemplatesTest);
    defineReflectiveTests(ResolveHtmlTemplateTest);
  });
}

@reflectiveTest
class AngularParseHtmlTest extends AbstractAngularTest {
  test_perform() {
    String code = r'''
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
    final tplParser = new TemplateParser();

    tplParser.parse(code, source);
    expect(tplParser.parseErrors, isEmpty);
    // HTML_DOCUMENT
    {
      html.Document document = tplParser.document;
      expect(document, isNotNull);
      // verify that attributes are not lower-cased
      html.Element element = document.body.getElementsByTagName('h1').single;
      expect(element.attributes['myAttr'], 'my value');
    }
  }

  test_perform_noDocType() {
    String code = r'''
<div>AAA</div>
<span>BBB</span>
''';
    final source = newSource('/test.html', code);
    final tplParser = new TemplateParser();

    tplParser.parse(code, source);
    // validate Document
    {
      html.Document document = tplParser.document;
      expect(document, isNotNull);
      // artificial <html>
      expect(document.nodes, hasLength(1));
      html.Element htmlElement = document.nodes[0];
      expect(htmlElement.localName, 'html');
      // artificial <body>
      expect(htmlElement.nodes, hasLength(2));
      html.Element bodyElement = htmlElement.nodes[1];
      expect(bodyElement.localName, 'body');
      // actual nodes
      expect(bodyElement.nodes, hasLength(4));
      expect((bodyElement.nodes[0] as html.Element).localName, 'div');
      expect((bodyElement.nodes[2] as html.Element).localName, 'span');
    }
    // it's OK to don't have DOCTYPE
    expect(tplParser.parseErrors, isEmpty);
  }

  test_perform_noDocType_with_dangling_unclosed_tag() {
    String code = r'''
<div>AAA</div>
<span>BBB</span>
<di''';
    final source = newSource('/test.html', code);
    final tplParser = new TemplateParser();

    tplParser.parse(code, source);
    // quick validate Document
    {
      html.Document document = tplParser.document;
      expect(document, isNotNull);
      html.Element htmlElement = document.nodes[0];
      html.Element bodyElement = htmlElement.nodes[1];
      expect(bodyElement.nodes, hasLength(5));
      expect((bodyElement.nodes[0] as html.Element).localName, 'div');
      expect((bodyElement.nodes[2] as html.Element).localName, 'span');
      expect((bodyElement.nodes[4] as html.Element).localName, 'di');
    }
  }
}

@reflectiveTest
class BuildStandardHtmlComponentsTest extends AbstractAngularTest {
  Future test_perform() async {
    StandardHtml stdhtml = await angularDriver.getStandardHtml();
    // validate
    Map<String, Component> map = stdhtml.components;
    expect(map, isNotNull);
    // a
    {
      Component component = map['a'];
      expect(component, isNotNull);
      expect(component.classElement.displayName, 'AnchorElement');
      expect(component.selector.toString(), 'a');
      List<InputElement> inputs = component.inputs;
      List<OutputElement> outputElements = component.outputs;
      {
        InputElement input = inputs.singleWhere((i) => i.name == 'href');
        expect(input, isNotNull);
        expect(input.setter, isNotNull);
        expect(input.setterType.toString(), equals("String"));
      }
      expect(outputElements, hasLength(0));
      expect(inputs.where((i) => i.name == '_privateField'), hasLength(0));
    }
    // button
    {
      Component component = map['button'];
      expect(component, isNotNull);
      expect(component.classElement.displayName, 'ButtonElement');
      expect(component.selector.toString(), 'button');
      List<InputElement> inputs = component.inputs;
      List<OutputElement> outputElements = component.outputs;
      {
        InputElement input = inputs.singleWhere((i) => i.name == 'autofocus');
        expect(input, isNotNull);
        expect(input.setter, isNotNull);
        expect(input.setterType.toString(), equals("bool"));
      }
      expect(outputElements, hasLength(0));
    }
    // input
    {
      Component component = map['input'];
      expect(component, isNotNull);
      expect(component.classElement.displayName, 'InputElement');
      expect(component.selector.toString(), 'input');
      List<OutputElement> outputElements = component.outputs;
      expect(outputElements, hasLength(0));
    }
    // body is one of the few elements with special events
    {
      Component component = map['body'];
      expect(component, isNotNull);
      expect(component.classElement.displayName, 'BodyElement');
      expect(component.selector.toString(), 'body');
      List<OutputElement> outputElements = component.outputs;
      expect(outputElements, hasLength(1));
      {
        OutputElement output = outputElements[0];
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
  }

  test_buildStandardHtmlEvents() async {
    StandardHtml stdhtml = await angularDriver.getStandardHtml();
    Map<String, OutputElement> outputElements = stdhtml.events;
    {
      // This one is important because it proves we're using @DomAttribute
      // to generate the output name and not the method in the sdk.
      OutputElement outputElement = outputElements['keyup'];
      expect(outputElement, isNotNull);
      expect(outputElement.getter, isNotNull);
      expect(outputElement.eventType, isNotNull);
    }
    {
      OutputElement outputElement = outputElements['cut'];
      expect(outputElement, isNotNull);
      expect(outputElement.getter, isNotNull);
      expect(outputElement.eventType, isNotNull);
    }
    {
      OutputElement outputElement = outputElements['click'];
      expect(outputElement, isNotNull);
      expect(outputElement.getter, isNotNull);
      expect(outputElement.eventType, isNotNull);
      expect(outputElement.eventType.toString(), equals('MouseEvent'));
    }
    {
      OutputElement outputElement = outputElements['change'];
      expect(outputElement, isNotNull);
      expect(outputElement.getter, isNotNull);
      expect(outputElement.eventType, isNotNull);
    }
    {
      // used to happen from "id" which got truncated by 'on'.length
      OutputElement outputElement = outputElements[''];
      expect(outputElement, isNull);
    }
    {
      // used to happen from "hidden" which got truncated by 'on'.length
      OutputElement outputElement = outputElements['dden'];
      expect(outputElement, isNull);
    }
  }

  test_buildStandardHtmlAttributes() async {
    StandardHtml stdhtml = await angularDriver.getStandardHtml();
    Map<String, InputElement> inputElements = stdhtml.attributes;
    {
      InputElement input = inputElements['tabIndex'];
      expect(input, isNotNull);
      expect(input.setter, isNotNull);
      expect(input.setterType.toString(), equals("int"));
    }
    {
      InputElement input = inputElements['hidden'];
      expect(input, isNotNull);
      expect(input.setter, isNotNull);
      expect(input.setterType.toString(), equals("bool"));
    }
  }
}

@reflectiveTest
class BuildUnitDirectivesTest extends AbstractAngularTest {
  List<AbstractDirective> directives;
  List<AnalysisError> errors;

  Future getDirectives(Source source) async {
    final dartResult = await dartDriver.getResult(source.fullName);
    fillErrorListener(dartResult.errors);
    final result = await angularDriver.getDirectives(source.fullName);
    directives = result.directives;
    errors = result.errors;
    fillErrorListener(errors);
  }

  Future test_Component() async {
    var source = newSource(
        '/test.dart',
        r'''
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
      Component component = directives[0];
      expect(component, new isInstanceOf<Component>());
      {
        Selector selector = component.selector;
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-a');
      }
      {
        expect(component.elementTags, hasLength(1));
        Selector selector = component.elementTags[0];
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
      {
        expect(component.elementTags, hasLength(1));
        Selector selector = component.elementTags[0];
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-b');
      }
    }
  }

  Future test_Directive() async {
    var source = newSource(
        '/test.dart',
        r'''
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
      AbstractDirective directive = directives[0];
      expect(directive, new isInstanceOf<Directive>());
      {
        Selector selector = directive.selector;
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-a');
      }
      {
        expect(directive.elementTags, hasLength(1));
        Selector selector = directive.elementTags[0];
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
      {
        expect(directive.elementTags, hasLength(1));
        Selector selector = directive.elementTags[0];
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-b');
      }
    }
  }

  Future test_Directive_elementTags_OrSelector() async {
    var source = newSource(
        '/test.dart',
        r'''
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
      Directive directive = directives[0];
      expect(directive, new isInstanceOf<Directive>());
      {
        Selector selector = directive.selector;
        expect(selector, new isInstanceOf<OrSelector>());
        expect((selector as OrSelector).selectors, hasLength(3));
      }
      {
        expect(directive.elementTags, hasLength(3));
        expect(
            directive.elementTags[0], new isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-a1');
        expect(
            directive.elementTags[1], new isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[1].toString(), 'dir-a2');
        expect(
            directive.elementTags[2], new isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[2].toString(), 'dir-a3');
      }
    }
    {
      Directive directive = directives[1];
      expect(directive, new isInstanceOf<Directive>());
      {
        Selector selector = directive.selector;
        expect(selector, new isInstanceOf<OrSelector>());
        expect((selector as OrSelector).selectors, hasLength(2));
      }
      {
        expect(directive.elementTags, hasLength(2));
        expect(
            directive.elementTags[0], new isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-b1');
        expect(
            directive.elementTags[1], new isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[1].toString(), 'dir-b2');
      }
    }
  }

  Future test_Directive_elementTags_AndSelector() async {
    var source = newSource(
        '/test.dart',
        r'''
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
      Directive directive = directives[0];
      expect(directive, new isInstanceOf<Directive>());
      {
        Selector selector = directive.selector;
        expect(selector, new isInstanceOf<AndSelector>());
        expect((selector as AndSelector).selectors, hasLength(3));
      }
      {
        expect(directive.elementTags, hasLength(1));
        expect(
            directive.elementTags[0], new isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-a');
      }
    }
    {
      Directive directive = directives[1];
      expect(directive, new isInstanceOf<Directive>());
      {
        Selector selector = directive.selector;
        expect(selector, new isInstanceOf<AndSelector>());
        expect((selector as AndSelector).selectors, hasLength(2));
      }
      {
        expect(directive.elementTags, hasLength(1));
        expect(
            directive.elementTags[0], new isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-b');
      }
    }
  }

  Future test_Directive_elementTags_CompoundSelector() async {
    var source = newSource(
        '/test.dart',
        r'''
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
      Directive directive = directives[0];
      expect(directive, new isInstanceOf<Directive>());
      {
        Selector selector = directive.selector;
        expect(selector, new isInstanceOf<OrSelector>());
        expect((selector as OrSelector).selectors, hasLength(2));
      }
      {
        expect(directive.elementTags, hasLength(2));
        expect(
            directive.elementTags[0], new isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-a1');
        expect(
            directive.elementTags[1], new isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[1].toString(), 'dir-a2');
      }
    }
    {
      Directive directive = directives[1];
      expect(directive, new isInstanceOf<Directive>());
      {
        Selector selector = directive.selector;
        expect(selector, new isInstanceOf<OrSelector>());
        expect((selector as OrSelector).selectors, hasLength(2));
      }
      {
        expect(directive.elementTags, hasLength(2));
        expect(
            directive.elementTags[0], new isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[0].toString(), 'dir-b1');
        expect(
            directive.elementTags[1], new isInstanceOf<ElementNameSelector>());
        expect(directive.elementTags[1].toString(), 'dir-b2');
      }
    }
  }

  Future test_exportAs_Component() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', exportAs: 'export-name', template:'')
class ComponentA {
}

@Component(selector: 'bbb', template:'')
class ComponentB {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(directives, hasLength(2));
    {
      Component component = getComponentByClassName(directives, 'ComponentA');
      {
        AngularElement exportAs = component.exportAs;
        expect(exportAs.name, 'export-name');
        expect(exportAs.nameOffset, code.indexOf('export-name'));
      }
    }
    {
      Component component = getComponentByClassName(directives, 'ComponentB');
      {
        AngularElement exportAs = component.exportAs;
        expect(exportAs, isNull);
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  Future test_exportAs_Directive() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: '[aaa]', exportAs: 'export-name')
class DirectiveA {
}

@Directive(selector: '[bbb]')
class DirectiveB {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(directives, hasLength(2));
    {
      Directive directive = getDirectiveByClassName(directives, 'DirectiveA');
      {
        AngularElement exportAs = directive.exportAs;
        expect(exportAs.name, 'export-name');
        expect(exportAs.nameOffset, code.indexOf('export-name'));
      }
    }
    {
      Directive directive = getDirectiveByClassName(directives, 'DirectiveB');
      {
        AngularElement exportAs = directive.exportAs;
        expect(exportAs, isNull);
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  Future test_exportAs_hasError_notStringValue() async {
    var source = newSource(
        '/test.dart',
        r'''
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

  Future test_exportAs_constantStringExpressionOk() async {
    var source = newSource(
        '/test.dart',
        r'''
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

  Future test_hasError_ArgumentSelectorMissing() async {
    var source = newSource(
        '/test.dart',
        r'''
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

  Future test_hasError_CannotParseSelector() async {
    String code = r'''
import 'package:angular2/angular2.dart';
@Component(selector: 'a+bad selector', template: '')
class ComponentA {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.CANNOT_PARSE_SELECTOR, code, "+");
  }

  Future test_hasError_selector_notStringValue() async {
    var source = newSource(
        '/test.dart',
        r'''
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

  Future test_selector_constantExpressionOk() async {
    var source = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'a' + '[b]', template: '')
class ComponentA {
}
''');
    await getDirectives(source);
    // validate
    errorListener.assertNoErrors();
  }

  Future test_hasError_UndefinedSetter_fullSyntax() async {
    var source = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', inputs: const ['noSetter: no-setter'], template: '')
class ComponentA {
}
''');
    await getDirectives(source);
    Component component = directives.single;
    List<InputElement> inputs = component.inputs;
    // the bad input should NOT show up, it is not usable see github #183
    expect(inputs, hasLength(0));
    // validate
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[StaticTypeWarningCode.UNDEFINED_SETTER]);
  }

  Future test_hasError_UndefinedSetter_shortSyntax() async {
    var source = newSource(
        '/test.dart',
        r'''
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

  Future test_hasError_UndefinedSetter_shortSyntax_noInputMade() async {
    var source = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', inputs: const ['noSetter'], template: '')
class ComponentA {
}
''');
    await getDirectives(source);
    Component component = directives.single;
    List<InputElement> inputs = component.inputs;
    // the bad input should NOT show up, it is not usable see github #183
    expect(inputs, hasLength(0));
    // validate
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[StaticTypeWarningCode.UNDEFINED_SETTER]);
  }

  Future test_inputs() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.single;
    List<InputElement> inputs = component.inputs;
    expect(inputs, hasLength(5));
    {
      InputElement input = inputs[0];
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
      InputElement input = inputs[1];
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
      InputElement input = inputs[2];
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
      InputElement input = inputs[3];
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
      InputElement input = inputs[4];
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

  Future test_inputs_deprecatedProperties() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.single;
    List<InputElement> inputs = component.inputs;
    expect(inputs, hasLength(2));
    {
      InputElement input = inputs[0];
      expect(input.name, 'leadingText');
      expect(input.nameOffset, code.indexOf("leadingText',"));
      expect(input.setterRange.offset, input.nameOffset);
      expect(input.setterRange.length, 'leadingText'.length);
      expect(input.setter, isNotNull);
      expect(input.setter.isSetter, isTrue);
      expect(input.setter.displayName, 'leadingText');
    }
    {
      InputElement input = inputs[1];
      expect(input.name, 'tailText');
      expect(input.nameOffset, code.indexOf("tailText']"));
      expect(input.setterRange.offset, code.indexOf("trailingText: "));
      expect(input.setterRange.length, 'trailingText'.length);
      expect(input.setter, isNotNull);
      expect(input.setter.isSetter, isTrue);
      expect(input.setter.displayName, 'trailingText');
    }
  }

  Future test_outputs() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.single;
    List<OutputElement> compOutputs = component.outputs;
    expect(compOutputs, hasLength(5));
    {
      OutputElement output = compOutputs[0];
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
      OutputElement output = compOutputs[1];
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
      OutputElement output = compOutputs[2];
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
      OutputElement output = compOutputs[3];
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
      OutputElement output = compOutputs[4];
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

  Future test_outputs_streamIsOk() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.single;
    List<OutputElement> compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      OutputElement output = compOutputs[0];
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("int"));
    }
  }

  Future test_outputs_extendStreamIsOk() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.single;
    List<OutputElement> compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      OutputElement output = compOutputs[0];
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("int"));
    }
  }

  Future test_outputs_extendStreamSpecializedIsOk() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.single;
    List<OutputElement> compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      OutputElement output = compOutputs[0];
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("int"));
    }
  }

  Future test_outputs_extendStreamUntypedIsOk() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.single;
    List<OutputElement> compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      OutputElement output = compOutputs[0];
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("dynamic"));
    }
  }

  Future test_outputs_notEventEmitterTypeError() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(
    selector: 'my-component',
    template: '<p></p>')
class MyComponent {
  @Output()
  int badOutput;
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_MUST_BE_STREAM, code, "badOutput");
  }

  Future test_outputs_extendStreamNotStreamHasDynamicEventType() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(
    selector: 'my-component',
    template: '<p></p>')
class MyComponent {
  @Output()
  int badOutput;
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    Component component = directives.single;
    List<OutputElement> compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      OutputElement output = compOutputs[0];
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("dynamic"));
    }
  }

  Future test_parameterizedInputsOutputs() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    Component component = directives.single;
    List<InputElement> compInputs = component.inputs;
    expect(compInputs, hasLength(4));
    {
      InputElement input = compInputs[0];
      expect(input.name, 'dynamicInput');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("dynamic"));
    }
    {
      InputElement input = compInputs[1];
      expect(input.name, 'stringInput');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("String"));
    }
    {
      InputElement input = compInputs[2];
      expect(input.name, 'stringInput2');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("String"));
    }
    {
      InputElement input = compInputs[3];
      expect(input.name, 'listInput');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("List<String>"));
    }

    List<OutputElement> compOutputs = component.outputs;
    expect(compOutputs, hasLength(4));
    {
      OutputElement output = compOutputs[0];
      expect(output.name, 'dynamicOutput');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("dynamic"));
    }
    {
      OutputElement output = compOutputs[1];
      expect(output.name, 'stringOutput');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("String"));
    }
    {
      OutputElement output = compOutputs[2];
      expect(output.name, 'stringOutput2');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("String"));
    }
    {
      OutputElement output = compOutputs[3];
      expect(output.name, 'listOutput');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("List<String>"));
    }

    // assert no syntax errors, etc
    errorListener.assertNoErrors();
  }

  Future test_parameterizedInheritedInputsOutputs() async {
    String code = r'''
import 'package:angular2/angular2.dart';

class Generic<T> {
  T input;
  EventEmitter<T> output;
}

@Component(
    selector: 'my-component',
    template: '<p></p>',
    inputs: const ['input'],
    outputs: const ['output'])
class MyComponent extends Generic {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.single;
    List<InputElement> compInputs = component.inputs;
    expect(compInputs, hasLength(1));
    {
      InputElement input = compInputs[0];
      expect(input.name, 'input');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("dynamic"));
    }

    List<OutputElement> compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      OutputElement output = compOutputs[0];
      expect(output.name, 'output');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("dynamic"));
    }
  }

  Future test_parameterizedInheritedInputsOutputsSpecified() async {
    String code = r'''
import 'package:angular2/angular2.dart';

class Generic<T> {
  T input;
  EventEmitter<T> output;
}

@Component(
    selector: 'my-component',
    template: '<p></p>',
    inputs: const ['input'],
    outputs: const ['output'])
class MyComponent extends Generic<String> {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.single;
    List<InputElement> compInputs = component.inputs;
    expect(compInputs, hasLength(1));
    {
      InputElement input = compInputs[0];
      expect(input.name, 'input');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("String"));
    }

    List<OutputElement> compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      OutputElement output = compOutputs[0];
      expect(output.name, 'output');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("String"));
    }
  }

  Future test_finalPropertyInputError() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '<p></p>')
class MyComponent {
  @Input() final int immutable = 1;
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_ANNOTATION_PLACEMENT_INVALID,
        code,
        "@Input()");
  }

  Future test_finalPropertyInputStringError() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '<p></p>', inputs: const ['immutable'])
class MyComponent {
  final int immutable = 1;
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    // validate. Can't easily assert position though because its all 'immutable'
    errorListener
        .assertErrorsWithCodes([StaticTypeWarningCode.UNDEFINED_SETTER]);
  }

  Future test_noDirectives() async {
    var source = newSource(
        '/test.dart',
        r'''
class A {}
class B {}
''');
    await getDirectives(source);
    expect(directives, isEmpty);
  }

  Future test_inputOnGetterIsError() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class MyComponent {
  @Input()
  String get someGetter => null;
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_ANNOTATION_PLACEMENT_INVALID,
        code,
        "@Input()");
  }

  Future test_outputOnSetterIsError() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class MyComponent {
  @Output()
  set someSetter(x) { }
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_ANNOTATION_PLACEMENT_INVALID,
        code,
        "@Output()");
  }

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
    Source source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.first;
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

  Future test_hasContentChildrenDirective() async {
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
    Source source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.first;
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

  Future test_hasContentChildChildrenNoRangeNotRecorded() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren()
  QueryList<ContentChildComp> contentChildren;
  @ContentChild()
  ContentChildComp contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    Source source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.first;
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

  Future test_hasContentChildChildrenSetter() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ContentChildComp) // 1
  void set contentChild(ContentChildComp contentChild) => null;
  @ContentChildren(ContentChildComp) // 2
  void set contentChildren(QueryList<ContentChildComp> contentChildren) => null;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    Source source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.first;

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
        equals(code.indexOf("QueryList<ContentChildComp>")));
    expect(children.typeRange.length,
        equals("QueryList<ContentChildComp>".length));

    errorListener.assertNoErrors();
  }
}

@reflectiveTest
class BuildUnitViewsTest extends AbstractAngularTest {
  List<AbstractDirective> directives;
  List<View> views;
  List<AnalysisError> errors;

  Future getViews(Source source) async {
    final dartResult = await dartDriver.getResult(source.fullName);
    fillErrorListener(dartResult.errors);
    final result = await angularDriver.getDirectives(source.fullName);
    directives = result.directives;

    final linker = new ChildDirectiveLinker(
        angularDriver,
        await angularDriver.getStandardAngular(),
        new ErrorReporter(errorListener, source));
    await linker.linkDirectives(directives, dartResult.unit.element.library);
    views = directives
        .map((d) => d is Component ? d.view : null)
        .where((d) => d != null)
        .toList();
    errors = result.errors;
    fillErrorListener(errors);
  }

  Future test_buildViewsDoesntGetDependentDirectives() async {
    String code = r'''
import 'package:angular2/angular2.dart';
import 'other_file.dart';

@Component(selector: 'my-component', template: 'My template',
    directives: const [OtherComponent])
class MyComponent {}
''';
    String otherCode = r'''
import 'package:angular2/angular2.dart';
@Component(selector: 'other-component', template: 'My template',
    directives: const [NgFor])
class OtherComponent {}
''';
    var source = newSource('/test.dart', code);
    newSource('/other_file.dart', otherCode);
    await getViews(source);
    {
      View view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.directives, hasLength(1));
      }

      // shouldn't be run yet
      for (AbstractDirective directive in view.directives) {
        if (directive is Component) {
          expect(directive.view.directives, hasLength(0));
        }
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  Future test_directives() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getViews(source);
    {
      View view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.directives, hasLength(3));
        List<String> directiveClassNames = view.directives
            .map((directive) => directive.classElement.name)
            .toList();
        expect(directiveClassNames,
            unorderedEquals(['DirectiveA', 'DirectiveB', 'DirectiveC']));
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  Future test_prefixedDirectives() async {
    String otherCode = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: '[aaa]')
class DirectiveA {}

@Directive(selector: '[bbb]')
class DirectiveB {}

@Directive(selector: '[ccc]')
class DirectiveC {}

const DIR_AB = const [DirectiveA, DirectiveB];
''';

    String code = r'''
import 'package:angular2/angular2.dart';
import 'other.dart' as other;

@Component(selector: 'my-component', template: 'My template',
    directives: const [other.DIR_AB, other.DirectiveC])
class MyComponent {}
''';
    var source = newSource('/test.dart', code);
    newSource('/other.dart', otherCode);
    await getViews(source);
    {
      View view = getViewByClassName(views, 'MyComponent');
      {
        expect(view.directives, hasLength(3));
        List<String> directiveClassNames = view.directives
            .map((directive) => directive.classElement.name)
            .toList();
        expect(directiveClassNames,
            unorderedEquals(['DirectiveA', 'DirectiveB', 'DirectiveC']));
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  Future test_directives_hasError_notListVariable() async {
    String code = r'''
import 'package:angular2/angular2.dart';

const NOT_DIRECTIVE_LIST = 42;

@Component(selector: 'my-component', template: 'My template',
   directives: const [NOT_DIRECTIVE_LIST])
class MyComponent {}
''';
    var source = newSource('/test.dart', code);
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE]);
  }

  Future test_hasError_ComponentAnnotationMissing() async {
    var source = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

@View(template: 'AAA')
class ComponentA {
}
''');
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.COMPONENT_ANNOTATION_MISSING]);
  }

  Future test_hasError_StringValueExpected() async {
    var source = newSource(
        '/test.dart',
        r'''
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

  Future test_constantExpressionTemplateOk() async {
    var source = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', template: 'abc' + 'bcd')
class ComponentA {
}
''');
    await getViews(source);
    errorListener.assertNoErrors();
  }

  Future test_constantExpressionTemplateComplexIsOnlyError() async {
    var source = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

const String tooComplex = 'bcd';

@Component(selector: 'aaa', template: 'abc' + tooComplex + "{{invalid {{stuff")
class ComponentA {
}
''');
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.STRING_VALUE_EXPECTED]);
  }

  Future test_hasError_TypeLiteralExpected() async {
    var source = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', template: 'AAA', directives: const [42])
class ComponentA {
}
''');
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TYPE_LITERAL_EXPECTED]);
  }

  Future test_hasError_TemplateAndTemplateUrlDefined() async {
    var source = newSource(
        '/test.dart',
        r'''
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

  Future test_hasError_NeitherTemplateNorTemplateUrlDefined() async {
    var source = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa')
class ComponentA {
}
''');
    await getViews(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.NO_TEMPLATE_URL_OR_TEMPLATE_DEFINED]);
  }

  Future test_hasError_missingHtmlFile() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', templateUrl: 'missing-template.html')
class MyComponent {}
''';
    var dartSource = newSource('/test.dart', code);
    await getViews(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.REFERENCED_HTML_FILE_DOESNT_EXIST,
        code,
        "'missing-template.html'");
  }

  Future test_templateExternal() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', templateUrl: 'my-template.html')
class MyComponent {}
''';
    var dartSource = newSource('/test.dart', code);
    var htmlSource = newSource('/my-template.html', '');
    await getViews(dartSource);
    expect(views, hasLength(1));
    // MyComponent
    View view = getViewByClassName(views, 'MyComponent');
    expect(view.component, getComponentByClassName(directives, 'MyComponent'));
    expect(view.templateText, isNull);
    expect(view.templateUriSource, isNotNull);
    expect(view.templateUriSource, htmlSource);
    expect(view.templateSource, htmlSource);
    {
      String url = "'my-template.html'";
      expect(view.templateUrlRange,
          new SourceRange(code.indexOf(url), url.length));
    }
  }

  Future test_templateExternalUsingViewAnnotation() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component')
@View(templateUrl: 'my-template.html')
class MyComponent {}
''';
    var dartSource = newSource('/test.dart', code);
    var htmlSource = newSource('/my-template.html', '');
    await getViews(dartSource);
    expect(views, hasLength(1));
    // MyComponent
    View view = getViewByClassName(views, 'MyComponent');
    expect(view.component, getComponentByClassName(directives, 'MyComponent'));
    expect(view.templateText, isNull);
    expect(view.templateUriSource, isNotNull);
    expect(view.templateUriSource, htmlSource);
    expect(view.templateSource, htmlSource);
    {
      String url = "'my-template.html'";
      expect(view.templateUrlRange,
          new SourceRange(code.indexOf(url), url.length));
    }
  }

  Future test_templateInline() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: 'my-directive')
class MyDirective {}

@Component(selector: 'other-component', template: 'Other template')
class OtherComponent {}

@Component(selector: 'my-component', template: 'My template',
    directives: const [MyDirective, OtherComponent])
class MyComponent {}
''';
    var source = newSource('/test.dart', code);
    await getViews(source);
    expect(views, hasLength(2));
    {
      View view = getViewByClassName(views, 'MyComponent');
      expect(
          view.component, getComponentByClassName(directives, 'MyComponent'));
      expect(view.templateText, ' My template '); // spaces preserve offsets
      expect(view.templateOffset, code.indexOf('My template') - 1);
      expect(view.templateUriSource, isNull);
      expect(view.templateSource, source);
      {
        expect(view.directives, hasLength(2));
        List<String> directiveClassNames = view.directives
            .map((directive) => directive.classElement.name)
            .toList();
        expect(directiveClassNames,
            unorderedEquals(['OtherComponent', 'MyDirective']));
      }
    }
  }

  Future test_templateInlineUsingViewAnnotation() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Directive(selector: 'my-directive')
class MyDirective {}

@Component(selector: 'other-component')
@View(template: 'Other template')
class OtherComponent {}

@Component(selector: 'my-component')
@View(template: 'My template', directives: const [MyDirective, OtherComponent])
class MyComponent {}
''';
    var source = newSource('/test.dart', code);
    await getViews(source);
    expect(views, hasLength(2));
    {
      View view = getViewByClassName(views, 'MyComponent');
      expect(
          view.component, getComponentByClassName(directives, 'MyComponent'));
      expect(view.templateText, ' My template '); // spaces preserve offsets
      expect(view.templateOffset, code.indexOf('My template') - 1);
      expect(view.templateUriSource, isNull);
      expect(view.templateSource, source);
      {
        expect(view.directives, hasLength(2));
        List<String> directiveClassNames = view.directives
            .map((directive) => directive.classElement.name)
            .toList();
        expect(directiveClassNames,
            unorderedEquals(['OtherComponent', 'MyDirective']));
      }
    }
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType child = childs.first.query;

    expect(child.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  Future test_hasContentChildrenDirective() async {
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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  Future test_hasContentChildChildrenSetter() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(ContentChildComp) // 1
  void set contentChild(ContentChildComp contentChild) => null;
  @ContentChildren(ContentChildComp) // 2
  void set contentChildren(QueryList<ContentChildComp> contentChildren) => null;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;

    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));

    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType child = childs.first.query;

    expect(child.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  Future test_hasContentChildLetBound() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild('foo')
  ContentChildComp contentChildDirective;
  @ContentChild('fooTpl')
  TemplateRef contentChildTpl;
  @ContentChild('fooElem')
  ElementRef contentChildElem;
  @ContentChild('fooDynamic')
  dynamic contentChildDynamic;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(4));

    final LetBoundQueriedChildType childDirective = childs
        .singleWhere((c) => c.field.fieldName == "contentChildDirective")
        .query;
    expect(childDirective, new isInstanceOf<LetBoundQueriedChildType>());
    expect(childDirective.letBoundName, equals("foo"));
    expect(childDirective.containerType.toString(), equals("ContentChildComp"));

    final LetBoundQueriedChildType childTemplate =
        childs.singleWhere((c) => c.field.fieldName == "contentChildTpl").query;
    expect(childTemplate, new isInstanceOf<LetBoundQueriedChildType>());
    expect(childTemplate.letBoundName, equals("fooTpl"));
    expect(childTemplate.containerType.toString(), equals("TemplateRef"));

    final LetBoundQueriedChildType childElement = childs
        .singleWhere((c) => c.field.fieldName == "contentChildElem")
        .query;
    expect(childElement, new isInstanceOf<LetBoundQueriedChildType>());
    expect(childElement.letBoundName, equals("fooElem"));
    expect(childElement.containerType.toString(), equals("ElementRef"));

    final LetBoundQueriedChildType childDynamic = childs
        .singleWhere((c) => c.field.fieldName == "contentChildDynamic")
        .query;
    expect(childDynamic, new isInstanceOf<LetBoundQueriedChildType>());
    expect(childDynamic.letBoundName, equals("fooDynamic"));
    expect(childDynamic.containerType.toString(), equals("dynamic"));

    // validate
    errorListener.assertNoErrors();
  }

  Future test_hasContentChildrenLetBound() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren('foo')
  QueryList<ContentChildComp> contentChildDirective;
  @ContentChildren('fooTpl')
  QueryList<TemplateRef> contentChildTpl;
  @ContentChildren('fooElem')
  QueryList<ElementRef> contentChildElem;
  @ContentChildren('fooDynamic')
  QueryList contentChildDynamic;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(4));

    final LetBoundQueriedChildType childrenDirective = childrens
        .singleWhere((c) => c.field.fieldName == "contentChildDirective")
        .query;
    expect(childrenDirective, new isInstanceOf<LetBoundQueriedChildType>());
    expect(childrenDirective.letBoundName, equals("foo"));
    expect(
        childrenDirective.containerType.toString(), equals("ContentChildComp"));

    final LetBoundQueriedChildType childrenTemplate = childrens
        .singleWhere((c) => c.field.fieldName == "contentChildTpl")
        .query;
    expect(childrenTemplate, new isInstanceOf<LetBoundQueriedChildType>());
    expect(childrenTemplate.letBoundName, equals("fooTpl"));
    expect(childrenTemplate.containerType.toString(), equals("TemplateRef"));

    final LetBoundQueriedChildType childrenElement = childrens
        .singleWhere((c) => c.field.fieldName == "contentChildElem")
        .query;
    expect(childrenElement, new isInstanceOf<LetBoundQueriedChildType>());
    expect(childrenElement.letBoundName, equals("fooElem"));
    expect(childrenElement.containerType.toString(), equals("ElementRef"));

    final LetBoundQueriedChildType childrenDynamic = childrens
        .singleWhere((c) => c.field.fieldName == "contentChildDynamic")
        .query;
    expect(childrenDynamic, new isInstanceOf<LetBoundQueriedChildType>());
    expect(childrenDynamic.letBoundName, equals("fooDynamic"));
    expect(childrenDynamic.containerType.toString(), equals("dynamic"));

    // validate
    errorListener.assertNoErrors();
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, new isInstanceOf<ElementRefQueriedChildType>());

    // validate
    errorListener.assertNoErrors();
  }

  Future test_hasContentChildrenElementRef() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ElementRef)
  QueryList<ElementRef> contentChildren;
}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<ElementRefQueriedChildType>());

    // validate
    errorListener.assertNoErrors();
  }

  Future test_hasContentChildrenTemplateRef() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(TemplateRef)
  QueryList<TemplateRef> contentChildren;
}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<TemplateRefQueriedChildType>());

    // validate
    errorListener.assertNoErrors();
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, new isInstanceOf<TemplateRefQueriedChildType>());

    // validate
    errorListener.assertNoErrors();
  }

  Future test_hasContentChildDirective_notRecognizedType() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(String)
  ElementRef contentChild;
}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(0));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNKNOWN_CHILD_QUERY_TYPE, code, 'String');
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(0));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNKNOWN_CHILD_QUERY_TYPE, code, 'AnchorElement');
  }

  Future test_hasContentChildDirective_notTypeOrString() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChild(const [])
  ElementRef contentChild;
}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(0));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNKNOWN_CHILD_QUERY_TYPE, code, 'const []');
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType child = childs.first.query;
    expect(child.directive, equals(directives[1]));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY, code, 'String');
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType child = childs.first.query;

    expect(child.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childs = component.contentChilds;
    expect(childs, hasLength(1));
    expect(childs.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType child = childs.first.query;
    expect(child.directive, equals(directives[1]));

    // validate
    assertErrorInCodeAtPosition(AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
        code, 'ContentChildCompSub');
  }

  Future test_hasContentChildrenDirective_notQueryList() async {
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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;
    expect(children.directive, equals(directives[1]));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_OR_VIEW_CHILDREN_REQUIRES_QUERY_LIST,
        code,
        'String');
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  Future test_hasContentChildrenDirective_notAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  QueryList<String> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
        code, 'QueryList<String>');
  }

  Future test_hasContentChildrenDirective_dynamicListOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  QueryList contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
        code, 'Iterable<String>');
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  Future test_hasContentChildrenDirective_subtypingQueryListNotOk() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ContentChildComp)
  // this is not allowed. Angular makes a QueryList, regardless of your subtype
  CannotSubtypeQueryList contentChild;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}

abstract class CannotSubtypeQueryList extends QueryList {}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);
    Component component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;
    expect(children.directive, equals(directives[1]));

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_OR_VIEW_CHILDREN_REQUIRES_QUERY_LIST,
        code,
        'CannotSubtypeQueryList');
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY, code, 'String');
  }

  Future test_hasContentChildrenTemplateRef_notAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(TemplateRef)
  QueryList<String> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
        code, 'QueryList<String>');
  }

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
    Source source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY, code, 'String');
  }

  Future test_hasContentChildrenElementRef_notAssignable() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class ComponentA {
  @ContentChildren(ElementRef)
  QueryList<String> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    Source source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
        code, 'QueryList<String>');
  }
}

@reflectiveTest
class ResolveDartTemplatesTest extends AbstractAngularTest {
  List<AbstractDirective> directives;
  List<Template> templates;
  List<AnalysisError> errors;

  Future getDirectives(Source source) async {
    final dartResult = await dartDriver.getResult(source.fullName);
    fillErrorListener(dartResult.errors);
    final ngResult = await angularDriver.resolveDart(source.fullName);
    directives = ngResult.directives;
    errors = ngResult.errors;
    fillErrorListener(errors);
    templates = directives
        .map((d) => d is Component ? d.view?.template : null)
        .where((d) => d != null)
        .toList();
  }

  Future test_hasError_DirectiveTypeLiteralExpected() async {
    var source = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'aaa', template: 'AAA', directives: const [int])
class ComponentA {
}
''');
    await getDirectives(source);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE]);
  }

  Future test_componentReference() async {
    var code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component componentA = getComponentByClassName(directives, 'ComponentA');
    Component componentB = getComponentByClassName(directives, 'ComponentB');
    // validate
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
            getResolvedRangeAtString(code, ranges, 'my-aaa></');
        assertComponentReference(resolvedRange, componentA);
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'my-aaa>1');
        assertComponentReference(resolvedRange, componentA);
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'my-bbb></');
        assertComponentReference(resolvedRange, componentB);
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'my-bbb>2');
        assertComponentReference(resolvedRange, componentB);
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  Future test_hasError_expression_ArgumentTypeNotAssignable() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel',
    template: r"<div> {{text.length + text}} </div>")
class TextPanel {
  String text;
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertErrorsWithCodes(
        [StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE]);
  }

  Future test_hasError_expression_UndefinedIdentifier() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener
        .assertErrorsWithCodes([StaticWarningCode.UNDEFINED_IDENTIFIER]);
  }

  Future
      test_hasError_expression_UndefinedIdentifier_OutsideFirstHtmlTag() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '<h1></h1>{{noSuchName}}')
class MyComponent {
}
''';

    var source = newSource('/test.dart', code);
    await getDirectives(source);
    assertErrorInCodeAtPosition(
        StaticWarningCode.UNDEFINED_IDENTIFIER, code, 'noSuchName');
  }

  Future test_hasError_UnresolvedTag() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa',
    template: "<unresolved-tag attr='value'></unresolved-tag>")
class ComponentA {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNRESOLVED_TAG, code, 'unresolved-tag');
  }

  Future test_suppressError_UnresolvedTag() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa',
    template: """
<!-- @ngIgnoreErrors: UNRESOLVED_TAG -->
<unresolved-tag attr='value'></unresolved-tag>""")
class ComponentA {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertNoErrors();
  }

  Future test_suppressError_NotCaseSensitive() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa',
    template: """
<!-- @ngIgnoreErrors: UnReSoLvEd_tAg -->
<unresolved-tag attr='value'></unresolved-tag>""")
class ComponentA {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertNoErrors();
  }

  Future test_suppressError_UnresolvedTagAndInput() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa',
    template: """
<!-- @ngIgnoreErrors: UNRESOLVED_TAG, NONEXIST_INPUT_BOUND -->
<unresolved-tag [attr]='value'></unresolved-tag>""")
class ComponentA {
  Object value;
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertNoErrors();
  }

  Future test_htmlParsing_hasError() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel',
    template: r"<div> <h2> Expected closing H2 </h3> </div>")
class TextPanel {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    // has errors
    errorListener.assertErrorsWithCodes([HtmlErrorCode.PARSE_ERROR]);
  }

  Future test_input_OK_event() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(templates, hasLength(1));
    {
      Template template = _getDartTemplateByClassName(templates, 'TodoList');
      List<ResolvedRange> ranges = template.ranges;
      expect(ranges, hasLength(4));
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, r'gotClicked($');
        expect(resolvedRange.range.length, 'gotClicked'.length);
        Element element = (resolvedRange.element as DartElement).element;
        expect(element, new isInstanceOf<MethodElement>());
        expect(element.name, 'gotClicked');
        expect(
            element.nameOffset, code.indexOf('gotClicked(MouseEvent event)'));
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, r"$event)'>");
        expect(resolvedRange.range.length, r'$event'.length);
        Element element = (resolvedRange.element as LocalVariable).dartVariable;
        expect(element, new isInstanceOf<LocalVariableElement>());
        expect(element.name, r'$event');
        expect(element.nameOffset, -1);
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'click');
        expect(resolvedRange.range.length, 'click'.length);
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  Future test_input_OK_reference_expression() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component textPanel = getComponentByClassName(directives, 'TextPanel');
    // validate
    expect(templates, hasLength(2));
    {
      Template template = _getDartTemplateByClassName(templates, 'UserPanel');
      List<ResolvedRange> ranges = template.ranges;
      expect(ranges, hasLength(5));
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'text]=');
        expect(resolvedRange.range.length, 'text'.length);
        assertPropertyReference(resolvedRange, textPanel, 'text');
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'user.');
        expect(resolvedRange.range.length, 'user'.length);
        Element element = (resolvedRange.element as DartElement).element;
        expect(element, new isInstanceOf<PropertyAccessorElement>());
        expect(element.name, 'user');
        expect(element.nameOffset, code.indexOf('user; // 1'));
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, "name'>");
        expect(resolvedRange.range.length, 'name'.length);
        Element element = (resolvedRange.element as DartElement).element;
        expect(element, new isInstanceOf<PropertyAccessorElement>());
        expect(element.name, 'name');
        expect(element.nameOffset, code.indexOf('name; // 2'));
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  Future test_input_OK_reference_text() async {
    String code = r'''
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
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component componentA = getComponentByClassName(directives, 'ComponentA');
    // validate
    expect(templates, hasLength(2));
    {
      Template template = _getDartTemplateByClassName(templates, 'ComponentB');
      List<ResolvedRange> ranges = template.ranges;
      expect(ranges, hasLength(4));
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'firstValue]=');
        expect(resolvedRange.range.length, 'firstValue'.length);
        assertPropertyReference(resolvedRange, componentA, 'firstValue');
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'second]=');
        expect(resolvedRange.range.length, 'second'.length);
        assertPropertyReference(resolvedRange, componentA, 'second');
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  Future test_noRootElement() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel',
    template: r'Often used without an element in tests.')
class TextPanel {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(templates, hasLength(1));
    // has errors
    errorListener.assertNoErrors();
  }

  Future test_noTemplateContents() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel',
    template: '')
class TextPanel {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(templates, hasLength(1));
    // has errors
    errorListener.assertNoErrors();
  }

  Future test_textExpression_hasError_UnterminatedMustache() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"<div> {{text </div>")
class TextPanel {
  String text = "text";
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    // has errors
    errorListener
        .assertErrorsWithCodes([AngularWarningCode.UNTERMINATED_MUSTACHE]);
  }

  Future test_textExpression_hasError_UnopenedMustache() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"<div> text}} </div>")
class TextPanel {
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    // has errors
    errorListener.assertErrorsWithCodes([AngularWarningCode.UNOPENED_MUSTACHE]);
  }

  Future test_textExpression_hasError_DoubleOpenedMustache() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"<div> {{text {{ error}} </div>")
class TextPanel {
  String text;
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertErrorsWithCodes([
      AngularWarningCode.UNTERMINATED_MUSTACHE,
      StaticWarningCode.UNDEFINED_IDENTIFIER
    ]);
  }

  Future test_textExpression_hasError_MultipleUnclosedMustaches() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"<div> {{open {{error {{text}} close}} close}} </div>")
class TextPanel {
  String text, open, close;
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    errorListener.assertErrorsWithCodes([
      AngularWarningCode.UNTERMINATED_MUSTACHE,
      AngularWarningCode.UNTERMINATED_MUSTACHE,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      AngularWarningCode.UNOPENED_MUSTACHE,
      AngularWarningCode.UNOPENED_MUSTACHE
    ]);
  }

  Future test_textExpression_OK() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', inputs: const ['text'],
    template: r"<div> <h2> {{text}}  </h2> and {{text.length}} </div>")
class TextPanel {
  String text; // 1
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    expect(templates, hasLength(1));
    {
      Template template = _getDartTemplateByClassName(templates, 'TextPanel');
      List<ResolvedRange> ranges = template.ranges;
      expect(ranges, hasLength(5));
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'text}}');
        expect(resolvedRange.range.length, 'text'.length);
        PropertyAccessorElement element = assertGetter(resolvedRange);
        expect(element.name, 'text');
        expect(element.nameOffset, code.indexOf('text; // 1'));
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'text.length');
        expect(resolvedRange.range.length, 'text'.length);
        PropertyAccessorElement element = assertGetter(resolvedRange);
        expect(element.name, 'text');
        expect(element.nameOffset, code.indexOf('text; // 1'));
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'length}}');
        expect(resolvedRange.range.length, 'length'.length);
        PropertyAccessorElement element = assertGetter(resolvedRange);
        expect(element.name, 'length');
        expect(element.enclosingElement.name, 'String');
      }
    }
    // no errors
    errorListener.assertNoErrors();
  }

  Future test_resolveGetChildDirectivesNgContentSelectors() async {
    String code = r'''
import 'package:angular2/angular2.dart';
import 'child_file.dart';

@Component(selector: 'my-component', template: 'My template',
    directives: const [ChildComponent])
class MyComponent {}
''';
    String childCode = r'''
import 'package:angular2/angular2.dart';
@Component(selector: 'child-component',
    template: 'My template <ng-content></ng-content>',
    directives: const [])
class ChildComponent {}
''';
    var source = newSource('/test.dart', code);
    newSource('/child_file.dart', childCode);
    await getDirectives(source);
    expect(templates, hasLength(1));
    // no errors
    errorListener.assertNoErrors();

    List<AbstractDirective> childDirectives = templates.first.view.directives;
    expect(childDirectives, hasLength(1));

    List<View> childViews = childDirectives
        .map((d) => d is Component ? d.view : null)
        .where((v) => v != null)
        .toList();
    expect(childViews, hasLength(1));
    View childView = childViews.first;
    expect(childView.component, isNotNull);
    expect(childView.component.ngContents, hasLength(1));
  }

  Future test_attributes() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class MyComponent {
  MyComponent(@Attribute("my-attr") String foo);
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.single;
    List<AngularElement> attributes = component.attributes;
    expect(attributes, hasLength(1));
    {
      AngularElement attribute = attributes[0];
      expect(attribute.name, 'my-attr');
      // TODO better offsets here. But its really not that critical
      expect(attribute.nameOffset, code.indexOf("foo"));
      expect(attribute.nameLength, "foo".length);
    }
    errorListener.assertNoErrors();
  }

  Future test_attributeNotString() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component', template: '')
class MyComponent {
  MyComponent(@Attribute("my-attr") int foo);
}
''';
    var source = newSource('/test.dart', code);
    await getDirectives(source);
    Component component = directives.single;
    List<AngularElement> attributes = component.attributes;
    expect(attributes, hasLength(1));
    {
      AngularElement attribute = attributes[0];
      expect(attribute.name, 'my-attr');
      // TODO better offsets here. But its really not that critical
      expect(attribute.nameOffset, code.indexOf("foo"));
      expect(attribute.nameLength, "foo".length);
    }
    assertErrorInCodeAtPosition(
        AngularWarningCode.ATTRIBUTE_PARAMETER_MUST_BE_STRING, code, 'foo');
  }

  Future test_constantExpressionTemplateVarDoesntCrash() async {
    Source source = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

const String tplText = "we don't analyze this";

@Component(selector: 'aaa', template: tplText)
class ComponentA {
}
''');
    await getDirectives(source);
    expect(templates, hasLength(0));
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.STRING_VALUE_EXPECTED]);
  }

  static Template _getDartTemplateByClassName(
      List<Template> templates, String className) {
    return templates.firstWhere(
        (template) => template.view.classElement.name == className, orElse: () {
      fail('Template with the class "$className" was not found.');
      return null;
    });
  }
}

@reflectiveTest
class ResolveHtmlTemplatesTest extends AbstractAngularTest {
  List<Template> templates;
  Future getDirectives(Source htmlSource, List<Source> dartSources) async {
    for (final dartSource in dartSources) {
      final result = await angularDriver.resolveDart(dartSource.fullName);
      fillErrorListener(result.errors);
    }
    final result2 = await angularDriver.resolveHtml(htmlSource.fullName);
    fillErrorListener(result2.errors);
    templates = result2.directives
        .map((d) => d is Component ? d.view?.template : null)
        .where((d) => d != null);
  }

  Future test_multipleViewsWithTemplate() async {
    String dartCodeOne = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panelA', templateUrl: 'text_panel.html')
class TextPanelA {
  String text; // A
}
''';

    String dartCodeTwo = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panelB', templateUrl: 'text_panel.html')
class TextPanelB {
  String text; // B
}
''';
    String htmlCode = r"""
<div>
  {{text}}
</div>
""";
    var dartSourceOne = newSource('/test1.dart', dartCodeOne);
    var dartSourceTwo = newSource('/test2.dart', dartCodeTwo);
    var htmlSource = newSource('/text_panel.html', htmlCode);
    await getDirectives(htmlSource, [dartSourceOne, dartSourceTwo]);
    expect(templates, hasLength(2));
    // validate templates
    bool hasTextPanelA = false;
    bool hasTextPanelB = false;
    for (HtmlTemplate template in templates) {
      String viewClassName = template.view.classElement.name;
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
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(htmlCode, template.ranges, 'text}}');
        PropertyAccessorElement element = assertGetter(resolvedRange);
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
    final result = await angularDriver.resolveDart(dartSource.fullName);
    fillErrorListener(result.errors);
    final result2 = await angularDriver.resolveHtml(htmlSource.fullName);
    fillErrorListener(result2.errors);
    views = result2.directives
        .map((d) => d is Component ? d.view : null)
        .where((v) => v != null);
  }

  Future test_suppressError_UnresolvedTagHtmlTemplate() async {
    var dartSource = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa', templateUrl: 'test.html')
class ComponentA {
}
''');
    var htmlSource = newSource(
        '/test.html',
        '''
<!-- @ngIgnoreErrors: UNRESOLVED_TAG -->
<unresolved-tag attr='value'></unresolved-tag>""")
''');
    await getDirectives(htmlSource, dartSource);
    errorListener.assertNoErrors();
  }

  Future test_errorFromWeirdInclude_includesFromPath() async {
    String code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa', templateUrl: "test.html")
class ComponentA {
}
''';
    var dartSource = newSource('/weird.dart', code);
    var htmlSource =
        newSource('/test.html', "<unresolved-tag></unresolved-tag>");
    await getDirectives(htmlSource, dartSource);
    final errors = errorListener.errors;
    expect(errors, hasLength(1));
    expect(errors.first, new isInstanceOf<FromFilePrefixedError>());
    expect(errors.first.message,
        equals('Unresolved tag "unresolved-tag" (from /weird.dart)'));
  }

  Future test_hasViewWithTemplate() async {
    String dartCode = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'text-panel', templateUrl: 'text_panel.html')
class TextPanel {
  String text; // 1
}
''';
    String htmlCode = r"""
<div>
  {{text}}
</div>
""";
    var dartSource = newSource('/test.dart', dartCode);
    var htmlSource = newSource('/text_panel.html', htmlCode);
    // compute
    await getDirectives(htmlSource, dartSource);
    expect(views, hasLength(1));
    {
      View view = getViewByClassName(views, 'TextPanel');
      expect(view.templateUriSource, isNotNull);
      // resolve this View
      Template template = view.template;
      expect(template, isNotNull);
      expect(template.view, view);
      expect(template.ranges, hasLength(1));
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(htmlCode, template.ranges, 'text}}');
        PropertyAccessorElement element = assertGetter(resolvedRange);
        expect(element.name, 'text');
        expect(element.nameOffset, dartCode.indexOf('text; // 1'));
      }
    }
  }

  Future test_resolveGetChildDirectivesNgContentSelectors() async {
    String code = r'''
import 'package:angular2/angular2.dart';
import 'child_file.dart';

import 'package:angular2/angular2.dart';
@Component(selector: 'my-component', templateUrl: 'test.html',
    directives: const [ChildComponent])
class MyComponent {}
''';
    String childCode = r'''
import 'package:angular2/angular2.dart';
@Component(selector: 'child-component',
    template: 'My template <ng-content></ng-content>',
    directives: const [])
class ChildComponent {}
''';
    var dartSource = newSource('/test.dart', code);
    newSource('/child_file.dart', childCode);
    var htmlSource = newSource('/test.html', '');
    await getDirectives(htmlSource, dartSource);

    List<AbstractDirective> childDirectives = views.first.directives;
    expect(childDirectives, hasLength(1));

    View childView = (views.first.directives.first as Component).view;
    expect(childView.component, isNotNull);
    expect(childView.component.ngContents, hasLength(1));
  }
}
