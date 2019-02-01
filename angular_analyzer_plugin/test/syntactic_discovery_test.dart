import 'dart:async';

import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/errors.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/base_directive.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/component.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/directive.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/functional_directive.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/pipe.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/reference.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/top_level.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/syntactic_discovery.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'abstract_angular.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(SyntacticDiscoveryTest);
  });
}

@reflectiveTest
class SyntacticDiscoveryTest extends AbstractAngularTest {
  List<TopLevel> topLevels;
  List<BaseDirective> directives;
  List<Pipe> pipes;
  List<AnalysisError> errors;

  Future getDirectives(final Source source) async {
    final dartResult = await dartDriver.getResult(source.fullName);
    fillErrorListener(dartResult.errors);
    final extractor = SyntacticDiscovery(dartResult.unit, source);
    topLevels = extractor.discoverAngularTopLevels();
    directives = topLevels.whereType<BaseDirective>().toList();
    pipes = extractor.discoverPipes();
    fillErrorListener(extractor.errorListener.errors);
  }

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
      final component = getSyntacticComponentByName(directives, 'ComponentA');
      {
        final exportAs = component.exportAs;
        expect(exportAs.name, 'export-name');
        expect(exportAs.nameOffset, code.indexOf('export-name'));
      }
    }
    {
      final component = getSyntacticComponentByName(directives, 'ComponentB');
      {
        final exportAs = component.exportAs;
        expect(exportAs, isNull);
      }
    }
    // no errors
    errorListener.assertNoErrors();
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
      final directive = getSyntacticDirectiveByName(directives, 'DirectiveA');
      {
        final exportAs = directive.exportAs;
        expect(exportAs.name, 'export-name');
        expect(exportAs.nameOffset, code.indexOf('export-name'));
      }
    }
    {
      final directive = getSyntacticDirectiveByName(directives, 'DirectiveB');
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
    final component = directives.first as Component;
    expect(component.exports, const isInstanceOf<ListLiteral>());
    final exports = (component.exports as ListLiteral).items;
    expect(exports, hasLength(3));
    {
      final export = exports[0];
      expect(export.name, equals('foo'));
      expect(export.prefix, equals(''));
      expect(export.range.offset, equals(code.indexOf('foo,')));
      expect(export.range.length, equals('foo'.length));
    }
    {
      final export = exports[1];
      expect(export.name, equals('bar'));
      expect(export.prefix, equals(''));
      expect(export.range.offset, equals(code.indexOf('bar,')));
      expect(export.range.length, equals('bar'.length));
    }
    {
      final export = exports[2];
      expect(export.name, equals('MyClass'));
      expect(export.prefix, equals(''));
      expect(export.range.offset, equals(code.indexOf('MyClass]')));
      expect(export.range.length, equals('MyClass'.length));
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
  Future test_inputs() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(
    selector: 'my-component',
    template: '<p></p>')
class MyComponent {
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
    expect(inputs, hasLength(3));
    {
      final input = inputs[0];
      expect(input.name, 'firstField');
      expect(input.nameOffset, code.indexOf('firstField'));
      expect(input.nameLength, 'firstField'.length);
      expect(input.setterRange.offset, input.nameOffset);
      expect(input.setterRange.length, input.name.length);
    }
    {
      final input = inputs[1];
      expect(input.name, 'secondInput');
      expect(input.nameOffset, code.indexOf('secondInput'));
      expect(input.setterRange.offset, code.indexOf('secondField'));
      expect(input.setterRange.length, 'secondField'.length);
    }
    {
      final input = inputs[2];
      expect(input.name, 'someSetter');
      expect(input.nameOffset, code.indexOf('someSetter'));
      expect(input.setterRange.offset, input.nameOffset);
      expect(input.setterRange.length, input.name.length);
    }

    // assert no syntax errors, etc
    errorListener.assertNoErrors();
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
  Future test_outputs() async {
    final code = r'''
import 'package:angular2/angular2.dart';

@Component(
    selector: 'my-component',
    template: '<p></p>')
class MyComponent {
  @Output()
  EventEmitter<int> outputOne;
  @Output('outputTwo')
  EventEmitter secondOutput;
  @Output()
  EventEmitter get someGetter => null;
}
''';
    final source = newSource('/test.dart', code);
    await getDirectives(source);
    final component = directives.single;
    final compOutputs = component.outputs;
    expect(compOutputs, hasLength(3));
    {
      final output = compOutputs[0];
      expect(output.name, 'outputOne');
      expect(output.nameOffset, code.indexOf('outputOne'));
      expect(output.nameLength, 'outputOne'.length);
      expect(output.getterRange.offset, output.nameOffset);
      expect(output.getterRange.length, output.nameLength);
    }
    {
      final output = compOutputs[1];
      expect(output.name, 'outputTwo');
      expect(output.nameOffset, code.indexOf('outputTwo'));
      expect(output.getterRange.offset, code.indexOf('secondOutput'));
      expect(output.getterRange.length, 'secondOutput'.length);
    }
    {
      final output = compOutputs[2];
      expect(output.name, 'someGetter');
      expect(output.nameOffset, code.indexOf('someGetter'));
      expect(output.getterRange.offset, output.nameOffset);
      expect(output.getterRange.length, output.name.length);
    }

    // assert no syntax errors, etc
    errorListener.assertNoErrors();
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
      expect(pipe.pipeName, 'pipeA');
    }
    {
      final pipe = pipes[1];
      expect(pipe, const isInstanceOf<Pipe>());
      expect(pipe.pipeName, 'pipeB');
    }
    errorListener.assertNoErrors();
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
    expect(pipeName, const isInstanceOf<String>());
    expect(pipeName, 'pipeA');

    errorListener
        .assertErrorsWithCodes([AngularWarningCode.PIPE_CANNOT_BE_ABSTRACT]);
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
    final component = directives.first as Component;
    expect(component.exports, const isInstanceOf<ListLiteral>());
    final exports = (component.exports as ListLiteral).items;
    expect(exports, hasLength(2));
    {
      final export = exports[0];
      expect(export.name, equals('foo'));
      expect(export.prefix, equals('prefixed'));
      expect(export.range.offset, equals(code.indexOf('prefixed.foo')));
      expect(export.range.length, equals('prefixed.foo'.length));
    }
    {
      final export = exports[1];
      expect(export.name, equals('foo'));
      expect(export.prefix, equals(''));
      expect(export.range.offset, equals(code.indexOf('foo]')));
      expect(export.range.length, equals('foo'.length));
    }

    // validate
    errorListener.assertNoErrors();
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
}
