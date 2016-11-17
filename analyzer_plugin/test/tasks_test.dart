library angular2.src.analysis.analyzer_plugin.src.tasks_test;

import 'package:analyzer/src/context/cache.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/engine.dart' show ChangeSet;
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/model.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/tasks.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';

import 'abstract_angular.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(BuildStandardHtmlComponentsTaskTest);
  defineReflectiveTests(BuildUnitDirectivesTaskTest);
  defineReflectiveTests(BuildUnitViewsTaskTest);
  defineReflectiveTests(ComputeDirectivesInLibraryTaskTest);
  defineReflectiveTests(ResolveDartTemplatesTaskTest);
  defineReflectiveTests(ResolveHtmlTemplatesTaskTest);
  defineReflectiveTests(ResolveHtmlTemplateTaskTest);
}

@reflectiveTest
class BuildStandardHtmlComponentsTaskTest extends AbstractAngularTest {
  void test_perform() {
    computeResult(AnalysisContextTarget.request, STANDARD_HTML_COMPONENTS);
    expect(task, new isInstanceOf<BuildStandardHtmlComponentsTask>());
    // validate
    List<Component> components = outputs[STANDARD_HTML_COMPONENTS];
    Map<String, Component> map = {};
    components.forEach((c) {
      map[c.selector.toString()] = c;
    });
    expect(map, isNotNull);
    // a
    {
      Component component = map['a'];
      expect(component, isNotNull);
      expect(component.classElement.displayName, 'AnchorElement');
      expect(component.selector.toString(), 'a');
      List<InputElement> inputs = component.inputs;
      {
        InputElement input = inputs.singleWhere((i) => i.name == 'href');
        expect(input, isNotNull);
        expect(input.setter, isNotNull);
      }
      {
        InputElement input = inputs.singleWhere((i) => i.name == 'tabIndex');
        expect(input, isNotNull);
        expect(input.setter, isNotNull);
      }
    }
    // button
    {
      Component component = map['button'];
      expect(component, isNotNull);
      expect(component.classElement.displayName, 'ButtonElement');
      expect(component.selector.toString(), 'button');
      List<InputElement> inputs = component.inputs;
      {
        InputElement input = inputs.singleWhere((i) => i.name == 'autofocus');
        expect(input, isNotNull);
        expect(input.setter, isNotNull);
      }
      {
        InputElement input = inputs.singleWhere((i) => i.name == 'tabIndex');
        expect(input, isNotNull);
        expect(input.setter, isNotNull);
      }
    }
    // h1, h2, h3
    expect(map['h1'], isNotNull);
    expect(map['h2'], isNotNull);
    expect(map['h3'], isNotNull);
  }
}

@reflectiveTest
class BuildUnitDirectivesTaskTest extends AbstractAngularTest {
  void test_Component() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'comp-a')
class ComponentA {
}

@Component(selector: 'comp-b')
class ComponentB {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES_IN_UNIT];
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
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Directive(selector: 'dir-a')
class DirectiveA {
}

@Directive(selector: 'dir-b')
class DirectiveB {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES_IN_UNIT];
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

  void test_exportAs_Component() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'aaa', exportAs: 'export-name')
class ComponentA {
}

