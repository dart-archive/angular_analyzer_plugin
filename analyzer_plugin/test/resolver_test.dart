library angular2.src.analysis.analyzer_plugin.src.resolver_test;

import 'dart:async';

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/dart/error/syntactic_errors.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';

import 'abstract_angular.dart';
import 'element_assert.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(TemplateResolverTest);
}

void assertPropertyElement(AngularElement element,
    {nameMatcher, sourceMatcher}) {
  expect(element, new isInstanceOf<InputElement>());
  InputElement inputElement = element;
  if (nameMatcher != null) {
    expect(inputElement.name, nameMatcher);
  }
  if (sourceMatcher != null) {
    expect(inputElement.source.fullName, sourceMatcher);
  }
}

@reflectiveTest
class TemplateResolverTest extends AbstractAngularTest {
  String dartCode;
  String htmlCode;
  Source dartSource;
  Source htmlSource;

  List<AbstractDirective> directives;

  Template template;
  List<ResolvedRange> ranges;

  Future test_attribute_mixedCase() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    _addHtmlSource(r"""
<svg viewBox='0, 0, 24 24'></svg>
""");
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(0));
  }

  Future test_attributeInterpolation() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  String aaa; // 1
  String bbb; // 2
}
''');
    _addHtmlSource(r"""
<span title='Hello {{aaa}} and {{bbb}}!'></span>
""");
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(2));
    _assertElement('aaa}}').dart.getter.at('aaa; // 1');
    _assertElement('bbb}}').dart.getter.at('bbb; // 2');
  }

  Future test_expression_eventBinding() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    _addHtmlSource(r"""
<div (click)='handleClick($event)'></div>
""");
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(3));
    _assertElement('click)').output.inCoreHtml;
    _assertElement('handleClick').dart.method.at('handleClick(MouseEvent');

    errorListener.assertNoErrors();
    ElementSearch search = new ElementSearch((e) => e.localName == "div");
    template.ast.accept(search);

    expect(search.element, isNotNull);
    expect(search.element.boundStandardOutputs, hasLength(1));
    expect(search.element.boundStandardOutputs.first.boundOutput.name, 'click');
  }

  Future test_expression_nativeEventBindingOnComponent() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [SomeComponent])
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}

@Component(selector: 'some-comp', template: '')
class SomeComponent {
}
''');
    _addHtmlSource(r"""
<some-comp (click)='handleClick($event)'></some-comp>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement('click').output.inCoreHtml;
  }

  Future test_expression_eventBinding_on() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    _addHtmlSource(r"""
<div on-click='handleClick()'></div>
""");
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(2));
    _assertElement('click=').output.inCoreHtml;
    _assertElement('handleClick()').dart.method.at('handleClick(MouseEvent');
  }

  Future test_expression_inputBinding_valid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Directive(selector: '[titled]', template: '', inputs: 'title')
class TitleComponent {
  @Input() String title;
}
''');
    _addHtmlSource(r"""
<span titled [title]='text'></span>
""");
    await _resolveSingleTemplate(dartSource);

    errorListener.assertNoErrors();
    ElementSearch search = new ElementSearch((e) => e.localName == "span");
    template.ast.accept(search);

    expect(search.element, isNotNull);
    expect(search.element.boundDirectives, hasLength(1));
    DirectiveBinding boundDirective = search.element.boundDirectives.first;
    expect(boundDirective.inputBindings, hasLength(1));
    expect(boundDirective.inputBindings.first.boundInput.name, 'title');
  }

  Future test_expression_nativeGlobalAttrBindingOnComponent() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [SomeComponent])
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}

@Component(selector: 'some-comp', template: '')
class SomeComponent {
}
''');
    _addHtmlSource(r"""
<some-comp [hidden]='false'></some-comp>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement('hidden').input.inCoreHtml;
  }

  Future test_expression_inputBinding_asString() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
}
@Component(selector: 'title-comp', template: '')
class TitleComponent {
  @Input() String title;
}
''');
    var code = r"""
<title-comp title='anything can go here' id="some id"></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement('title=').input.inFileName('/test_panel.dart').at('title;');
    _assertElement('id=').input.inCoreHtml;
  }

  Future test_expression_inputBinding_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() int title;
}
''');
    var code = r"""
<title-comp [title]='text'></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_BINDING_TYPE_ERROR, code, "text");
  }

  Future test_expression_inputBinding_asString_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
}
@Component(selector: 'title-comp', template: '')
class TitleComponent {
  @Input() int titleInput;
}
''');
    var code = r"""
<title-comp titleInput='string binding'></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.STRING_STYLE_INPUT_BINDING_INVALID,
        code,
        "titleInput");
  }

  Future test_expression_inputBinding_global_asString_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [], templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    var code = r"""
<div hidden="string binding"></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.STRING_STYLE_INPUT_BINDING_INVALID, code, "hidden");
  }

  Future test_expression_inputBinding_noValue() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() int title;
}
''');
    var code = r"""
<title-comp [title]></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.EMPTY_BINDING, code, "[title]");
  }

  Future test_expression_inputBinding_empty() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() int title;
}
''');
    var code = r"""
<title-comp [title]=""></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.EMPTY_BINDING, code, "[title]");
  }

  Future test_expression_inputBinding_boundToNothing() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    var code = r"""
<span [title]='text'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.NONEXIST_INPUT_BOUND, code, "title");
  }

  Future test_expression_twoWayBinding_valid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Directive(selector: '[titled]', template: '', inputs: 'title')
class TitleComponent {
  @Input() String title;
  @Output() EventEmitter<String> titleChange;
}
''');
    _addHtmlSource(r"""
<span titled [(title)]='text'></span>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    ElementSearch search = new ElementSearch((e) => e.localName == "span");
    template.ast.accept(search);

    expect(search.element, isNotNull);
    expect(search.element.boundDirectives, hasLength(1));
    DirectiveBinding boundDirective = search.element.boundDirectives.first;
    expect(boundDirective.inputBindings, hasLength(1));
    expect(boundDirective.inputBindings.first.boundInput.name, 'title');
    expect(boundDirective.outputBindings, hasLength(1));
    expect(boundDirective.outputBindings.first.boundOutput.name, 'titleChange');
  }

  Future test_expression_twoWayBinding_noAttr_emptyBinding() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Directive(selector: '[titled]', template: '', inputs: 'title')
class TitleComponent {
  @Input() String twoWay;
  @Output() EventEmitter<String> twoWayChange;
}
''');
    String code = r"""
<span titled [(twoWay)]></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.EMPTY_BINDING, code, "[(twoWay)]");
  }

  Future test_expression_twoWayBinding_inputTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() int title;
  @Output() EventEmitter<String> titleChange;
}
''');
    var code = r"""
<title-comp [(title)]='text'></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_BINDING_TYPE_ERROR, code, "text");
  }

  Future test_expression_twoWayBinding_outputTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() String title;
  @Output() EventEmitter<int> titleChange;
}
''');
    var code = r"""
<title-comp [(title)]='text'></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TWO_WAY_BINDING_OUTPUT_TYPE_ERROR, code, "text");
  }

  Future test_expression_outputBinding_noValue() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Output() EventEmitter<int> title;
}
''');
    var code = r"""
