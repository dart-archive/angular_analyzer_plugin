import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_ast/angular_ast.dart';
import 'package:angular_analyzer_plugin/src/from_file_prefixed_error.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/view_extraction.dart';
import 'package:angular_analyzer_plugin/src/directive_linking.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';

import 'abstract_angular.dart';

void main() {
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
      }
      expect(outputElements, hasLength(0));
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
      expect(outputElement.eventType.toString(), equals('MouseEvent'));
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
  }
}

@reflectiveTest
class BuildUnitDirectivesTest extends AbstractAngularTest {
  List<AbstractDirective> directives;
  List<AnalysisError> errors;

  Future getDirectives(final source) async {
    final dartResult = await dartDriver.getResult(source.fullName);
    fillErrorListener(dartResult.errors);
    final result = await angularDriver.getDirectives(source.fullName);
    directives = result.directives;
    errors = result.errors;
    fillErrorListener(errors);
  }

  // ignore: non_constant_identifier_names
  Future test_Component() async {
    final source = newSource(
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
      final component = directives[0];
      expect(component, new isInstanceOf<Component>());
      {
        final selector = component.selector;
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-a');
      }
      {
        expect(component.elementTags, hasLength(1));
        final selector = component.elementTags[0];
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-a');
      }
    }
    {
      final component = directives[1];
      expect(component, new isInstanceOf<Component>());
      {
        final selector = component.selector;
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-b');
      }
      {
        expect(component.elementTags, hasLength(1));
        final selector = component.elementTags[0];
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'comp-b');
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_Directive() async {
    final source = newSource(
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
      final directive = directives[0];
      expect(directive, new isInstanceOf<Directive>());
      {
        final selector = directive.selector;
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-a');
      }
      {
        expect(directive.elementTags, hasLength(1));
        final selector = directive.elementTags[0];
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-a');
      }
    }
    {
      final directive = directives[1];
      expect(directive, new isInstanceOf<Directive>());
      {
        final selector = directive.selector;
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-b');
      }
      {
        expect(directive.elementTags, hasLength(1));
        final selector = directive.elementTags[0];
        expect(selector, new isInstanceOf<ElementNameSelector>());
        expect(selector.toString(), 'dir-b');
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_Directive_elementTags_OrSelector() async {
    final source = newSource(
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
      final directive = directives[0];
      expect(directive, new isInstanceOf<Directive>());
      {
        final selector = directive.selector;
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
      final directive = directives[1];
      expect(directive, new isInstanceOf<Directive>());
      {
        final selector = directive.selector;
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

  // ignore: non_constant_identifier_names
  Future test_Directive_elementTags_AndSelector() async {
    final source = newSource(
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
      final directive = directives[0];
      expect(directive, new isInstanceOf<Directive>());
      {
        final selector = directive.selector;
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
      final directive = directives[1];
      expect(directive, new isInstanceOf<Directive>());
      {
        final selector = directive.selector;
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

  // ignore: non_constant_identifier_names
  Future test_Directive_elementTags_CompoundSelector() async {
    final source = newSource(
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
      final directive = directives[0];
      expect(directive, new isInstanceOf<Directive>());
      {
        final selector = directive.selector;
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
      final directive = directives[1];
      expect(directive, new isInstanceOf<Directive>());
      {
        final selector = directive.selector;
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
      final component = getComponentByClassName(directives, 'ComponentA');
      {
        final exportAs = component.exportAs;
        expect(exportAs.name, 'export-name');
        expect(exportAs.nameOffset, code.indexOf('export-name'));
      }
    }
    {
      final component = getComponentByClassName(directives, 'ComponentB');
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
      final directive = getDirectiveByClassName(directives, 'DirectiveA');
      {
        final exportAs = directive.exportAs;
        expect(exportAs.name, 'export-name');
        expect(exportAs.nameOffset, code.indexOf('export-name'));
      }
    }
    {
      final directive = getDirectiveByClassName(directives, 'DirectiveB');
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
    final source = newSource(
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

  // ignore: non_constant_identifier_names
  Future test_exportAs_constantStringExpressionOk() async {
    final source = newSource(
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

  // ignore: non_constant_identifier_names
  Future test_hasError_ArgumentSelectorMissing() async {
    final source = newSource(
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
    final source = newSource(
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

  // ignore: non_constant_identifier_names
  Future test_selector_constantExpressionOk() async {
    final source = newSource(
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

  // ignore: non_constant_identifier_names
  Future test_hasError_UndefinedSetter_fullSyntax() async {
    final source = newSource(
        '/test.dart',
        r'''
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
    final source = newSource(
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

  // ignore: non_constant_identifier_names
  Future test_hasError_UndefinedSetter_shortSyntax_noInputMade() async {
    final source = newSource(
        '/test.dart',
        r'''
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
  Future test_parameterizedInheritedInputsOutputs() async {
    final code = r'''
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
final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final compInputs = component.inputs;
    expect(compInputs, hasLength(1));
    {
      final input = compInputs[0];
      expect(input.name, 'input');
      expect(input.setterType, isNotNull);
      expect(input.setterType.toString(), equals("dynamic"));
    }

    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(1));
    {
      final output = compOutputs[0];
      expect(output.name, 'output');
      expect(output.eventType, isNotNull);
      expect(output.eventType.toString(), equals("dynamic"));
    }
  }

  // ignore: non_constant_identifier_names
  Future test_parameterizedInheritedInputsOutputsSpecified() async {
    final code = r'''
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
final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
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
final source = newSource(
        '/test.dart',
        r'''
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
  QueryList<ContentChildComp> contentChildren;
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
  void set contentChildren(QueryList<ContentChildComp> contentChildren) => null;
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

  Future getViews(final source) async {
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
        final directiveClassNames = view.directives
            .map((directive) => directive.classElement.name)
            .toList();
        expect(directiveClassNames,
            unorderedEquals(['DirectiveA', 'DirectiveB', 'DirectiveC']));
      }
    }
    // no errors
    errorListener.assertNoErrors();
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
        final directiveClassNames = view.directives
            .map((directive) => directive.classElement.name)
            .toList();
        expect(directiveClassNames,
            unorderedEquals(['DirectiveA', 'DirectiveB', 'DirectiveC']));
      }
    }
    // no errors
    errorListener.assertNoErrors();
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
  Future test_hasError_ComponentAnnotationMissing() async {
final source = newSource(
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

  // ignore: non_constant_identifier_names
  Future test_hasError_StringValueExpected() async {
final source = newSource(
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

  // ignore: non_constant_identifier_names
  Future test_constantExpressionTemplateOk() async {
final source = newSource(
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

  // ignore: non_constant_identifier_names
  Future test_constantExpressionTemplateComplexIsOnlyError() async {
final source = newSource(
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

  // ignore: non_constant_identifier_names
  Future test_hasError_TypeLiteralExpected() async {
final source = newSource(
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

  // ignore: non_constant_identifier_names
  Future test_hasError_TemplateAndTemplateUrlDefined() async {
final source = newSource(
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

  // ignore: non_constant_identifier_names
  Future test_hasError_NeitherTemplateNorTemplateUrlDefined() async {
final source = newSource(
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
    expect(view.component, getComponentByClassName(directives, 'MyComponent'));
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
  Future test_templateExternalUsingViewAnnotation() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-component')
@View(templateUrl: 'my-template.html')
class MyComponent {}
''';
    final dartSource = newSource('/test.dart', code);
    final htmlSource = newSource('/my-template.html', '');
    await getViews(dartSource);
    expect(views, hasLength(1));
    // MyComponent
    final view = getViewByClassName(views, 'MyComponent');
    expect(view.component, getComponentByClassName(directives, 'MyComponent'));
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
      expect(
          view.component, getComponentByClassName(directives, 'MyComponent'));
      expect(view.templateText, ' My template '); // spaces preserve offsets
      expect(view.templateOffset, code.indexOf('My template') - 1);
      expect(view.templateUriSource, isNull);
      expect(view.templateSource, source);
      {
        expect(view.directives, hasLength(2));
        final directiveClassNames = view.directives
            .map((directive) => directive.classElement.name)
            .toList();
        expect(directiveClassNames,
            unorderedEquals(['OtherComponent', 'MyDirective']));
      }
    }
  }

  // ignore: non_constant_identifier_names
  Future test_templateInlineUsingViewAnnotation() async {
    final code = r'''
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
final source = newSource('/test.dart', code);
    await getViews(source);
    expect(views, hasLength(2));
    {
      final view = getViewByClassName(views, 'MyComponent');
      expect(
          view.component, getComponentByClassName(directives, 'MyComponent'));
      expect(view.templateText, ' My template '); // spaces preserve offsets
      expect(view.templateOffset, code.indexOf('My template') - 1);
      expect(view.templateUriSource, isNull);
      expect(view.templateSource, source);
      {
        expect(view.directives, hasLength(2));
        final directiveClassNames = view.directives
            .map((directive) => directive.classElement.name)
            .toList();
        expect(directiveClassNames,
            unorderedEquals(['OtherComponent', 'MyDirective']));
      }
    }
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
    expect(childs.first.query, new isInstanceOf<DirectiveQueriedChildType>());
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
  QueryList<ContentChildComp> contentChildren;
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
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
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
  void set contentChildren(QueryList<ContentChildComp> contentChildren) => null;
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

  // ignore: non_constant_identifier_names
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
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
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

  // ignore: non_constant_identifier_names
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
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
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
    expect(childs.first.query, new isInstanceOf<ElementRefQueriedChildType>());

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
  QueryList<ElementRef> contentChildren;
}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<ElementRefQueriedChildType>());

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
  QueryList<TemplateRef> contentChildren;
}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<TemplateRefQueriedChildType>());

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
    expect(childs.first.query, new isInstanceOf<TemplateRefQueriedChildType>());

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
    expect(childs.first.query, new isInstanceOf<DirectiveQueriedChildType>());
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
    expect(childs.first.query, new isInstanceOf<DirectiveQueriedChildType>());
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
    expect(childs.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType child = childs.first.query;
    expect(child.directive, equals(directives[1]));

    // validate
    assertErrorInCodeAtPosition(AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
        code, 'ContentChildCompSub');
  }

  // ignore: non_constant_identifier_names
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
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
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
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
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
  QueryList<String> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
        code, 'QueryList<String>');
  }

  // ignore: non_constant_identifier_names
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
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
    final childrens = component.contentChildren;
    expect(childrens, hasLength(1));
    expect(
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
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
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
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
        childrens.first.query, new isInstanceOf<DirectiveQueriedChildType>());
    final DirectiveQueriedChildType children = childrens.first.query;

    expect(children.directive, equals(directives[1]));
    // validate
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
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
    final source = newSource('/test.dart', code);
    await getViews(source);
    final component = directives.first;
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
  QueryList<String> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
    await getViews(source);

    // validate
    assertErrorInCodeAtPosition(AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
        code, 'QueryList<String>');
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
  QueryList<String> contentChildren;
}

@Component(selector: 'foo', template: '')
class ContentChildComp {}
''';
    final source = newSource('/test.dart', code);
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

  Future getDirectives(final source) async {
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

  // ignore: non_constant_identifier_names
  Future test_hasError_DirectiveTypeLiteralExpected() async {
final source = newSource(
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
    final componentA = getComponentByClassName(directives, 'ComponentA');
    final componentB = getComponentByClassName(directives, 'ComponentB');
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
        expect(element, new isInstanceOf<MethodElement>());
        expect(element.name, 'gotClicked');
        expect(
            element.nameOffset, code.indexOf('gotClicked(MouseEvent event)'));
      }
      {
        final resolvedRange =
            getResolvedRangeAtString(code, ranges, r"$event)'>");
        expect(resolvedRange.range.length, r'$event'.length);
        final element = (resolvedRange.element as LocalVariable).dartVariable;
        expect(element, new isInstanceOf<LocalVariableElement>());
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
    final textPanel = getComponentByClassName(directives, 'TextPanel');
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
        expect(element, new isInstanceOf<PropertyAccessorElement>());
        expect(element.name, 'user');
        expect(element.nameOffset, code.indexOf('user; // 1'));
      }
      {
        final resolvedRange = getResolvedRangeAtString(code, ranges, "name'>");
        expect(resolvedRange.range.length, 'name'.length);
        final element = (resolvedRange.element as DartElement).element;
        expect(element, new isInstanceOf<PropertyAccessorElement>());
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
    final componentA = getComponentByClassName(directives, 'ComponentA');
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
    final source = newSource(
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
          List<Template> templates, String className) =>
      templates.firstWhere(
          (template) => template.view.classElement.name == className,
          orElse: () {
        fail('Template with the class "$className" was not found.');
        return null;
      });
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
    final result = await angularDriver.resolveDart(dartSource.fullName);
    fillErrorListener(result.errors);
    final result2 = await angularDriver.resolveHtml(htmlSource.fullName);
    fillErrorListener(result2.errors);
    views = result2.directives
        .map((d) => d is Component ? d.view : null)
        .where((v) => v != null);
  }

  // ignore: non_constant_identifier_names
  Future test_suppressError_UnresolvedTagHtmlTemplate() async {
    final dartSource = newSource(
        '/test.dart',
        r'''
import 'package:angular2/angular2.dart';

@Component(selector: 'my-aaa', templateUrl: 'test.html')
class ComponentA {
}
''');
    final htmlSource = newSource(
        '/test.html',
        '''
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
class ComponentA {
}
''';
    final dartSource = newSource('/weird.dart', code);
    final htmlSource =
        newSource('/test.html', "<unresolved-tag></unresolved-tag>");
    await getDirectives(htmlSource, dartSource);
    final errors = errorListener.errors;
    expect(errors, hasLength(1));
    expect(errors.first, new isInstanceOf<FromFilePrefixedError>());
    expect(errors.first.message,
        equals('Unresolved tag "unresolved-tag" (from /weird.dart)'));
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
}