@Component(selector: 'bbb')
class ComponentB {
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES_IN_UNIT];
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
    fillErrorListener(DIRECTIVES_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_exportAs_Directive() {
    String code = r'''
import '/angular2/angular2.dart';

@Directive(selector: '[aaa]', exportAs: 'export-name')
class DirectiveA {
}

@Directive(selector: '[bbb]')
class DirectiveB {
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES_IN_UNIT];
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
    fillErrorListener(DIRECTIVES_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_exportAs_hasError_notStringValue() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'aaa', exportAs: 42)
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // has a directive
    List<AbstractDirective> directives = outputs[DIRECTIVES_IN_UNIT];
    expect(directives, hasLength(1));
    // has an error
    fillErrorListener(DIRECTIVES_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.STRING_VALUE_EXPECTED]);
  }

  void test_hasError_ArgumentSelectorMissing() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component()
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    fillErrorListener(DIRECTIVES_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.ARGUMENT_SELECTOR_MISSING]);
  }

  void test_hasError_CannotParseSelector() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: '+bad')
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    fillErrorListener(DIRECTIVES_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.CANNOT_PARSE_SELECTOR]);
  }

  void test_hasError_selector_notStringValue() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'comp' + '-a')
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    fillErrorListener(DIRECTIVES_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.STRING_VALUE_EXPECTED]);
  }

  void test_hasError_UndefinedSetter_fullSyntax() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'my-component', inputs: const ['noSetter: no-setter'])
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    fillErrorListener(DIRECTIVES_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[StaticTypeWarningCode.UNDEFINED_SETTER]);
  }

  void test_hasError_UndefinedSetter_shortSyntax() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'my-component', inputs: const ['noSetter'])
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    fillErrorListener(DIRECTIVES_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[StaticTypeWarningCode.UNDEFINED_SETTER]);
  }

  void test_inputs() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(
    selector: 'my-component',
    inputs: const ['leadingText', 'trailingText: tailText'])
class MyComponent {
  String leadingText;
  String trailingText;
  @Input()
  String firstField;
  @Input('secondInput')
  String secondField;
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES_IN_UNIT];
    Component component = directives.single;
    List<InputElement> inputs = component.inputs;
    expect(inputs, hasLength(4));
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
    {
      InputElement input = inputs[2];
      expect(input.name, 'firstField');
      expect(input.nameOffset, code.indexOf('firstField'));
      expect(input.nameLength, 'firstField'.length);
      expect(input.setterRange, isNull);
      expect(input.setter, isNotNull);
      expect(input.setter.isSetter, isTrue);
      expect(input.setter.displayName, 'firstField');
    }
    {
      InputElement input = inputs[3];
      expect(input.name, 'secondInput');
      expect(input.nameOffset, code.indexOf('secondInput'));
      expect(input.setterRange, isNull);
      expect(input.setter, isNotNull);
      expect(input.setter.isSetter, isTrue);
      expect(input.setter.displayName, 'secondField');
    }
  }

  void test_inputs_deprecatedProperties() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(
    selector: 'my-component',
    properties: const ['leadingText', 'trailingText: tailText'])
class MyComponent {
  String leadingText;
  String trailingText;
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES_IN_UNIT];
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

  void test_outputs() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(
    selector: 'my-component',
    outputs: const ['outputOne', 'secondOutput: outputTwo'])
class MyComponent {
  EventEmitter outputOne;
  EventEmitter<String> secondOutput;
  @Output()
  EventEmitter<int> outputThree;
  @Output('outputFour')
  EventEmitter<MyComponent> fourthOutput;
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES_IN_UNIT];
    Component component = directives.single;
    List<OutputElement> compOutputs = component.outputs;
    expect(compOutputs, hasLength(4));
    {
      OutputElement output = compOutputs[0];
      expect(output.name, 'outputOne');
      expect(output.nameOffset, code.indexOf("outputOne"));
      expect(output.getterRange.offset, output.nameOffset);
      expect(output.getterRange.length, 'outputOne'.length);
      expect(output.getter, isNotNull);
      expect(output.getter.isGetter, isTrue);
      expect(output.getter.displayName, 'outputOne');
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
    }
    {
      OutputElement output = compOutputs[2];
      expect(output.name, 'outputThree');
      expect(output.nameOffset, code.indexOf('outputThree'));
      expect(output.nameLength, 'outputThree'.length);
      expect(output.getterRange, isNull);
      expect(output.getter, isNotNull);
      expect(output.getter.isGetter, isTrue);
      expect(output.getter.displayName, 'outputThree');
    }
    {
      OutputElement output = compOutputs[3];
      expect(output.name, 'outputFour');
      expect(output.nameOffset, code.indexOf('outputFour'));
      expect(output.getterRange, isNull);
      expect(output.getter, isNotNull);
      expect(output.getter.isGetter, isTrue);
      expect(output.getter.displayName, 'fourthOutput');
    }
  }

  void test_noDirectives() {
    Source source = newSource(
        '/test.dart',
        r'''
class A {}
class B {}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DIRECTIVES_IN_UNIT);
    expect(task, new isInstanceOf<BuildUnitDirectivesTask>());
    // validate
    List<AbstractDirective> directives = outputs[DIRECTIVES_IN_UNIT];
    expect(directives, isEmpty);
  }
}