<title-comp (title)></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.EMPTY_BINDING, code, "(title)");
  }

  Future test_expression_twoWayBinding_notAssignableError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() String title;
  @Output() EventEmitter<String> titleChange;
}
''');
    var code = r"""
<title-comp [(title)]="text.toUpperCase()"></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TWO_WAY_BINDING_NOT_ASSIGNABLE,
        code,
        "text.toUpperCase()");
  }

  Future test_expression_twoWayBinding_noInputToBind() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Output() EventEmitter<String> noInputChange;
}
''');
    var code = r"""
<title-comp [(noInput)]="text"></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.NONEXIST_INPUT_BOUND, code, "noInput");
  }

  Future test_expression_twoWayBinding_noOutputToBind() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() String inputOnly;
}
''');
    var code = r"""
<title-comp [(inputOnly)]="text"></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.NONEXIST_TWO_WAY_OUTPUT_BOUND, code, "inputOnly");
  }

  Future test_expression_inputBinding_bind() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<span bind-title='text'></span>
""");
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    _assertElement("text'>").dart.getter.at('text; // 1');
  }

  Future test_expression_outputBinding_boundToNothing() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    var code = r"""
<span (title)='text'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.NONEXIST_OUTPUT_BOUND, code, "title");
  }

  Future test_expression_outputBinding_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [TitleComponent], templateUrl: 'test_panel.html')
class TestPanel {
  takeString(String arg);
}
@Component(selector: 'title-comp', template: '')
class TitleComponent {
  @Output() EventEmitter<int> output;
}
''');
    var code = r"""
<title-comp (output)='takeString($event)'></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE, code, r"$event");
  }

  Future test_expression_inputBinding_noEvent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    var code = r"""
<h1 [hidden]="$event">
</h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.UNDEFINED_IDENTIFIER, code, r"$event");
  }

  Future test_expression_mustache_noEvent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    var code = r"""
<h1>{{$event}}</h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.UNDEFINED_IDENTIFIER, code, r"$event");
  }

  Future test_expression_mustache_closeOpen_githubBug198() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    var code = r"""
    }}{{''}}
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNOPENED_MUSTACHE, code, "}}");
  }

  Future test_expression_as_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1>{{str as String}}</h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "str as String");
  }

  Future test_expression_nested_as_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1>{{(str.isEmpty as String).isEmpty}}</h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.DISALLOWED_EXPRESSION, code,
        "str.isEmpty as String");
  }

  Future test_expression_typed_list_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="<String>[].isEmpty"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "<String>[]");
  }

  Future test_expression_setter_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="str = 'hey'"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "str = 'hey'");
  }

  Future test_expression_assignment_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 #h1 [hidden]="h1 = 4"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "h1 = 4");
  }

  Future test_statements_assignment_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 #h1 (click)="h1 = 4"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "h1 = 4");
  }

  Future test_expression_invocation_of_erroneous_assignment_no_crash() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
  Function f;
}
''');
    var code = r"""
{{str = (f)()}}
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "str = (f)()");
  }

  Future test_statements_setter_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 #h1 (click)="str = 'hey'"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_expression_is_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="str is int"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "str is int");
  }

  Future test_expression_typed_map_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="<String, String>{}.keys.isEmpty"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "<String, String>{}");
  }

  Future test_expression_func_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="(){}"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "(){}");
  }

  Future test_expression_func2_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="()=>x"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "()=>x");
  }

  Future test_expression_symbol_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="#symbol"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "#symbol");
  }

  Future test_expression_symbol_invoked_noCrash() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="#symbol()"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "#symbol");
  }

  Future test_expression_await_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="await str"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    //This actually gets parsed as an identifier, which is OK. Still fails!
    errorListener.assertErrorsWithCodes([
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      AngularWarningCode.TRAILING_EXPRESSION
    ]);
  }

  Future test_expression_throw_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="throw str"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "throw str");
  }

  Future test_expression_cascade_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="str..x"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "str..x");
  }

  Future test_expression_new_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="new String().isEmpty"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "new String()");
  }

  Future test_expression_named_args_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  bool callMe({String arg}) => true;
}
''');
    var code = r"""
<h1 [hidden]="callMe(arg: 'bob')"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "arg: 'bob'");
  }

  Future test_expression_rethrow_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="rethrow"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "rethrow");
  }

  Future test_expression_super_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="super.x"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "super");
  }

  Future test_expression_this_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    var code = r"""
<h1 [hidden]="this"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "this");
  }

  Future test_expression_attrBinding_valid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    var code = r"""
<span [attr.aria-title]='text'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_expression_attrBinding_expressionTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int pixels;
}
''');
    var code = r"""
<span [attr.aria]='pixels.length'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticTypeWarningCode.UNDEFINED_GETTER, code, "length");
  }

  Future test_expression_classBinding_valid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    var code = r"""
<span [class.my-class]='text == null'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_expression_classBinding_invalidClassName() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String title;
}
''');
    var code = r"""
<span [class.invalid.class]='title == null'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_HTML_CLASSNAME, code, "invalid.class");
  }

  Future test_expression_classBinding_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String notBoolean;
}
''');
    var code = r"""