@reflectiveTest
class BuildUnitViewsTaskTest extends AbstractAngularTest {
  void test_directives() {
    String code = r'''
import '/angular2/angular2.dart';

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
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate views
    List<View> views = outputs[VIEWS];
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
    fillErrorListener(VIEWS_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_directives_hasError_notListVariable() {
    String code = r'''
import '/angular2/angular2.dart';

const NOT_DIRECTIVE_LIST = 42;

@Component(selector: 'my-component', template: 'My template',
   directives: const [NOT_DIRECTIVE_LIST])
class MyComponent {}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // no errors
    fillErrorListener(VIEWS_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TYPE_LITERAL_EXPECTED]);
  }

  void test_hasError_ComponentAnnotationMissing() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@View(template: 'AAA')
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    fillErrorListener(VIEWS_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.COMPONENT_ANNOTATION_MISSING]);
  }

  void test_hasError_DirectiveTypeLiteralExpected() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'aaa', template: 'AAA', directives: const [int])
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    fillErrorListener(VIEWS_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.DIRECTIVE_TYPE_LITERAL_EXPECTED]);
  }

  void test_hasError_StringValueExpected() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'aaa', template: 'bad' + 'template')
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    fillErrorListener(VIEWS_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.STRING_VALUE_EXPECTED]);
  }

  void test_hasError_TypeLiteralExpected() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'aaa', template: 'AAA', directives: const [42])
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    fillErrorListener(VIEWS_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TYPE_LITERAL_EXPECTED]);
  }

  void test_hasError_TemplateAndTemplateUrlDefined() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'aaa', template: 'AAA', templateUrl: 'a.html')
class ComponentA {
}
''');
    newSource('/a.html', '');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    fillErrorListener(VIEWS_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.TEMPLATE_URL_AND_TEMPLATE_DEFINED]);
  }

  void test_hasError_NeitherTemplateNorTemplateUrlDefined() {
    Source source = newSource(
        '/test.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'aaa')
class ComponentA {
}
''');
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    fillErrorListener(VIEWS_ERRORS);
    errorListener.assertErrorsWithCodes(
        <ErrorCode>[AngularWarningCode.NO_TEMPLATE_URL_OR_TEMPLATE_DEFINED]);
  }

  void test_hasError_missingHtmlFile() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'my-component', templateUrl: 'missing-template.html')
class MyComponent {}
''';
    Source dartSource = newSource('/test.dart', code);
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    fillErrorListener(VIEWS_ERRORS);
    assertErrorInCodeAtPosition(
        AngularWarningCode.REFERENCED_HTML_FILE_DOESNT_EXIST,
        code,
        "'missing-template.html'");
  }

  void test_templateExternal() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'my-component', templateUrl: 'my-template.html')
class MyComponent {}
''';
    Source dartSource = newSource('/test.dart', code);
    Source htmlSource = newSource('/my-template.html', '');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    List<AbstractDirective> directives =
        context.analysisCache.getValue(target, DIRECTIVES_IN_UNIT);
    // validate views
    List<View> views = outputs[VIEWS];
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
    // has a single view
    List<View> templateViews = outputs[VIEWS_WITH_HTML_TEMPLATES];
    expect(templateViews, unorderedEquals([view]));
  }

  void test_templateExternalUsingViewAnnotation() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'my-component')