<span [class.aria]='notBoolean'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CLASS_BINDING_NOT_BOOLEAN, code, "notBoolean");
  }

  Future test_expression_styleBinding_noUnit_valid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    var code = r"""
<span [style.background-color]='text'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_expression_styleBinding_noUnit_invalidCssProperty() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    var code = r"""
<span [style.invalid*property]='text'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_CSS_PROPERTY_NAME, code, "invalid*property");
  }

  Future test_expression_styleBinding_noUnit_expressionTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int noLength; // 1
}
''');
    var code = r"""
<span [style.background-color]='noLength.length'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticTypeWarningCode.UNDEFINED_GETTER, code, "length");
  }

  Future test_expression_styleBinding_withUnit_invalidPropertyName() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int pixels; // 1
}
''');
    var code = r"""
<span [style.border&radius.px]='pixels'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_CSS_PROPERTY_NAME, code, "border&radius");
  }

  Future test_expression_styleBinding_withUnit_invalidUnitName() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  double pixels; // 1
}
''');
    var code = r"""
<span [style.border-radius.p|x]='pixels'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_CSS_UNIT_NAME, code, "p|x");
  }

  Future test_expression_styleBinding_withUnit_heightPercent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int percentage; // 1
}
''');
    var code = r"""
<span [style.height.%]='percentage'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_expression_styleBinding_withUnit_widthPercent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int percentage; // 1
}
''');
    var code = r"""
<span [style.width.%]='percentage'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_expression_styleBinding_withUnit_nonWidthOrHeightPercent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int percentage; // 1
}
''');
    var code = r"""
<span [style.something.%]='percentage'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_CSS_UNIT_NAME, code, "%");
  }

  Future test_expression_styleBinding_withUnit_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String notNumber; // 1
}
''');
    var code = r"""
<span [style.border-radius.px]='notNumber'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CSS_UNIT_BINDING_NOT_NUMBER, code, "notNumber");
  }

  Future test_expression_detect_eof_post_semicolon_in_moustache() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String name = "TestPanel";
}
''');

    var code = r"""
<p>{{name; bad portion}}</p>
 """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TRAILING_EXPRESSION, code, "; bad portion");
  }

  Future test_expression_detect_eof_ellipsis_in_moustache() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String name = "TestPanel";
}
''');
    var code = r"""
<p>{{name...}}</p>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TRAILING_EXPRESSION, code, "...");
  }

  Future test_expression_detect_eof_post_semicolon_in_property_binding() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int a = 1;
  int b = 1;
}
''');

    var code = r"""
<div [class.selected]="a == b; bad portion"></div>
 """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TRAILING_EXPRESSION, code, "; bad portion");
  }

  Future test_expression_detect_eof_ellipsis_in_property_binding() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int a = 1;
  int b = 1;
}
''');
    var code = r"""
<div [class.selected]="a==b..."></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TRAILING_EXPRESSION, code, "...");
  }

  Future test_expression_inputAndOutputBinding_genericDirective_ok() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [GenericComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String string;
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T> {
  @Output() EventEmitter<T> output;
  @Input() T input;

  @Output() EventEmitter<T> twoWayChange;
  @Input() T twoWay;
}
''');
    var code = r"""
<generic-comp (output)='$event.length' [input]="string" [(twoWay)]="string"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      test_expression_inputAndOutputBinding_genericDirectiveChild_ok() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [GenericComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String string;
}
class Generic<T> {
  EventEmitter<T> output;
  T input;

  EventEmitter<T> twoWayChange;
  T twoWay;
}
@Component(selector: 'generic-comp', template: '',
    inputs: ['input', 'twoWay'], outputs: ['output', 'twoWayChange'])
class GenericComponent<T> extends Generic<T> {
}
''');
    var code = r"""
<generic-comp (output)='$event.length' [input]="string" [(twoWay)]="string"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      test_expression_inputAndOutputBinding_extendGenericUnbounded_ok() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [GenericComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String string;
}
class Generic<T> {
  EventEmitter<T> output;
  T input;

  EventEmitter<T> twoWayChange;
  T twoWay;
}
@Component(selector: 'generic-comp', template: '',
    inputs: ['input', 'twoWay'], outputs: ['output', 'twoWayChange'])
class GenericComponent<T> extends Generic {
}
''');
    var code = r"""
<generic-comp (output)='$event.length' [input]="string" [(twoWay)]="string"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      test_expression_inputAndOutputBinding_genericDirective_chain_ok() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [GenericComponent], templateUrl: 'test_panel.html')
class TestPanel {
  String string;
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T extends E, E> {
  @Output() EventEmitter<T> output;
  @Input() T input;

  @Output() EventEmitter<T> twoWayChange;
  @Input() T twoWay;
}
''');
    var code = r"""
<generic-comp (output)='$event.length' [input]="string" [(twoWay)]="string"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      test_expression_inputAndOutputBinding_genericDirective_nested_ok() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [GenericComponent], templateUrl: 'test_panel.html')
class TestPanel {
  List<String> stringList;
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T> {
  @Output() EventEmitter<List<T>> output;
  @Input() List<T> input;

  @Output() EventEmitter<List<T>> twoWayChange;
  @Input() List<T> twoWay;
}
''');
    var code = r"""
<generic-comp (output)='$event[0].length' [input]="stringList" [(twoWay)]="stringList"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      test_expression_inputBinding_genericDirective_lowerBoundTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [GenericComponent], templateUrl: 'test_panel.html')
class TestPanel {
  int notString;
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T extends String> {
  @Input() T string;
}
''');
    var code = r"""
<generic-comp [string]="notString"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_BINDING_TYPE_ERROR, code, "notString");
  }

  Future
      test_expression_input_genericDirective_lowerBoundChainTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [GenericComponent], templateUrl: 'test_panel.html')
class TestPanel {
  int notString;
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T extends O, O extends String> {
  @Input() T string;
}
''');
    var code = r"""
<generic-comp [string]="notString"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_BINDING_TYPE_ERROR, code, "notString");
  }

  Future
      test_expression_input_genericDirective_lowerBoundNestedTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [GenericComponent], templateUrl: 'test_panel.html')
class TestPanel {
  List<int> notStringList;
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T extends String> {
  @Input() List<T> stringList;
}
''');
    var code = r"""
<generic-comp [stringList]="notStringList"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_BINDING_TYPE_ERROR, code, "notStringList");
  }

  Future
      test_expression_outputBinding_genericDirective_lowerBoundTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [GenericComponent], templateUrl: 'test_panel.html')