@View(templateUrl: 'my-template.html')
class MyComponent {}
''';
    Source dartSource = newSource('/test.dart', code);
    Source htmlSource = newSource('/my-template.html', '');
    LibrarySpecificUnit target =
        new LibrarySpecificUnit(dartSource, dartSource);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    List<AbstractDirective> directives =
        context.analysisCache.getValue(target, DIRECTIVES_IN_UNIT);
    // validate views
    List<View> views = outputs[VIEWS];
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
    // has a single view
    List<View> templateViews = outputs[VIEWS_WITH_HTML_TEMPLATES];
    expect(templateViews, unorderedEquals([view]));
  }

  void test_templateInline() {
    String code = r'''
import '/angular2/angular2.dart';

@Directive(selector: 'my-directive')
class MyDirective {}

@Component(selector: 'other-component', template: 'Other template')
class OtherComponent {}

@Component(selector: 'my-component', template: 'My template',
    directives: const [MyDirective, OtherComponent])
class MyComponent {}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    List<AbstractDirective> directives =
        context.analysisCache.getValue(target, DIRECTIVES_IN_UNIT);
    // validate views
    List<View> views = outputs[VIEWS];
    expect(views, hasLength(2));
    {
      View view = getViewByClassName(views, 'MyComponent');
      expect(
          view.component, getComponentByClassName(directives, 'MyComponent'));
      expect(view.templateText, 'My template');
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
    // no view with external templates
    List<View> templateViews = outputs[VIEWS_WITH_HTML_TEMPLATES];
    expect(templateViews, hasLength(0));
  }

  void test_templateInlineUsingViewAnnotation() {
    String code = r'''
import '/angular2/angular2.dart';

@Directive(selector: 'my-directive')
class MyDirective {}

@Component(selector: 'other-component')
@View(template: 'Other template')
class OtherComponent {}

@Component(selector: 'my-component')
@View(template: 'My template', directives: const [MyDirective, OtherComponent])
class MyComponent {}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, VIEWS);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    List<AbstractDirective> directives =
        context.analysisCache.getValue(target, DIRECTIVES_IN_UNIT);
    // validate views
    List<View> views = outputs[VIEWS];
    expect(views, hasLength(2));
    {
      View view = getViewByClassName(views, 'MyComponent');
      expect(
          view.component, getComponentByClassName(directives, 'MyComponent'));
      expect(view.templateText, 'My template');
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
    // no view with external templates
    List<View> templateViews = outputs[VIEWS_WITH_HTML_TEMPLATES];
    expect(templateViews, hasLength(0));
  }
}

@reflectiveTest
class ComputeDirectivesInLibraryTaskTest extends AbstractAngularTest {
  void test_cycle_withExports() {
    Source sourceA = newSource(
        '/a.dart',
        r'''
import '/angular2/angular2.dart';
import 'b.dart';
export 'a2.dart';

@Component(selector: 'aaa')
class ComponentA {
}
''');
    newSource(
        '/a2.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'aaa2')
class ComponentA2 {
}
''');
    Source sourceB = newSource(
        '/b.dart',
        r'''
import '/angular2/angular2.dart';
import 'a.dart';
export 'b2.dart';

@Component(selector: 'bbb')
class ComponentB {
}
''');
    newSource(
        '/b2.dart',
        r'''
import '/angular2/angular2.dart';

@Component(selector: 'bbb2')
class ComponentB2 {
}
''');
    computeResult(sourceA, DIRECTIVES_IN_LIBRARY);
    computeResult(sourceB, DIRECTIVES_IN_LIBRARY);
    {
      List<AbstractDirective> directives =
          context.analysisCache.getValue(sourceA, DIRECTIVES_IN_LIBRARY);
      List<String> classNames =
          directives.map((d) => d.classElement.name).toList();
      expect(classNames, contains('ComponentA'));
      expect(classNames, contains('ComponentA2'));
      expect(classNames, contains('ComponentB'));
      expect(classNames, contains('ComponentB2'));
    }
    {
      List<AbstractDirective> directives =
          context.analysisCache.getValue(sourceB, DIRECTIVES_IN_LIBRARY);
      List<String> classNames =
          directives.map((d) => d.classElement.name).toList();
      expect(classNames, contains('ComponentA'));
      expect(classNames, contains('ComponentA2'));
      expect(classNames, contains('ComponentB'));
      expect(classNames, contains('ComponentB2'));
    }
  }
}