class TestPanel {
  takeInt(int i) {}
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T extends String> {
  @Output() EventEmitter<T> string;
}
''');
    var code = r"""
<generic-comp (string)="takeInt($event)"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE, code, r"$event");
  }

  Future
      test_expression_twoWayBinding_genericDirective_lowerBoundTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel',
    directives: const [GenericComponent], templateUrl: 'test_panel.html')
class TestPanel {
  int anInt;
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T extends String> {
  @Output() EventEmitter<T> stringChange;
  @Input() dynamic string;
}
''');
    var code = r"""
<generic-comp [(string)]="anInt"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TWO_WAY_BINDING_OUTPUT_TYPE_ERROR, code, "anInt");
  }

  Future test_expression_pipe_in_moustache() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String name = "TestPanel";
}
''');
    var code = r"""
<p>{{((1 | pipe1:(2+2):(5 | pipe2:1:2)) + (2 | pipe3:4:2))}}</p>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_expression_pipe_in_moustache_with_error() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String name = "TestPanel";
}
''');
    var code = r"""
<p>{{((1 | pipe1:(2+2):(5 | pipe2:1:2)) + (error1 | pipe3:4:2))}}</p>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.UNDEFINED_IDENTIFIER, code, "error1");
  }

  Future test_expression_pipe_in_input_binding() async {
    _addDartSource(r'''
@Component(
    selector: 'name-panel',
@View(template: r"<div>AAA</div>")
class NamePanel {
  @Input() int value;
}
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NamePanel])
class TestPanel {
  int value;
}
''');
    _addHtmlSource(r"""
<name-panel [value]='value | pipe1'></name-panel>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_expression_pipe_in_ngFor() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> operators = [];
}
''');
    _addHtmlSource(r"""
<li *ngFor='let operator of (operators | pipe1)'>
  {{operator.length}}
</li>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      test_statement_eventBinding_single_statement_without_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    _addHtmlSource(r"""
<div (click)='handleClick($event)'></div>
""");
    await _resolveSingleTemplate(dartSource);
    _assertElement('handleClick').dart.method.at('handleClick(MouseEvent');
    errorListener.assertNoErrors();
  }

  Future test_statement_eventBinding_single_statement_with_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    _addHtmlSource(r"""
<div (click)='handleClick($event);'></div>
""");
    await _resolveSingleTemplate(dartSource);
    _assertElement('handleClick').dart.method.at('handleClick(MouseEvent');
    errorListener.assertNoErrors();
  }

  Future
      test_statement_eventBinding_return_statement_without_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""<h2 (click)='return 5'></h2>""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
        code,
        "return 5");
  }

  Future test_statement_eventBinding_return_statement_with_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""<h2 (click)='return 5;'></h2>""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
        code,
        "return 5");
  }

  Future test_statement_eventBinding_if_statement_without_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""<h2 (click)='if(true){}'></h2>""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
        code,
        "if(true){}");
  }

  Future test_statement_eventBinding_if_statement_with_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""<h2 (click)='if(true){};'></h2>""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
        code,
        "if(true){}");
  }

  Future test_statement_eventBinding_double_statement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    _addHtmlSource(r"""
<div (click)='handleClick($event); 5+5;'></div>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement('handleClick').dart.method.at('handleClick(MouseEvent');
  }

  Future test_statement_eventBinding_error_on_second_statement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""
<div (click)='handleClick($event); unknownFunction()'></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticTypeWarningCode.UNDEFINED_METHOD, code, "unknownFunction");
  }

  Future test_statement_eventBinding_error_on_assignment_statement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""
<div (click)='handleClick($event); String s;'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
        code,
        "String s");
  }

  Future test_statement_eventBinding_typeError() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""
<div (click)='handleClick($event); 1 + "asdf";'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE, code, '"asdf"');
  }

  Future test_statement_eventBinding_all_semicolons() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""
<div (click)=';;;;;;;;;;;;;'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_statement_eventBinding_single_variable() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
  String random_string = "";
}
''');
    String code = r"""
<div (click)='handleClick;'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      test_statement_eventBinding_unexpected_closing_brackets_at_end() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""
<div (click)='handleClick($event);}}}}'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(ParserErrorCode.UNEXPECTED_TOKEN, code, '}}}}');
  }

  Future
      test_statement_eventBinding_unexpected_closing_brackets_at_start() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""
<div (click)='}}handleClick($event)'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(ParserErrorCode.UNEXPECTED_TOKEN, code, '}}');
  }

  Future
      test_statement_eventBinding_typechecking_after_unexpected_bracket() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""
<div (click)='}1.length'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertMultipleErrorsInCodeAtPositions(code, {
      ParserErrorCode.UNEXPECTED_TOKEN: '}',
      StaticTypeWarningCode.UNDEFINED_GETTER: 'length'
    });
  }

  Future test_inheritedFields() async {
    _addDartSource(r'''
class BaseComponent {
  String text; // 1
}
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel extends BaseComponent {
  main() {
    text.length;
  }
}
''');
    _addHtmlSource(r"""
<div>
  Hello {{text}}!
</div>
""");
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    _assertElement("text}}").dart.getter.at('text; // 1');
    errorListener.assertNoErrors();
  }

  Future test_inputReference() async {
    _addDartSource(r'''
@Component(
    selector: 'name-panel',
    inputs: const ['aaa', 'bbb', 'ccc'])
@View(template: r"<div>AAA</div>")
class NamePanel {
  int aaa;
  int bbb;
  int ccc;
}
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NamePanel])
class TestPanel {}
''');
    _addHtmlSource(r"""
<name-panel aaa='1' [bbb]='2' bind-ccc='3' id="someid"></name-panel>
""");
    await _resolveSingleTemplate(dartSource);
    _assertElement("aaa=").input.at("aaa', ");
    _assertElement("bbb]=").input.at("bbb', ");
    _assertElement("ccc=").input.at("ccc']");
    _assertElement("id=").input.inCoreHtml;
  }

  Future test_outputReference() async {
    _addDartSource(r'''
@Component(selector: 'name-panel',
    template: r"<div>AAA</div>")
class NamePanel {
  @Output() EventEmitter aaa;
  @Output() EventEmitter bbb;
  @Output() EventEmitter ccc;
}
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NamePanel])
class TestPanel {}
''');
    _addHtmlSource(r"""
<name-panel aaa='1' (bbb)='2' on-ccc='3'></name-panel>
""");
    await _resolveSingleTemplate(dartSource);
    _assertElement("bbb)=").output.at("bbb;");
    _assertElement("ccc=").output.at("ccc;");
    ElementSearch search =
        new ElementSearch((e) => e.localName == "name-panel");
    template.ast.accept(search);

    expect(search.element, isNotNull);
    expect(search.element.boundDirectives, hasLength(1));
    DirectiveBinding boundDirective = search.element.boundDirectives.first;
    expect(boundDirective.outputBindings, hasLength(2));
    expect(boundDirective.outputBindings[0].boundOutput.name, 'bbb');
    expect(boundDirective.outputBindings[1].boundOutput.name, 'ccc');
  }

  Future test_twoWayReference() async {
    _addDartSource(r'''
@Component(
    selector: 'name-panel',
@View(template: r"<div>AAA</div>")
class NamePanel {
  @Input() int value;
  @Output() EventEmitter<int> valueChange;
}
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NamePanel])
class TestPanel {
  int value;
}
''');
    _addHtmlSource(r"""
<name-panel [(value)]='value'></name-panel>
""");
    await _resolveSingleTemplate(dartSource);
    _assertElement("value)]").input.at("value;");
  }

  Future test_localVariable_camelCaseName() async {
    _addDartSource(r'''
import 'dart:html';

@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(Element e) {}
}
''');
    _addHtmlSource(r"""
<h1 (click)='handleClick(myTargetElement)'>
  <div #myTargetElement></div>
</h1>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement("myTargetElement)").local.at("myTargetElement>");
  }

  Future test_localVariable_exportAs() async {
    _addDartSource(r'''
@Directive(selector: '[myDirective]', exportAs: 'exportedValue')
class MyDirective {
  String aaa; // 1
}

@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [MyDirective])
class TestPanel {}
''');
    _addHtmlSource(r"""
<div myDirective #value='exportedValue'>
  {{value.aaa}}
</div>
""");
    await _resolveSingleTemplate(dartSource);
    _assertElement("myDirective #").selector.at("myDirective]");
    _assertElement("value=").local.declaration.type('MyDirective');
    _assertElement("exportedValue'>").angular.at("exportedValue')");
    _assertElement("value.aaa").local.at("value=");
    _assertElement("aaa}}").dart.getter.at('aaa; // 1');
  }

  Future test_attributeReference() async {
    _addDartSource(r'''
@Component(
    selector: 'name-panel',
    template: r"<div>AAA</div>")
class NamePanel {
  NamePanel(@Attribute("name-panel-attr") String namePanelAttr);
}
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NamePanel])
class TestPanel {}
''');
    _addHtmlSource(r"""
<name-panel name-panel-attr="foo"></name-panel>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement("name-panel-attr=")
        .angular
        .inFileName('/test_panel.dart')
        .at("namePanelAttr");
  }

  Future test_erroroneousTemplate_starHash_noCrash() async {
    _addDartSource(r'''
import 'dart:html';

@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(Element e) {}
}
''');
    _addHtmlSource(r"""
<h1 (click)='handleClick(myTargetElement)'>
  <div *#myTargetElement></div>
</h1>
""");
    await _resolveSingleTemplate(dartSource);
    // no assertion. Just don't crash.
  }

  Future test_localVariable_exportAs_notFound() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {}
''');
    var code = r"""
<div #value='noSuchExportedValue'>
  {{value.aaa}}
  assertErrorInCodeAtPosition fails when it sees multiple errors.
  this shouldn't err because 'value' should be known as uncheckable.
</div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.NO_DIRECTIVE_EXPORTED_BY_SPECIFIED_NAME,
        code,
        "noSuchExportedValue");
  }

  Future test_localVariable_scope_forwardReference() async {
    _addDartSource(r'''
import 'dart:html';

@Component(selector: 'aaa', inputs: const ['target'])
@View(template: '')
class ComponentA {
  void set target(ComponentB b) {}
}

@Component(selector: 'bbb')
@View(template: '')
class ComponentB {}

@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [ComponentA, ComponentB])
class TestPanel {}
''');
    _addHtmlSource(r"""
<div>
  <aaa [target]='handle'></aaa>
  <bbb #handle></bbb>
</div>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement("handle'>").local.at("handle></bbb>").type('ComponentB');
  }

  Future test_ngContent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {}