@reflectiveTest
class ResolveDartTemplatesTaskTest extends AbstractAngularTest {
  void test_componentReference() {
    var code = r'''
import '/angular2/angular2.dart';

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
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // prepare directives
    List<AbstractDirective> directives =
        context.analysisCache.getValue(target, DIRECTIVES_IN_UNIT);
    Component componentA = getComponentByClassName(directives, 'ComponentA');
    Component componentB = getComponentByClassName(directives, 'ComponentB');
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
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_hasError_expression_ArgumentTypeNotAssignable() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panel',
    template: r"<div> {{text.length + text}} </div>")
class TextPanel {
  String text;
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // has errors
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertErrorsWithCodes(
        [StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE]);
  }

  void test_hasError_expression_UndefinedIdentifier() {
    String code = r'''
import '/angular2/angular2.dart';

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
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // has errors
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener
        .assertErrorsWithCodes([StaticWarningCode.UNDEFINED_IDENTIFIER]);
  }

  void test_hasError_expression_UndefinedIdentifier_OutsideFirstHtmlTag() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'my-component', template: '<h1></h1>{{noSuchName}}')
class MyComponent {
}
''';

    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // has errors
    fillErrorListener(DART_TEMPLATES_ERRORS);
    assertErrorInCodeAtPosition(
        StaticWarningCode.UNDEFINED_IDENTIFIER, code, 'noSuchName');
  }

  void test_hasError_UnresolvedTag() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'my-aaa',
    template: "<unresolved-tag attr='value'></unresolved-tag>")
class ComponentA {
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    fillErrorListener(DART_TEMPLATES_ERRORS);
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNRESOLVED_TAG, code, 'unresolved-tag');
  }

  void test_htmlParsing_hasError() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panel',
    template: r"<div> <h2> Expected closing H2 </h3> </div>")
class TextPanel {
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // has errors
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertErrorsWithCodes([HtmlErrorCode.PARSE_ERROR]);
  }

  void test_input_OK_event() {
    String code = r'''
import 'dart:html';
import '/angular2/angular2.dart';