''');
    _addHtmlSource(r"""
<ng-content></ng-content>>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_ngFor_iterableElementType() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  MyIterable<String> items = new MyIterable<String>();
}
class BaseIterable<T> {
  Iterator<T> get iterator => <T>[].iterator;
}
class MyIterable<T> extends BaseIterable<T> {
}
''');
    _addHtmlSource(r"""
<li template='ngFor let item of items'>
  {{item.length}}
</li>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement("item.").local.at('item of').type('String');
    _assertElement("length}}").dart.getter;
  }

  Future test_ngFor_operatorLocalVariable() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> operators = [];
}
''');
    _addHtmlSource(r"""
<li *ngFor='let operator of operators'>
  {{operator.length}}
</li>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    expect(template.ranges, hasLength(7));
    _assertElement("ngFor=").selector.inFileName('ng_for.dart');
    _assertElement("operator of").local.declaration.type('String');
    _assertElement("length}}").dart.getter;
    errorListener.assertNoErrors();
    ElementSearch search = new ElementSearch((e) => e.localName == "li");
    template.ast.accept(search);

    expect(search.element, isNotNull);
    expect(search.element.templateAttribute, isNotNull);
    expect(search.element.templateAttribute.boundDirectives, hasLength(1));
    DirectiveBinding boundDirective =
        search.element.templateAttribute.boundDirectives.first;
    expect(boundDirective.inputBindings, hasLength(1));
    expect(boundDirective.inputBindings.first.boundInput.name, 'ngForOf');
  }

  Future test_ngFor_operatorLocalVariableVarKeyword() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> operators = [];
}
''');
    _addHtmlSource(r"""
<li *ngFor='var operator of operators'>
  {{operator.length}}
</li>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    expect(template.ranges, hasLength(7));
    _assertElement("ngFor=").selector.inFileName('ng_for.dart');
    _assertElement("operator of").local.declaration.type('String');
    _assertElement("length}}").dart.getter;
    errorListener.assertNoErrors();
  }

  Future test_ngFor_star() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<li *ngFor='let item of items; let i = index; let e = even; let o = odd; let f = first; let l = last;'>
  {{i}} {{item.length}}
  {{o}} {{e}} {{f}} {{l}}
</li>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    expect(template.ranges, hasLength(22));
    _assertElement("ngFor=").selector.inFileName('ng_for.dart');
    _assertElement("item of").local.declaration.type('String');
    _assertSelectorElement("of items")
        .selector
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertInputElement("of items")
        .input
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertElement("items;").dart.getter.at('items = []');
    _assertElement("i = index").local.declaration.type('int');
    _assertElement("i}}").local.at('i = index');
    _assertElement("item.").local.at('item of');
    _assertElement("length}}").dart.getter;
    _assertElement("e = even").local.declaration.type('bool');
    _assertElement("e}}").local.at('e = even');
    _assertElement("o = odd").local.declaration.type('bool');
    _assertElement("o}}").local.at('o = odd');
    _assertElement("f = first").local.declaration.type('bool');
    _assertElement("f}}").local.at('f = first');
    _assertElement("l = last").local.declaration.type('bool');
    _assertElement("l}}").local.at('l = last');
  }

  Future test_ngFor_noStarError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    var code = r"""
<li ngFor='let item of items; let i = index'>
</li>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.STRUCTURAL_DIRECTIVES_REQUIRE_TEMPLATE,
        code,
        "ngFor");
  }

  Future test_ngFor_star_itemHiddenInElement() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<h1 *ngFor='let item of items' [hidden]='item == null'>
</h1>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement("item == null").local.at('item of items');
  }

  Future test_ngFor_templateAttribute() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<li template='ngFor let item of items; let i = index'>
  {{i}} {{item.length}}
</li>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement("ngFor let").selector.inFileName('ng_for.dart');
    _assertElement("item of").local.declaration.type('String');
    _assertSelectorElement("of items")
        .selector
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertInputElement("of items")
        .input
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertElement("items;").dart.getter.at('items = []');
    _assertElement("i = index").local.declaration.type('int');
    _assertElement("i}}").local.at('i = index');
    _assertElement("item.").local.at('item of');
    _assertElement("length}}").dart.getter;
  }

  Future test_ngFor_templateAttribute2() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<li template='ngFor: let item, of = items, let i=index'>
  {{i}} {{item.length}}
</li>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement("ngFor:").selector.inFileName('ng_for.dart');
    _assertElement("item, of").local.declaration.type('String');
    _assertSelectorElement("of = items,")
        .selector
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertInputElement("of = items,")
        .input
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertElement("items,").dart.getter.at('items = []');
    _assertElement("i=index").local.declaration.type('int');
    _assertElement("i}}").local.at('i=index');
    _assertElement("item.").local.at('item, of');
    _assertElement("length}}").dart.getter;
  }

  Future test_ngFor_templateElement() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<template ngFor let-item [ngForOf]='items' let-i='index'>
  <li>{{i}} {{item.length}}</li>
</template>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement("ngFor let").selector.inFileName('ng_for.dart');
    _assertElement("item [").local.declaration.type('String');
    _assertSelectorElement("ngForOf]")
        .selector
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertInputElement("ngForOf]")
        .input
        .name('ngForOf')
        .inFileName('ng_for.dart');
    _assertElement("items'").dart.getter.at('items = []');
    _assertElement("i='index").local.declaration.type('int');
    _assertElement("i}}").local.at("i='index");
    _assertElement("item.").local.at('item [');
    _assertElement("length}}").dart.getter;
  }

  Future test_ngFor_templateElementVar() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<template ngFor var-item [ngForOf]='items' var-i='index'>
  <li>{{i}} {{item.length}}</li>
</template>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement("item [").local.declaration.type('String');
    _assertElement("i='index").local.declaration.type('int');
    _assertElement("i}}").local.at("i='index");
    _assertElement("item.").local.at('item [');
  }

  Future test_ngFor_variousKinds_useLowerIdentifier() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<template ngFor let-item1 [ngForOf]='items' let-i='index' {{lowerEl}}>
  {{item1.length}}
</template>
<li template="ngFor let item2 of items; let i=index" {{lowerEl}}>
  {{item2.length}}
</li>
<li *ngFor="let item3 of items; let i=index" {{lowerEl}}>
  {{item3.length}}
</li>
<div #lowerEl></div>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_ngFor_hash_instead_of_let() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    var code = r"""
<li *ngFor='#item of items; let i = index'>
</li>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNEXPECTED_HASH_IN_TEMPLATE, code, "#");
  }

  Future test_ngForSugar_dartExpression() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgFor])
class TestPanel {
  List<String> getItems(int unused) => [];
  int unused;
}
''');
    _addHtmlSource(r"""
<li template="ngFor let item1 of getItems(unused + 5); let i=index">
  {{item1.length}}
</li>
<li *ngFor="let item2 of getItems(unused + 5); let i=index">
  {{item2.length}}
</li>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_ngIf_star() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgIf])
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<span *ngIf='text.length != 0'></span>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertSelectorElement("ngIf=").selector.inFileName('ng_if.dart');
    _assertInputElement("ngIf=").input.inFileName('ng_if.dart');
    _assertElement("text.").dart.getter.at('text; // 1');
    _assertElement("length != 0").dart.getter;
  }

  Future test_ngIf_noStarError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgIf])
class TestPanel {
  String text; // 1
}
''');
    var code = r"""
<span ngIf='text.length != 0'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.STRUCTURAL_DIRECTIVES_REQUIRE_TEMPLATE,
        code,
        "ngIf");
  }

  Future test_ngIf_templateAttribute() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgIf])
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<span template='ngIf text.length != 0'></span>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertSelectorElement("ngIf text").selector.inFileName('ng_if.dart');
    _assertInputElement("ngIf text").input.inFileName('ng_if.dart');
    _assertElement("text.").dart.getter.at('text; // 1');
    _assertElement("length != 0").dart.getter;
  }

  Future test_ngIf_templateElement() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NgIf])
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<template [ngIf]='text.length != 0'></template>
""");
    await _resolveSingleTemplate(dartSource);
    _assertSelectorElement("ngIf]").selector.inFileName('ng_if.dart');
    _assertInputElement("ngIf]").input.inFileName('ng_if.dart');
    _assertElement("text.").dart.getter.at('text; // 1');
    _assertElement("length != 0").dart.getter;
  }

  Future test_standardHtmlComponent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void inputChange(String value, String validationMessage) {}
}
''');
    _addHtmlSource(r"""
<input #inputEl M
       (change)='inputChange(inputEl.value, inputEl.validationMessage)'>
""");
    await _resolveSingleTemplate(dartSource);
    _assertElement('input #').selector.inCoreHtml.at('input");');
    _assertElement('inputEl M').local.at('inputEl M');
    _assertElement('inputChange(inputEl').dart.method.at('inputChange(Str');
    _assertElement('inputEl.value').local.at('inputEl M');
    _assertElement('value, ').dart.getter.inCoreHtml;
    _assertElement('inputEl.validationMessage').local.at('inputEl M');
    _assertElement('validationMessage)').dart.getter.inCoreHtml;
    _assertElement('change)').output.inCoreHtml;
    errorListener.assertNoErrors();
    expect(ranges, hasLength(8));
  }

  Future test_standardHtmlComponentUsingRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void inputChange(String value, String validationMessage) {}
}
''');
    _addHtmlSource(r"""
<input ref-inputEl M
       (change)='inputChange(inputEl.value, inputEl.validationMessage)'>
""");
    await _resolveSingleTemplate(dartSource);
    _assertElement('input ref').selector.inCoreHtml.at('input");');
    _assertElement('inputEl M').local.at('inputEl M');
    _assertElement('inputChange(inputEl').dart.method.at('inputChange(Str');
    _assertElement('inputEl.value').local.at('inputEl M');
    _assertElement('value, ').dart.getter.inCoreHtml;
    _assertElement('inputEl.validationMessage').local.at('inputEl M');
    _assertElement('validationMessage)').dart.getter.inCoreHtml;
    _assertElement('change)').output.inCoreHtml;
    errorListener.assertNoErrors();
    expect(ranges, hasLength(8));
  }

  Future test_template_attribute_withoutValue() async {
    _addDartSource(r'''
@Directive(selector: '[deferred-content]')
class DeferredContentDirective {}

@Component(selector: 'test-panel')
@View(
    templateUrl: 'test_panel.html',
    directives: const [DeferredContentDirective])
class TestPanel {}
''');
    _addHtmlSource(r"""
<div *deferred-content>Deferred content</div>
""");
    await _resolveSingleTemplate(dartSource);
    _assertElement('deferred-content>').selector.at("deferred-content]')");
    errorListener.assertNoErrors();
  }

  Future test_textInterpolation() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  String aaa; // 1
  String bbb; // 2
}
''');
    _addHtmlSource(r"""
<div>
  Hello {{aaa}} and {{bbb}}!
</div>
""");
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(2));
    _assertElement('aaa}}').dart.getter.at('aaa; // 1');
    _assertElement('bbb}}').dart.getter.at('bbb; // 2');
  }

  // see https://github.com/dart-lang/html/issues/44
  Future test_catchPkgHtmlGithubBug44() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  String aaa; // 1
  String bbb; // 2
}
''');
    _addHtmlSource(r"""<button attr<="value"></button>""");
    await _resolveSingleTemplate(dartSource);

    // no assertion...this throws in the github bug
  }

  Future test_angleBracketInMustacheNoCrash_githubBug204() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    String code = r"""
{{<}}
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertErrorsWithCodes([
      HtmlErrorCode.PARSE_ERROR,
      ParserErrorCode.EXPECTED_LIST_OR_MAP_LITERAL,
      ParserErrorCode.EXPECTED_TOKEN,
      ParserErrorCode.EXPECTED_TYPE_NAME,
      StaticTypeWarningCode.NON_TYPE_AS_TYPE_ARGUMENT,
      AngularWarningCode.DISALLOWED_EXPRESSION
    ]);
  }

  Future test_resolveTemplateWithNgContentTracksSelectors() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    String code = r"""
<div>
  <ng-content select="foo"></ng-content>
</div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(template.view.component.ngContents, hasLength(1));
  }

  Future test_resolveTemplateWithNgContent_noSelectorIsNull() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    String code = r"""
<div>
  <ng-content></ng-content>
</div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(template.view.component.ngContents, hasLength(1));
    expect(template.view.component.ngContents.first.selector, isNull);
  }

  Future test_resolveTemplateWithNgContent_selectorParseError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    String code = r"""
<div>
  <ng-content select="foo+bar"></ng-content>
</div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(template.view.component.ngContents, hasLength(0));
    assertErrorInCodeAtPosition(
        AngularWarningCode.CANNOT_PARSE_SELECTOR, code, "+");
  }

  Future test_resolveTemplateWithNgContent_emptySelectorError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    String code = r"""
<div>
  <ng-content select=""></ng-content>
</div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(template.view.component.ngContents, hasLength(0));
    assertErrorInCodeAtPosition(
        AngularWarningCode.CANNOT_PARSE_SELECTOR, code, "\"\"");
  }

  Future test_resolveTemplateWithNgContent_noValueError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    String code = r"""
<div>
  <ng-content select></ng-content>
</div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(template.view.component.ngContents, hasLength(0));
    assertErrorInCodeAtPosition(
        AngularWarningCode.CANNOT_PARSE_SELECTOR, code, "select");
  }

  Future test_resolveTemplateWithNgContent_hasContentsError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    String code = r"""
<div>
  <ng-content>with content</ng-content>
</div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.NG_CONTENT_MUST_BE_EMPTY, code, "<ng-content>");
  }

  Future test_resolveTemplate_provideContentWhereInvalid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NoTransclude])
class TestPanel {
}
@Component(selector: 'no-transclude')
@View(template: '')
class NoTransclude {
}
''');
    String code = r"""
<no-transclude>doesn't belong</no-transclude>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_NOT_TRANSCLUDED, code, "doesn't belong");
  }

  Future test_resolveTemplate_provideContentNgSelectAll() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [TranscludeAll])
class TestPanel {
}
@Component(selector: 'transclude-all')
@View(template: '<ng-content></ng-content>')
class TranscludeAll {
}
''');
    String code = r"""
<transclude-all>belongs</transclude-all>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_resolveTemplate_provideContentEmptyTextAlwaysOK() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [NoTransclude])
class TestPanel {
}
@Component(selector: 'no-transclude')
@View(template: '')
class NoTransclude {
}
''');
    String code = r"""