@Component(selector: 'UserPanel', template: r"""
<div>
  <input (keyup)='doneTyping($event)'>
</div>
""")
class TodoList {
  doneTyping(KeyboardEvent event) {}
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(1));
    {
      Template template = _getDartTemplateByClassName(templates, 'TodoList');
      List<ResolvedRange> ranges = template.ranges;
      expect(ranges, hasLength(4));
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, r'doneTyping($');
        expect(resolvedRange.range.length, 'doneTyping'.length);
        Element element = (resolvedRange.element as DartElement).element;
        expect(element, new isInstanceOf<MethodElement>());
        expect(element.name, 'doneTyping');
        expect(element.nameOffset,
            code.indexOf('doneTyping(KeyboardEvent event)'));
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, r"$event)'>");
        expect(resolvedRange.range.length, r'$event'.length);
        Element element = (resolvedRange.element as DartElement).element;
        expect(element, new isInstanceOf<LocalVariableElement>());
        expect(element.name, r'$event');
        expect(element.nameOffset, -1);
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'keyup');
        expect(resolvedRange.range.length, 'keyup'.length);
      }
    }
    // no errors
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_input_OK_reference_expression() {
    String code = r'''
import '/angular2/angular2.dart';

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
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // prepare directives
    List<AbstractDirective> directives =
        context.analysisCache.getValue(target, DIRECTIVES_IN_UNIT);
    Component textPanel = getComponentByClassName(directives, 'TextPanel');
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
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
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_input_OK_reference_text() {
    String code = r'''
import '/angular2/angular2.dart';

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
  <comp-a firstValue='1' second='2'></comp-a>
</div>
""", directives: const [ComponentA])
class ComponentB {
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // prepare directives
    List<AbstractDirective> directives =
        context.analysisCache.getValue(target, DIRECTIVES_IN_UNIT);
    Component componentA = getComponentByClassName(directives, 'ComponentA');
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(2));
    {
      Template template = _getDartTemplateByClassName(templates, 'ComponentB');
      List<ResolvedRange> ranges = template.ranges;
      expect(ranges, hasLength(4));
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'firstValue=');
        expect(resolvedRange.range.length, 'firstValue'.length);
        assertPropertyReference(resolvedRange, componentA, 'firstValue');
      }
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(code, ranges, 'second=');
        expect(resolvedRange.range.length, 'second'.length);
        assertPropertyReference(resolvedRange, componentA, 'second');
      }
    }
    // no errors
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_noRootElement() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panel',
    template: r'Often used without an element in tests.')
class TextPanel {
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(1));
    // has errors
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertNoErrors();
  }

  void test_textExpression_hasError_UnterminatedMustache() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"<div> {{text </div>")
class TextPanel {
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(1));
    // has errors
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener
        .assertErrorsWithCodes([AngularWarningCode.UNTERMINATED_MUSTACHE]);
  }

  void test_textExpression_hasError_UnopenedMustache() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"<div> text}} </div>")
class TextPanel {
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(1));
    // has errors
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertErrorsWithCodes([AngularWarningCode.UNOPENED_MUSTACHE]);
  }

  void test_textExpression_hasError_DoubleOpenedMustache() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"<div> {{text {{ text}} </div>")
class TextPanel {
  String text;
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(1));
    // has errors
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener
        .assertErrorsWithCodes([AngularWarningCode.UNTERMINATED_MUSTACHE]);
  }

  void test_textExpression_hasError_MultipleUnclosedMustaches() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panel', template: r"<div> {{open {{open {{text}} close}} close}} </div>")
class TextPanel {
  String text;
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
    expect(templates, hasLength(1));
    // has errors
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertErrorsWithCodes([
      AngularWarningCode.UNTERMINATED_MUSTACHE,
      AngularWarningCode.UNTERMINATED_MUSTACHE,
      AngularWarningCode.UNOPENED_MUSTACHE,
      AngularWarningCode.UNOPENED_MUSTACHE
    ]);
  }

  void test_textExpression_OK() {
    String code = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panel', inputs: const ['text'],
    template: r"<div> <h2> {{text}}  </h2> and {{text.length}} </div>")
class TextPanel {
  String text; // 1
}
''';
    Source source = newSource('/test.dart', code);
    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
    computeResult(target, DART_TEMPLATES);
    expect(task, new isInstanceOf<ResolveDartTemplatesTask>());
    // validate
    List<Template> templates = outputs[DART_TEMPLATES];
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
    fillErrorListener(DART_TEMPLATES_ERRORS);
    errorListener.assertNoErrors();
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
class ResolveHtmlTemplatesTaskTest extends AbstractAngularTest {
  void test_multipleViewsWithTemplate() {
    String dartCode = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panelA', templateUrl: 'text_panel.html')
class TextPanelA {
  String text; // A
}

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
    Source dartSource = newSource('/test.dart', dartCode);
    Source htmlSource = newSource('/text_panel.html', htmlCode);
    // compute views, so that we have the TEMPLATE_VIEWS result
    {
      LibrarySpecificUnit target =
          new LibrarySpecificUnit(dartSource, dartSource);
      computeResult(target, VIEWS_WITH_HTML_TEMPLATES);
    }
    // compute Angular templates
    computeResult(htmlSource, HTML_TEMPLATES);
    expect(task, new isInstanceOf<ResolveHtmlTemplatesTask>());
    // validate
    List<HtmlTemplate> templates = outputs[HTML_TEMPLATES];
    expect(templates, hasLength(2));
    // validate templates
    bool hasTextPanelA = false;
    bool hasTextPanelB = false;
    for (HtmlTemplate template in templates) {
      String viewClassName = template.view.classElement.name;
      String textTargetPattern;
      if (viewClassName == 'TextPanelA') {
        hasTextPanelA = true;
        textTargetPattern = 'text; // A';
      }
      if (viewClassName == 'TextPanelB') {
        hasTextPanelB = true;
        textTargetPattern = 'text; // B';
      }
      expect(template.ranges, hasLength(1));
      {
        ResolvedRange resolvedRange =
            getResolvedRangeAtString(htmlCode, template.ranges, 'text}}');
        PropertyAccessorElement element = assertGetter(resolvedRange);
        expect(element.name, 'text');
        expect(element.nameOffset, dartCode.indexOf(textTargetPattern));
      }
    }
    expect(hasTextPanelA, isTrue);
    expect(hasTextPanelB, isTrue);
  }

  void test_priorityHtmlTemplate() {
    String dartCode = r'''
import '/angular2/angular2.dart';

@Component(selector: 'text-panel', templateUrl: 'text_panel.html')
class TextPanel {}
''';
    String htmlCode = '<div></div>';
    Source dartSource = newSource('/text_panel.dart', dartCode);
    Source htmlSource = newSource('/text_panel.html', htmlCode);
    context.applyChanges(
        new ChangeSet()..addedSource(dartSource)..addedSource(htmlSource));
    context.analysisPriorityOrder = <Source>[htmlSource];
    // analyze all
    _analyzeAll_assertFinished();
    // success
    CacheEntry htmlEntry = context.getCacheEntry(htmlSource);
    expect(htmlEntry.exception, isNull);
    // has HTML_TEMPLATES with 1 item
    List<HtmlTemplate> templates = htmlEntry.getValue(HTML_TEMPLATES);
    expect(templates, hasLength(1));
  }

  /**
   * Perform analysis tasks up to [maxIterations] times and assert that it
   * was enough.
   */
  void _analyzeAll_assertFinished([int maxIterations = 1024]) {
    for (int i = 0; i < maxIterations; i++) {
      var notice = context.performAnalysisTask().changeNotices;
      if (notice == null) {
        return;
      }
    }
    fail("performAnalysisTask failed to terminate after analyzing all sources");
  }
}

@reflectiveTest
class ResolveHtmlTemplateTaskTest extends AbstractAngularTest {
  void test_hasViewWithTemplate() {
    String dartCode = r'''
import '/angular2/angular2.dart';

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
    Source dartSource = newSource('/test.dart', dartCode);
    newSource('/text_panel.html', htmlCode);
    // compute
    computeLibraryViews(dartSource);
    expect(task, new isInstanceOf<BuildUnitViewsTask>());
    // validate
    List<View> views = outputs[VIEWS_WITH_HTML_TEMPLATES];
    expect(views, hasLength(1));
    {
      View view = getViewByClassName(views, 'TextPanel');
      expect(view.templateUriSource, isNotNull);
      // resolve this View
      computeResult(view, HTML_TEMPLATE);
      expect(task, new isInstanceOf<ResolveHtmlTemplateTask>());
      expect(
          outputs.keys, unorderedEquals([HTML_TEMPLATE, HTML_TEMPLATE_ERRORS]));
      Template template = outputs[HTML_TEMPLATE];
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
}