<no-transclude>
</no-transclude>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_resolvedTag_complexSelector() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [MyTag])
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
@Component(selector: 'my-tag[my-prop]', template: '')
class MyTag {
}
''');
    String code = r"""
<my-tag my-prop></my-tag>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_resolveTemplate_provideContentNgSelectAllWithSelectors() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [TranscludeAll])
class TestPanel {
}
@Component(selector: 'transclude-all')
@View(template: '<ng-content select="x"></ng-content><ng-content></ng-content>')
class TranscludeAll {
}
''');
    String code = r"""
<transclude-all>belongs</transclude-all>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_resolveTemplate_provideContentNotMatchingSelectors() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some')
@View(template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeSome {
}
''');
    String code = r"""
<transclude-some><div></div></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_NOT_TRANSCLUDED, code, "<div></div>");
  }

  Future test_resolveTemplate_provideTextInfosDontMatchSelectors() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some')
@View(template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeSome {
}
''');
    String code = r"""
<transclude-some>doesn't belong</transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_NOT_TRANSCLUDED, code, "doesn't belong");
  }

  Future test_resolveTemplate_provideContentMatchingSelectors() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some')
@View(template: '<ng-content select="[transclude-me]"></ng-content>')
class TranscludeSome {
}
''');
    String code = r"""
<transclude-some><div transclude-me></div></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future test_resolveTemplate_provideContentMatchingSelectorsKnowsTag() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some')
@View(template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeSome {
}
''');
    String code = r"""
<transclude-some><transclude-me></transclude-me></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      test_resolveTemplate_provideContentMatchingSelectorsAndAllKnowsTag() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html',
    directives: const [TranscludeAllAndKnowsTag])
class TestPanel {
}
@Component(selector: 'transclude-all-and-knows-tag')
@View(template:
    '<ng-content select="transclude-me"></ng-content><ng-content></ng-content>')
class TranscludeAllAndKnowsTag {
}
''');
    String code = r"""
<transclude-all-and-knows-tag>
  <transclude-me></transclude-me>
</transclude-all-and-knows-tag>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      test_resolveTemplate_noDashesAroundTranscludedContent_stillError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html',
    directives: const [TranscludeAllAndKnowsTag])
class TestPanel {
}
@Component(selector: 'nodashes')
@View(template: '')
class TranscludeAllAndKnowsTag {
}
''');
    String code = r"""
<nodashes>shouldn't be allowed</nodashes>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.CONTENT_NOT_TRANSCLUDED,
        code, "shouldn't be allowed");
  }

  Future
      test_resolveTemplate_noDashesAroundTranscludedContent_stillMatchesTag() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html',
    directives: const [TranscludeAllAndKnowsTag])
class TestPanel {
}
@Component(selector: 'nodashes')
@View(template: '<ng-content select="custom-tag"></ng-content>')
class TranscludeAllAndKnowsTag {
}
''');
    String code = r"""
<nodashes>
  <custom-tag></custom-tag>
</nodashes>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      test_resolveTemplate_provideContentMatchingSelectorsReportsUnknownTag() async {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some')
@View(template: '<ng-content select="[transclude-me]"></ng-content>')
class TranscludeSome {
}
''');
    String code = r"""
<transclude-some><unknown-tag transclude-me></unknown-tag></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNRESOLVED_TAG, code, "unknown-tag");
  }

  Future test_unResolvedTag_evenThoughMatchedComplexSelector() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [MyTag])
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
@Component(selector: 'my-tag.not-this-class,[my-prop]', template: '')
class MyTag {
}
''');
    String code = r"""
<my-tag my-prop></my-tag>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    _assertElement("my-prop")
        .selector
        .inFileName("test_panel.dart")
        .at("my-prop");
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNRESOLVED_TAG, code, "my-tag");
  }

  Future test_resolvedTag_evenThoughAlsoMatchesNonTagMatch() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: const [MyTag])
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
@Component(selector: '[red-herring],my-tag,[unrelated]', template: '')
class MyTag {
}
''');
    String code = r"""
<my-tag red-herring unrelated></my-tag>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    _assertElement("my-tag")
        .selector
        .inFileName("test_panel.dart")
        .at("my-tag");
    errorListener.assertNoErrors();
  }

  void _addDartSource(String code) {
    dartCode = '''
import '/angular2/angular2.dart';
$code
''';
    dartSource = newSource('/test_panel.dart', dartCode);
  }

  void _addHtmlSource(String code) {
    htmlCode = code;
    htmlSource = newSource('/test_panel.html', htmlCode);
  }

  ElementAssert _assertElement(String atString,
      [ResolvedRangeCondition condition]) {
    ResolvedRange resolvedRange = _findResolvedRange(atString, condition);
    return new ElementAssert(dartCode, dartSource, htmlCode, htmlSource,
        resolvedRange.element, resolvedRange.range.offset);
  }

  ElementAssert _assertInputElement(String atString) {
    return _assertElement(atString, _isInputElement);
  }

  ElementAssert _assertSelectorElement(String atString) {
    return _assertElement(atString, _isSelectorName);
  }

  /**
   * Return the [ResolvedRange] that starts at the position of the give
   * [search] and, if specified satisfies the given [condition].
   */
  ResolvedRange _findResolvedRange(String search,
      [ResolvedRangeCondition condition]) {
    return getResolvedRangeAtString(htmlCode, ranges, search, condition);
  }

  /**
   * Compute all the views declared in the given [dartSource], and resolve the
   * external template of the last one.
   */
  Future _resolveSingleTemplate(Source dartSource) async {
    final result = await angularDriver.resolveDart(dartSource.fullName);
    final finder = (AbstractDirective d) =>
        d is Component && d.view.templateUriSource != null;
    fillErrorListener(result.errors);
    errorListener.assertNoErrors();
    final directive = result.directives.singleWhere(finder);
    final htmlPath = (directive as Component).view.templateUriSource.fullName;
    final result2 =
        await angularDriver.resolveHtml(htmlPath, dartSource.fullName);
    fillErrorListener(result2.errors);
    final view = (result2.directives.singleWhere(finder) as Component).view;

    template = view.template;
    ranges = template.ranges;
  }

  static bool _isInputElement(ResolvedRange region) {
    return region.element is InputElement;
  }

  static bool _isSelectorName(ResolvedRange region) {
    return region.element is SelectorName;
  }
}

class ElementSearch extends AngularAstVisitor {
  ElementInfo element;
  ElementSearchFn searchFn;

  ElementSearch(this.searchFn);

  @override
  void visitElementInfo(ElementInfo info) {
    if (searchFn(info)) {
      element = info;
    } else {
      super.visitElementInfo(info);
    }
  }
}

typedef bool ElementSearchFn(ElementInfo info);
