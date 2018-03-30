import 'dart:async';

import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/dart/error/syntactic_errors.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/errors.dart';
import 'package:angular_ast/angular_ast.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:tuple/tuple.dart';
import 'package:test/test.dart';

import 'abstract_angular.dart';
import 'element_assert.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(TemplateResolverTest);
  });
}

void assertPropertyElement(AngularElement element,
    {nameMatcher, sourceMatcher}) {
  expect(element, const isInstanceOf<InputElement>());
  final inputElement = element;
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

  // ignore: non_constant_identifier_names
  Future test_attribute_mixedCase() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    _addHtmlSource(r"""
<svg viewBox='0, 0, 24 24'></svg>
""");
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(0));
  }

  // ignore: non_constant_identifier_names
  Future test_attributeInterpolation() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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

  // ignore: non_constant_identifier_names
  Future test_expression_eventBinding() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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
    final search = new ElementSearch((e) => e.localName == "div");
    template.ast.accept(search);

    expect(search.element, isNotNull);
    expect(search.element.boundStandardOutputs, hasLength(1));
    expect(search.element.boundStandardOutputs.first.boundOutput.name, 'click');
  }

  // ignore: non_constant_identifier_names
  Future test_expression_keyupdownWithKeysOk() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handle(dynamic e) {
  }
}
''');
    _addHtmlSource(r"""
<div (keyup.a)='handle($event)'></div>
<div (keydown.enter)='handle($event)'></div>
<div (keydown.shift.x)='handle($event)'></div>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_reductionsOnRegularOutputsNotAllowed() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handle(dynamic e) {
  }
}
''');
    var code = r'''
<div (click.whatever)='handle($event)'></div>
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.EVENT_REDUCTION_NOT_ALLOWED, code, '.whatever');
  }

  // ignore: non_constant_identifier_names
  Future test_expression_nativeEventBindingOnComponent() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: [SomeComponent])
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

  // ignore: non_constant_identifier_names
  Future test_expression_eventBinding_on() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_valid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
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
    final search = new ElementSearch((e) => e.localName == "span");
    template.ast.accept(search);

    expect(search.element, isNotNull);
    expect(search.element.boundDirectives, hasLength(1));
    final boundDirective = search.element.boundDirectives.first;
    expect(boundDirective.inputBindings, hasLength(1));
    expect(boundDirective.inputBindings.first.boundInput.name, 'title');
  }

  // ignore: non_constant_identifier_names
  Future test_expression_nativeGlobalAttrBindingOnComponent() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: [SomeComponent])
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

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_asString() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
}
@Component(selector: 'title-comp', template: '')
class TitleComponent {
  @Input() String title;
}
''');
    final code = r"""
<title-comp title='anything can go here' id="some id"></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement('title=').input.inFileName('/test_panel.dart').at('title;');
    _assertElement('id=').input.inCoreHtml;
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_asString_fromDynamic() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
}
@Component(selector: 'title-comp', template: '')
class TitleComponent {
  bool _title;
  @Input()
  set title(value) {
    _title = value == "" ? true : false;
  }
  bool get title => _title;
}
''');

    final code = r"""
<title-comp title='anything can go here'></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement('title=').input.inFileName('/test_panel.dart').at('title(');
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() int title;
}
''');
    final code = r"""
<title-comp [title]='text'></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_BINDING_TYPE_ERROR, code, "text");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_asString_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
}
@Component(selector: 'title-comp', template: '')
class TitleComponent {
  @Input() int titleInput;
}
''');

    final code = r"""
<title-comp titleInput='string binding'></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.STRING_STYLE_INPUT_BINDING_INVALID,
        code,
        "titleInput");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_asBoool_noError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
}
@Component(selector: 'title-comp', template: '')
class TitleComponent {
  @Input() bool boolInput;
}
''');

    final code = r"""
<title-comp boolInput></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_asBool_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
}
@Component(selector: 'title-comp', template: '')
class TitleComponent {
  @Input() bool boolInput;
}
''');

    final code = r"""
<title-comp boolInput="foo bar baz"></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.STRING_STYLE_INPUT_BINDING_INVALID,
        code,
        "boolInput");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_nativeHtml_asString_notTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [],
    templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    final code = r"""
<div hidden="allowed because becomes addAttribute() rather than .hidden="></div>
<img width="allowed because becomes addAttribute() rather than .width=" />
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_noValue() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() int title;
}
''');
    final code = r"""
<title-comp [title]></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.EMPTY_BINDING, code, "[title]");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_empty() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() int title;
}
''');
    final code = r"""
<title-comp [title]=""></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.EMPTY_BINDING, code, "[title]");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_boundToNothing() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    final code = r"""
<span [title]='text'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.NONEXIST_INPUT_BOUND, code, "title");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_duplicate_standardHtml() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
  directives: const [MyTagComponent])
class TestPanel {}
@Component(selector: 'my-tag', template: '')
class MyTagComponent {
  @Input()
  String readonly;
}
''');
    final code = r'''
<my-tag [readonly]="'blah'"></my-tag>
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_alt_standardHtml() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    final code = r"""
<span [class]='text' [innerHtml]='text'></span>
""";
    await angularDriver.getStandardHtml();
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_orig_standardHtml() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    final code = r"""
<span [className]='text' [innerHTML]='text'></span>
""";
    await angularDriver.getStandardHtml();
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_safeBindings() async {
    _addDartSource(r'''
import 'package:angular/security.dart';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  SafeHtml html;
  SafeUrl url;
  SafeStyle style;
  SafeResourceUrl resourceUrl;
}
''');
    final code = r"""
<a [innerHtml]='html' [innerHTML]='html' [href]='url'></a>
<iframe [src]='resourceUrl'></iframe><!-- TODO test [style]='style' -->
""";
    await angularDriver.getStandardHtml();
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_wrongSafeBindingErrors() async {
    _addDartSource(r'''
import 'package:angular/security.dart';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  SafeHtml html;
  SafeUrl url;
  SafeStyle style;
  SafeResourceUrl resourceUrl;
}
''');
    final code = r"""
<a [innerHtml]='style' [innerHTML]='url' [href]='resourceUrl'></a>
<iframe [src]='html'></iframe> <!--TODO test [style]='html' -->
""";
    await angularDriver.getStandardHtml();
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertErrorsWithCodes([
      AngularWarningCode.INPUT_BINDING_TYPE_ERROR,
      AngularWarningCode.INPUT_BINDING_TYPE_ERROR,
      AngularWarningCode.INPUT_BINDING_TYPE_ERROR,
      AngularWarningCode.UNSAFE_BINDING, // resourceUrl gets reported this way
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_unsafelyBound() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String unsafe;
}
''');
    final code = r"""
<iframe [src]='unsafe'></iframe>
""";
    await angularDriver.getStandardHtml();
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNSAFE_BINDING, code, 'unsafe');
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_hardcodedDoesntNeedSanitization() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String unsafe;
}
''');
    final code = r"""
<iframe src='this does no sanitization and succeeds'></iframe>
""";
    await angularDriver.getStandardHtml();
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_unsafelyBoundViaMustache() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String unsafe;
}
''');
    final code = r"""
<iframe src='this is ok until we bind {{unsafe}}'></iframe>
""";
    await angularDriver.getStandardHtml();
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.UNSAFE_BINDING, code,
        'this is ok until we bind {{unsafe}}');
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_doesntNeedSafeBinding() async {
    _addDartSource(r'''
import 'package:angular/security.dart';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  SafeHtml html;
  SafeUrl url;
  SafeStyle style;
  SafeResourceUrl resourceUrl;
}
''');
    final code = r"""
<a [class]='html'></a>
<a [class]='url'></a>
<a [class]='style'></a>
<a [class]='resourceUrl'></a>
""";
    await angularDriver.getStandardHtml();
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertErrorsWithCodes([
      AngularWarningCode.INPUT_BINDING_TYPE_ERROR,
      AngularWarningCode.INPUT_BINDING_TYPE_ERROR,
      AngularWarningCode.INPUT_BINDING_TYPE_ERROR,
      AngularWarningCode.INPUT_BINDING_TYPE_ERROR,
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_expression_twoWayBinding_valid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
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
    final search = new ElementSearch((e) => e.localName == "span");
    template.ast.accept(search);

    expect(search.element, isNotNull);
    expect(search.element.boundDirectives, hasLength(1));
    final boundDirective = search.element.boundDirectives.first;
    expect(boundDirective.inputBindings, hasLength(1));
    expect(boundDirective.inputBindings.first.boundInput.name, 'title');
    expect(boundDirective.outputBindings, hasLength(1));
    expect(boundDirective.outputBindings.first.boundOutput.name, 'titleChange');
  }

  // ignore: non_constant_identifier_names
  Future test_expression_twoWayBinding_noAttr_emptyBinding() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Directive(selector: '[titled]', template: '', inputs: 'title')
class TitleComponent {
  @Input() String twoWay;
  @Output() EventEmitter<String> twoWayChange;
}
''');
    final code = r"""
<span titled [(twoWay)]></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.EMPTY_BINDING, code, "[(twoWay)]");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_twoWayBinding_inputTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() int title;
  @Output() EventEmitter<String> titleChange;
}
''');
    final code = r"""
<title-comp [(title)]='text'></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_BINDING_TYPE_ERROR, code, "text");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_twoWayBinding_outputTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() String title;
  @Output() EventEmitter<int> titleChange;
}
''');
    final code = r"""
<title-comp [(title)]='text'></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TWO_WAY_BINDING_OUTPUT_TYPE_ERROR, code, "text");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_outputBinding_noValue() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Output() EventEmitter<int> title;
}
''');
    final code = r"""
<title-comp (title)></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.EMPTY_BINDING, code, "(title)");
  }

  // ignore: non_constant_identifier_names
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
    final code = r"""
<title-comp [(title)]="text.toUpperCase()"></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TWO_WAY_BINDING_NOT_ASSIGNABLE,
        code,
        "text.toUpperCase()");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_twoWayBinding_noInputToBind() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Output() EventEmitter<String> noInputChange;
}
''');
    final code = r"""
<title-comp [(noInput)]="text"></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.NONEXIST_INPUT_BOUND, code, "noInput");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_twoWayBinding_noOutputToBind() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
@Component(selector: 'title-comp', template: '', inputs: 'title')
class TitleComponent {
  @Input() String inputOnly;
}
''');
    final code = r"""
<title-comp [(inputOnly)]="text"></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.NONEXIST_TWO_WAY_OUTPUT_BOUND, code, "inputOnly");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_bind() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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

  // ignore: non_constant_identifier_names
  Future test_expression_outputBinding_boundToNothing() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    final code = r"""
<span (title)='text'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.NONEXIST_OUTPUT_BOUND, code, "title");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_outputBinding_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [TitleComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  takeString(String arg);
}
@Component(selector: 'title-comp', template: '')
class TitleComponent {
  @Output() EventEmitter<int> output;
}
''');
    final code = r"""
<title-comp (output)='takeString($event)'></title-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE, code, r"$event");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputBinding_noEvent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    final code = r"""
<h1 [hidden]="$event">
</h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.UNDEFINED_IDENTIFIER, code, r"$event");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_mustache_noEvent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    final code = r"""
<h1>{{$event}}</h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.UNDEFINED_IDENTIFIER, code, r"$event");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_mustache_closeOpen_githubBug198() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    final code = r"""
    }}{{''}}
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNOPENED_MUSTACHE, code, '}}');
  }

  // ignore: non_constant_identifier_names
  Future test_expression_as_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1>{{str as String}}</h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "str as String");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_nested_as_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1>{{(str.isEmpty as String).isEmpty}}</h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.DISALLOWED_EXPRESSION, code,
        "str.isEmpty as String");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_typed_list_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="<String>[].isEmpty"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "<String>[]");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_setter_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="str = 'hey'"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "str = 'hey'");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_assignment_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 #h1 [hidden]="h1 = 4"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "h1 = 4");
  }

  // ignore: non_constant_identifier_names
  Future test_statements_assignment_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 #h1 (click)="h1 = 4"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "h1 = 4");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_invocation_of_erroneous_assignment_no_crash() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
  Function f;
}
''');
    final code = r"""
{{str = (f)()}}
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "str = (f)()");
  }

  // ignore: non_constant_identifier_names
  Future test_statements_setter_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 #h1 (click)="str = 'hey'"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_is_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="str is int"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "str is int");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_typed_map_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="<String, String>{}.keys.isEmpty"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "<String, String>{}");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_func_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="(){}"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "(){}");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_func2_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="()=>x"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "()=>x");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_symbol_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="#symbol"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "#symbol");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_symbol_invoked_noCrash() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="#symbol()"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "#symbol");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_await_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
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

  // ignore: non_constant_identifier_names
  Future test_expression_throw_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="throw str"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "throw str");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_cascade_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="str..x"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "str..x");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_new_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="new String().isEmpty"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "new String()");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_named_args_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  bool callMe({String arg}) => true;
}
''');
    final code = r"""
<h1 [hidden]="callMe(arg: 'bob')"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "arg: 'bob'");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_rethrow_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="rethrow"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "rethrow");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_super_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="super.x"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "super");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_this_not_allowed() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String str;
}
''');
    final code = r"""
<h1 [hidden]="this"></h1>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DISALLOWED_EXPRESSION, code, "this");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_attrBinding_valid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    final code = r"""
<span [attr.aria-title]='text'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_attrBinding_expressionTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int pixels;
}
''');
    final code = r"""
<span [attr.aria]='pixels.length'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticTypeWarningCode.UNDEFINED_GETTER, code, "length");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_classBinding_valid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    final code = r"""
<span [class.my-class]='text == null'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_classBinding_invalidClassName() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String title;
}
''');
    final code = r"""
<span [class.invalid.class]='title == null'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_HTML_CLASSNAME, code, "invalid.class");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_classBinding_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String notBoolean;
}
''');
    final code = r"""
<span [class.aria]='notBoolean'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CLASS_BINDING_NOT_BOOLEAN, code, "notBoolean");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_styleBinding_noUnit_valid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    final code = r"""
<span [style.background-color]='text'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_styleBinding_noUnit_invalidCssProperty() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    final code = r"""
<span [style.invalid*property]='text'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertMultipleErrorsExplicit(htmlSource, code, [
      new Tuple4(']', 0, AngularWarningCode.NONEXIST_INPUT_BOUND, ['']),
      new Tuple4(']', 1,
          NgParserWarningCode.EXPECTED_WHITESPACE_BEFORE_NEW_DECORATOR, []),
      new Tuple4('[', 14, NgParserWarningCode.SUFFIX_PROPERTY, []),
      new Tuple4('*property', 9, AngularWarningCode.TEMPLATE_ATTR_NOT_USED, []),
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_expression_styleBinding_noUnit_expressionTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int noLength; // 1
}
''');
    final code = r"""
<span [style.background-color]='noLength.length'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticTypeWarningCode.UNDEFINED_GETTER, code, "length");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_styleBinding_withUnit_invalidPropertyName() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int pixels; // 1
}
''');
    final code = r"""
<span [style.border&radius.px]='pixels'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertMultipleErrorsExplicit(htmlSource, code, [
      new Tuple4(
          "]='pixels'", 0, AngularWarningCode.NONEXIST_INPUT_BOUND, ['']),
      new Tuple4("]='pixels'", 1,
          NgParserWarningCode.EXPECTED_WHITESPACE_BEFORE_NEW_DECORATOR, []),
      new Tuple4('&radius', 1, NgParserWarningCode.UNEXPECTED_TOKEN, []),
      new Tuple4('[style', 14, NgParserWarningCode.SUFFIX_PROPERTY, []),
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_expression_styleBinding_withUnit_invalidUnitName() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  double pixels; // 1
}
''');
    final code = r"""
<span [style.border-radius.p|x]='pixels'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertMultipleErrorsExplicit(htmlSource, code, [
      new Tuple4(
          "]='pixels'", 0, AngularWarningCode.NONEXIST_INPUT_BOUND, ['']),
      new Tuple4("]='pixels'", 1,
          NgParserWarningCode.EXPECTED_WHITESPACE_BEFORE_NEW_DECORATOR, []),
      new Tuple4('|x', 1, NgParserWarningCode.UNEXPECTED_TOKEN, []),
      new Tuple4('[style', 23, NgParserWarningCode.SUFFIX_PROPERTY, []),
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_expression_styleBinding_withUnit_heightPercent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int percentage; // 1
}
''');
    final code = r"""
<span [style.height.%]='percentage'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_styleBinding_withUnit_widthPercent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int percentage; // 1
}
''');
    final code = r"""
<span [style.width.%]='percentage'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_styleBinding_withUnit_nonWidthOrHeightPercent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int percentage; // 1
}
''');
    final code = r"""
<span [style.something.%]='percentage'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INVALID_CSS_UNIT_NAME, code, "%");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_styleBinding_withUnit_typeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String notNumber; // 1
}
''');
    final code = r"""
<span [style.border-radius.px]='notNumber'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CSS_UNIT_BINDING_NOT_NUMBER, code, "notNumber");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_detect_eof_post_semicolon_in_moustache() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String name = "TestPanel";
}
''');

    final code = r"""
<p>{{name; bad portion}}</p>
 """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TRAILING_EXPRESSION, code, "; bad portion");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_detect_eof_ellipsis_in_moustache() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String name = "TestPanel";
}
''');
    final code = r"""
<p>{{name...}}</p>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TRAILING_EXPRESSION, code, "...");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_detect_eof_post_semicolon_in_property_binding() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int a = 1;
  int b = 1;
}
''');

    final code = r"""
<div [class.selected]="a == b; bad portion"></div>
 """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TRAILING_EXPRESSION, code, "; bad portion");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_detect_eof_ellipsis_in_property_binding() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  int a = 1;
  int b = 1;
}
''');
    final code = r"""
<div [class.selected]="a==b..."></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TRAILING_EXPRESSION, code, "...");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_inputAndOutputBinding_genericDirective_ok() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [GenericComponent],
    templateUrl: 'test_panel.html')
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
    final code = r"""
<generic-comp (output)='$event.length' [input]="string" [(twoWay)]="string"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_expression_inputAndOutputBinding_genericDirectiveChild_ok() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [GenericComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  String string;
}
class Generic<T> {
  EventEmitter<T> output;
  T input;

  EventEmitter<T> twoWayChange;
  T twoWay;
}
@Component(selector: 'generic-comp', template: '', inputs: ['input', 'twoWay'],
    outputs: ['output', 'twoWayChange'])
class GenericComponent<T> extends Generic<T> {
}
''');
    final code = r"""
<generic-comp (output)='$event.length' [input]="string" [(twoWay)]="string"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_expression_inputAndOutputBinding_extendGenericUnbounded_ok() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [GenericComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  String string;
}
class Generic<T> {
  EventEmitter<T> output;
  T input;

  EventEmitter<T> twoWayChange;
  T twoWay;
}
@Component(selector: 'generic-comp', template: '', inputs: ['input', 'twoWay'],
    outputs: ['output', 'twoWayChange'])
class GenericComponent<T> extends Generic {
}
''');
    final code = r"""
<generic-comp (output)='$event.length' [input]="string" [(twoWay)]="string"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_expression_inputAndOutputBinding_genericDirective_chain_ok() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [GenericComponent],
    templateUrl: 'test_panel.html')
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
    final code = r"""
<generic-comp (output)='$event.length' [input]="string" [(twoWay)]="string"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_expression_inputAndOutputBinding_genericDirective_nested_ok() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [GenericComponent],
    templateUrl: 'test_panel.html')
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
    final code = r"""
<generic-comp (output)='$event[0].length' [input]="stringList" [(twoWay)]="stringList"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_expression_inputBinding_genericDirective_lowerBoundTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [GenericComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  int notString;
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T extends String> {
  @Input() T string;
}
''');
    final code = r"""
<generic-comp [string]="notString"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_BINDING_TYPE_ERROR, code, "notString");
  }

  Future
      // ignore: non_constant_identifier_names
      test_expression_input_genericDirective_lowerBoundChainTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [GenericComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  int notString;
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T extends O, O extends String> {
  @Input() T string;
}
''');
    final code = r"""
<generic-comp [string]="notString"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_BINDING_TYPE_ERROR, code, "notString");
  }

  Future
      // ignore: non_constant_identifier_names
      test_expression_input_genericDirective_lowerBoundNestedTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [GenericComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  List<int> notStringList;
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T extends String> {
  @Input() List<T> stringList;
}
''');
    final code = r"""
<generic-comp [stringList]="notStringList"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.INPUT_BINDING_TYPE_ERROR, code, "notStringList");
  }

  Future
      // ignore: non_constant_identifier_names
      test_expression_outputBinding_genericDirective_lowerBoundTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [GenericComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  takeInt(int i) {}
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T extends String> {
  @Output() EventEmitter<T> string;
}
''');
    final code = r"""
<generic-comp (string)="takeInt($event)"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE, code, r"$event");
  }

  Future
      // ignore: non_constant_identifier_names
      test_expression_twoWayBinding_genericDirective_lowerBoundTypeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', directives: const [GenericComponent],
    templateUrl: 'test_panel.html')
class TestPanel {
  int anInt;
}
@Component(selector: 'generic-comp', template: '')
class GenericComponent<T extends String> {
  @Output() EventEmitter<T> stringChange;
  @Input() dynamic string;
}
''');
    final code = r"""
<generic-comp [(string)]="anInt"></generic-comp>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TWO_WAY_BINDING_OUTPUT_TYPE_ERROR, code, "anInt");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_pipe_in_moustache() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String name = "TestPanel";
}
''');
    final code = r"""
<p>{{((1 | pipe1:(2+2):(5 | pipe2:1:2)) + (2 | pipe3:4:2))}}</p>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_expression_pipe_in_moustache_with_error() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String name = "TestPanel";
}
''');
    final code = r"""
<p>{{((1 | pipe1:(2+2):(5 | pipe2:1:2)) + (error1 | pipe3:4:2))}}</p>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.UNDEFINED_IDENTIFIER, code, "error1");
  }

  // ignore: non_constant_identifier_names
  Future test_expression_pipe_in_input_binding() async {
    _addDartSource(r'''
@Component(selector: 'name-panel', template: r"<div>AAA</div>")
class NamePanel {
  @Input() int value;
}
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NamePanel])
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

  // ignore: non_constant_identifier_names
  Future test_expression_pipe_in_ngFor() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
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
      // ignore: non_constant_identifier_names
      test_statement_eventBinding_single_statement_without_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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

  // ignore: non_constant_identifier_names
  Future test_statement_eventBinding_single_statement_with_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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
      // ignore: non_constant_identifier_names
      test_statement_eventBinding_return_statement_without_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""<h2 (click)='return 5'></h2>""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
        code,
        "return 5");
  }

  // ignore: non_constant_identifier_names
  Future test_statement_eventBinding_return_statement_with_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""<h2 (click)='return 5;'></h2>""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
        code,
        "return 5");
  }

  // ignore: non_constant_identifier_names
  Future test_statement_eventBinding_if_statement_without_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""<h2 (click)='if(true){}'></h2>""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
        code,
        "if(true){}");
  }

  // ignore: non_constant_identifier_names
  Future test_statement_eventBinding_if_statement_with_semicolon() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""<h2 (click)='if(true){};'></h2>""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
        code,
        "if(true){}");
  }

  // ignore: non_constant_identifier_names
  Future test_statement_eventBinding_double_statement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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

  // ignore: non_constant_identifier_names
  Future test_statement_eventBinding_error_on_second_statement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""
<div (click)='handleClick($event); unknownFunction()'></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticTypeWarningCode.UNDEFINED_METHOD, code, "unknownFunction");
  }

  // ignore: non_constant_identifier_names
  Future test_statement_eventBinding_error_on_assignment_statement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""
<div (click)='handleClick($event); String s;'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
        code,
        "String s");
  }

  // ignore: non_constant_identifier_names
  Future test_statement_eventBinding_typeError() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""
<div (click)='handleClick($event); 1 + "asdf";'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE, code, '"asdf"');
  }

  // ignore: non_constant_identifier_names
  Future test_statement_eventBinding_all_semicolons() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""
<div (click)=';;;;;;;;;;;;;'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_statement_eventBinding_single_variable() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
  String random_string = "";
}
''');
    final code = r"""
<div (click)='handleClick;'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_statement_eventBinding_unexpected_closing_brackets_at_end() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""
<div (click)='handleClick($event);}}}}'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(ParserErrorCode.UNEXPECTED_TOKEN, code, '}}}}');
  }

  Future
      // ignore: non_constant_identifier_names
      test_statement_eventBinding_unexpected_closing_brackets_at_start() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""
<div (click)='}}handleClick($event)'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(ParserErrorCode.UNEXPECTED_TOKEN, code, '}}');
  }

  Future
      // ignore: non_constant_identifier_names
      test_statement_eventBinding_typechecking_after_unexpected_bracket() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""
<div (click)='}1.length'></div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertMultipleErrorsExplicit(htmlSource, code, [
      new Tuple4('}1', 1, ParserErrorCode.UNEXPECTED_TOKEN, ['}']),
      new Tuple4('length', 6, StaticTypeWarningCode.UNDEFINED_GETTER,
          ['length', 'int']),
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_inheritedFields() async {
    _addDartSource(r'''
class BaseComponent {
  String text; // 1
}
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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

  // ignore: non_constant_identifier_names
  Future test_inputReference() async {
    _addDartSource(r'''
@Component(selector: 'name-panel', inputs: const ['aaa', 'bbb', 'ccc'],
  template: r"<div>AAA</div>")
class NamePanel {
  int aaa;
  int bbb;
  int ccc;
}
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NamePanel])
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

  // ignore: non_constant_identifier_names
  Future test_outputReference() async {
    _addDartSource(r'''
@Component(selector: 'name-panel', template: r"<div>AAA</div>")
class NamePanel {
  @Output() EventEmitter aaa;
  @Output() EventEmitter bbb;
  @Output() EventEmitter ccc;
}
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NamePanel])
class TestPanel {}
''');
    _addHtmlSource(r"""
<name-panel aaa='1' (bbb)='2' on-ccc='3'></name-panel>
""");
    await _resolveSingleTemplate(dartSource);
    _assertElement("bbb)=").output.at("bbb;");
    _assertElement("ccc=").output.at("ccc;");
    final search = new ElementSearch((e) => e.localName == "name-panel");
    template.ast.accept(search);

    expect(search.element, isNotNull);
    expect(search.element.boundDirectives, hasLength(1));
    final boundDirective = search.element.boundDirectives.first;
    expect(boundDirective.outputBindings, hasLength(2));
    expect(boundDirective.outputBindings[0].boundOutput.name, 'bbb');
    expect(boundDirective.outputBindings[1].boundOutput.name, 'ccc');
  }

  // ignore: non_constant_identifier_names
  Future test_twoWayReference() async {
    _addDartSource(r'''
@Component(selector: 'name-panel', template: r"<div>AAA</div>")
class NamePanel {
  @Input() int value;
  @Output() EventEmitter<int> valueChange;
}
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NamePanel])
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

  // ignore: non_constant_identifier_names
  Future test_localVariable_camelCaseName() async {
    _addDartSource(r'''
import 'dart:html';

@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [MyDivComponent])
class TestPanel {
  void handleClick(String s) {}
}
@Component(selector: 'myDiv', template: '')
class MyDivComponent {
  String someString = 'asdf';
}
''');
    _addHtmlSource(r"""
<h1 (click)='handleClick(myTargetElement.someString)'>
  <myDiv #myTargetElement></myDiv>
</h1>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement("myTargetElement.someString)").local.at("myTargetElement>");
  }

  // ignore: non_constant_identifier_names
  Future test_localVariable_exportAs() async {
    _addDartSource(r'''
@Directive(selector: '[myDirective]', exportAs: 'exportedValue')
class MyDirective {
  String aaa; // 1
}

@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [MyDirective])
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

  // ignore: non_constant_identifier_names
  Future test_letVariable_in_nonTemplate() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {}
''');
    final html = r'''<div let-value></div>''';
    _addHtmlSource(html);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        NgParserWarningCode.INVALID_LET_BINDING_IN_NONTEMPLATE,
        html,
        'let-value');
  }

  // ignore: non_constant_identifier_names
  Future test_attributeReference() async {
    _addDartSource(r'''
@Component(selector: 'name-panel', template: r"<div>AAA</div>")
class NamePanel {
  NamePanel(@Attribute("name-panel-attr") String namePanelAttr);
}
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NamePanel])
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

  // ignore: non_constant_identifier_names
  Future test_erroroneousTemplate_starHash_noCrash() async {
    _addDartSource(r'''
import 'dart:html';

@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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

  // ignore: non_constant_identifier_names
  Future test_localVariable_exportAs_notFound() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {}
''');
    final code = r"""
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

  // ignore: non_constant_identifier_names
  Future test_localVariable_exportAs_ambiguous() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
  directives: const [Directive1, Directive2])
class TestPanel {}

@Directive(selector: '[dir1]', exportAs: 'ambiguous')
class Directive1 {}

@Directive(selector: '[dir2]', exportAs: 'ambiguous')
class Directive2 {}
''');
    final code = r"""
<div dir1 dir2 #value="ambiguous"></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.DIRECTIVE_EXPORTED_BY_AMBIGIOUS, code, 'ambiguous');
  }

  // ignore: non_constant_identifier_names
  Future test_localVariable_scope_forwardReference() async {
    _addDartSource(r'''
import 'dart:html';

@Component(selector: 'aaa', inputs: const ['target'], template: '')
class ComponentA {
  void set target(ComponentB b) {}
}

@Component(selector: 'bbb', template: '')
class ComponentB {}

@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: [ComponentA, ComponentB])
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

  // ignore: non_constant_identifier_names
  Future test_ngContent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {}
''');
    _addHtmlSource(r"""
<ng-content></ng-content>>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_ngFor_iterableElementType() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
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

  // ignore: non_constant_identifier_names
  Future test_ngFor_operatorLocalVariable() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
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
    final search = new ElementSearch((e) => e.localName == "li");
    template.ast.accept(search);

    expect(search.element, isNotNull);
    expect(search.element.templateAttribute, isNotNull);
    expect(search.element.templateAttribute.boundDirectives, hasLength(1));
    final boundDirective =
        search.element.templateAttribute.boundDirectives.first;
    expect(boundDirective.inputBindings, hasLength(1));
    expect(boundDirective.inputBindings.first.boundInput.name, 'ngForOf');
  }

  // ignore: non_constant_identifier_names
  Future test_ngFor_operatorLocalVariableVarKeyword() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
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

  // ignore: non_constant_identifier_names
  Future test_ngFor_star() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
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

  // ignore: non_constant_identifier_names
  Future test_ngFor_noStarError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    final code = r"""
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

  // ignore: non_constant_identifier_names
  Future test_customDirective_noStarError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [CustomTemplateDirective])
class TestPanel {
}

@Directive(selector: '[customTemplateDirective]')
class CustomTemplateDirective {
  CustomTemplateDirective(TemplateRef tpl);
}
''');
    final code = r"""
<div customTemplateDirective></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CUSTOM_DIRECTIVE_MAY_REQUIRE_TEMPLATE,
        code,
        "<div customTemplateDirective>");
  }

  // ignore: non_constant_identifier_names
  Future test_customDirective_withStarOk() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [CustomTemplateDirective])
class TestPanel {
}

@Directive(selector: '[customTemplateDirective]')
class CustomTemplateDirective {
  CustomTemplateDirective(TemplateRef tpl);
}
''');
    final code = r"""
<div *customTemplateDirective></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_customDirective_asTemplateAttrOk() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [CustomTemplateDirective])
class TestPanel {
}

@Directive(selector: '[customTemplateDirective]')
class CustomTemplateDirective {
  CustomTemplateDirective(TemplateRef tpl);
}
''');
    final code = r"""
<div template="customTemplateDirective"></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_customDirective_starDoesntTakeTemplateError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NotTemplateDirective])
class TestPanel {
}

@Directive(selector: '[notTemplateDirective]')
class NotTemplateDirective {
}
''');
    final code = r"""
<div *notTemplateDirective></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.TEMPLATE_ATTR_NOT_USED, code,
        "*notTemplateDirective");
  }

  // ignore: non_constant_identifier_names
  Future test_starNoDirectives() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [])
class TestPanel {
}
''');
    final code = r"""
<div *foo></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TEMPLATE_ATTR_NOT_USED, code, "*foo");
  }

  // ignore: non_constant_identifier_names
  Future test_customDirective_templateDoesntTakeTemplateError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NotTemplateDirective])
class TestPanel {
}

@Directive(selector: '[notTemplateDirective]')
class NotTemplateDirective {
}
''');
    final code = r"""
<div template="notTemplateDirective"></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TEMPLATE_ATTR_NOT_USED, code, 'template');
  }

  // ignore: non_constant_identifier_names
  Future test_templateNoDirectives() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [])
class TestPanel {
}
''');
    final code = r"""
<div template="foo"></div>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.TEMPLATE_ATTR_NOT_USED, code, 'template');
  }

  // ignore: non_constant_identifier_names
  Future test_ngFor_star_itemHiddenInElement() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
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

  // ignore: non_constant_identifier_names
  Future test_ngFor_templateAttribute() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
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

  // ignore: non_constant_identifier_names
  Future test_ngFor_templateAttribute2() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
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

  // ignore: non_constant_identifier_names
  Future test_ngFor_templateElement() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
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

  // ignore: non_constant_identifier_names
  Future test_letVar_template_cascading() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor, FoobarDirective])
class TestPanel {
  List<String> items = [];
}
@Directive(selector: '[foobar]')
class FoobarDirective {
  @Input()
  String foobar;
}
''');
    _addHtmlSource(r"""
<template ngFor let-item [ngForOf]='items' let-i='index'>
  <template [foobar]="item"></template>
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
    _assertElement("item").local.at('item [');
  }

  // ignore: non_constant_identifier_names
  Future test_hashRef_templateElement() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html', 
  directives: const [HasTemplateInputComponent])
class TestPanel {
}
@Component(selector: 'has-template-input', template: '')
class HasTemplateInputComponent {
  @Input()
  TemplateRef myTemplate;
}
''');
    _addHtmlSource(r"""
<template #someTemplate></template>
<has-template-input [myTemplate]="someTemplate"></has-template-input>
""");
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
    _assertElement('someTemplate"').local.at('someTemplate>');
  }

  // ignore: non_constant_identifier_names
//  Future test_ngFor_variousKinds_useLowerIdentifier() async {
//    _addDartSource(r'''
//@Component(selector: 'test-panel')
//@View(templateUrl: 'test_panel.html', directives: const [NgFor])
//class TestPanel {
//  List<String> items = [];
//}
//''');
//    _addHtmlSource(r"""
//<template ngFor let-item1 [ngForOf]='items' let-i='index' {{lowerEl}}>
//  {{item1.length}}
//</template>
//<li template="ngFor let item2 of items; let i=index" {{lowerEl}}>
//  {{item2.length}}
//</li>
//<li *ngFor="let item3 of items; let i=index" {{lowerEl}}>
//  {{item3.length}}
//</li>
//<div #lowerEl></div>
//""");
//    await _resolveSingleTemplate(dartSource);
//    errorListener.assertNoErrors();
//  }

  // ignore: non_constant_identifier_names
  Future test_ngFor_hash_instead_of_let() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    final code = r"""
<li *ngFor='#item of items; let i = index'>
</li>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNEXPECTED_HASH_IN_TEMPLATE, code, "#");
  }

  // ignore: non_constant_identifier_names
  Future test_ngForSugar_dartExpression() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
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

  // ignore: non_constant_identifier_names
  Future test_ngForSugar_noDartExpressionError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
class TestPanel {
}
''');
    final code = r'''
<li *ngFor="let item of"></li>
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.EMPTY_BINDING, code, 'of');
  }

  // ignore: non_constant_identifier_names
  Future test_ngForSugar_noTrackByExpressionError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgFor])
class TestPanel {
  List items;
}
''');
    final code = r'''
<li *ngFor="let item of items; trackBy:"></li>
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.EMPTY_BINDING, code, 'trackBy');
  }

  // ignore: non_constant_identifier_names
  Future test_ngIf_star() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgIf])
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

  // ignore: non_constant_identifier_names
  Future test_ngIf_noStarError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgIf])
class TestPanel {
  String text; // 1
}
''');
    final code = r"""
<span ngIf='text.length != 0'></span>
""";
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.STRUCTURAL_DIRECTIVES_REQUIRE_TEMPLATE,
        code,
        "ngIf");
  }

  // ignore: non_constant_identifier_names
  Future test_ngIf_emptyStarError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgIf])
class TestPanel {
  String text; // 1
}
''');
    final code = r'''
<span *ngIf=""></span>
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    // TODO would be nice if this selected ""
    assertErrorInCodeAtPosition(AngularWarningCode.EMPTY_BINDING, code, 'ngIf');
  }

  // ignore: non_constant_identifier_names
  Future test_ngIf_starNoAttrError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgIf])
class TestPanel {
  String text; // 1
}
''');
    final code = r'''
<span *ngIf></span>
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.EMPTY_BINDING, code, 'ngIf');
  }

  // ignore: non_constant_identifier_names
  Future test_ngIf_templateAttribute() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgIf])
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

  // ignore: non_constant_identifier_names
  Future test_ngIf_templateElement() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgIf])
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

  // ignore: non_constant_identifier_names
  Future test_templateTag_selectTemplateMatches() async {
    _addDartSource(r'''
@Component(selector: 'test-panel' templateUrl: 'test_panel.html',
    directives: const [MyStarDirective])
class TestPanel {
}
@Directive(selector: 'template[myStarDirective]')
class MyStarDirective {
  MyStarDirective(TemplateRef ref) {}
  @Input()
  String myStarDirective;
}
''');
    final code = r'''
<template myStarDirective="'foo'"></template>
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_templateAttr() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [MyStarDirective])
class TestPanel {
}
@Directive(selector: 'template[myStarDirective]')
class MyStarDirective {
  MyStarDirective(TemplateRef ref) {}
}
''');
    final code = r'''
<div template="myStarDirective"></div>
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_star_selectTemplateMatches() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [MyStarDirective])
class TestPanel {
}
@Directive(selector: 'template[myStarDirective]')
class MyStarDirective {
  MyStarDirective(TemplateRef ref) {}
}
''');
    final code = r'''
<span *myStarDirective></span>
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_star_selectTemplateFunctionalDirectiveMatches() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [myStarDirective])
class TestPanel {
}
@Directive(selector: 'template[myStarDirective]')
void myStarDirective(TemplateRef ref) {}
''');
    final code = r'''
<span *myStarDirective></span>
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_standardHtmlComponent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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

  // ignore: non_constant_identifier_names
  Future test_standardHtmlComponentUsingRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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

  // ignore: non_constant_identifier_names
  Future test_template_attribute_withoutValue() async {
    _addDartSource(r'''
@Directive(selector: '[deferred]')
class DeferredContentDirective {
  DeferredContentDirective(TemplateRef tpl);
  @Input()
  String deferred;
}

@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [DeferredContentDirective])
class TestPanel {}
''');
    _addHtmlSource(r"""
<div *deferred>Deferred content</div>
""");
    await _resolveSingleTemplate(dartSource);
    _assertElement('deferred>').selector.at("deferred]')");
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_textInterpolation() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
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
  // ignore: non_constant_identifier_names
  Future test_catchPkgHtmlGithubBug44() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  String aaa; // 1
  String bbb; // 2
}
''');
    _addHtmlSource(r"""<button attr<="value"></button>""");
    await _resolveSingleTemplate(dartSource);

    // no assertion...this throws in the github bug
  }

  // ignore: non_constant_identifier_names
  Future test_angleBracketInMustacheNoCrash_githubBug204() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
''');
    final code = r"""
{{<}}
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertErrorsWithCodes([
      ParserErrorCode.EXPECTED_LIST_OR_MAP_LITERAL,
      ParserErrorCode.EXPECTED_TOKEN,
      ParserErrorCode.EXPECTED_TYPE_NAME,
      StaticTypeWarningCode.NON_TYPE_AS_TYPE_ARGUMENT,
      AngularWarningCode.DISALLOWED_EXPRESSION
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplateWithNgContentTracksSelectors() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    final code = r"""
<div>
  <ng-content select="foo"></ng-content>
</div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(template.view.component.ngContents, hasLength(1));
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplateWithNgContent_noSelectorIsNull() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    final code = r"""
<div>
  <ng-content></ng-content>
</div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(template.view.component.ngContents, hasLength(1));
    expect(template.view.component.ngContents.first.selector, isNull);
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplateWithNgContent_selectorParseError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    final code = r"""
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

  // ignore: non_constant_identifier_names
  Future test_resolveTemplateWithNgContent_emptySelectorError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    final code = r"""
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

  // ignore: non_constant_identifier_names
  Future test_resolveTemplateWithNgContent_noValueError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    final code = r"""
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

  // ignore: non_constant_identifier_names
  Future test_resolveTemplateWithNgContent_hasContentsError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    final code = r"""
<div>
  <ng-content>with content</ng-content>
</div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertMultipleErrorsExplicit(htmlSource, code, [
      new Tuple4('<ng-content', 12,
          NgParserWarningCode.NGCONTENT_MUST_CLOSE_IMMEDIATELY, []),
      new Tuple4(
          '</ng-content>', 13, NgParserWarningCode.DANGLING_CLOSE_ELEMENT, []),
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_provideContentWhereInvalid() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NoTransclude])
class TestPanel {
}
@Component(selector: 'no-transclude', template: '')
class NoTransclude {
}
''');
    final code = r"""
<no-transclude>doesn't belong</no-transclude>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_NOT_TRANSCLUDED, code, "doesn't belong");
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_provideContentNgSelectAll() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeAll])
class TestPanel {
}
@Component(selector: 'transclude-all', template: '<ng-content></ng-content>')
class TranscludeAll {
}
''');
    final code = r"""
<transclude-all>belongs</transclude-all>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_provideContentEmptyTextAlwaysOK() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NoTransclude])
class TestPanel {
}
@Component(selector: 'no-transclude', template: '')
class NoTransclude {
}
''');
    final code = r"""
<no-transclude>
</no-transclude>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_resolvedTag_complexSelector() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [MyTag])
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
@Component(selector: 'my-tag[my-prop]', template: '')
class MyTag {
}
''');
    final code = r"""
<my-tag my-prop></my-tag>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_provideContentNgSelectAllWithSelectors() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeAll])
class TestPanel {
}
@Component(selector: 'transclude-all',
    template: '<ng-content select="x"></ng-content><ng-content></ng-content>')
class TranscludeAll {
}
''');
    final code = r"""
<transclude-all>belongs</transclude-all>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_provideContentNotMatchingSelectors() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some',
    template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeSome {
}
''');
    final code = r"""
<transclude-some><div></div></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_NOT_TRANSCLUDED, code, "<div></div>");
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_provideTextInfosDontMatchSelectors() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some',
    template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeSome {
}
''');
    final code = r"""
<transclude-some>doesn't belong</transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_NOT_TRANSCLUDED, code, "doesn't belong");
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_provideContentMatchingSelectors() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some',
    template: '<ng-content select="[transclude-me]"></ng-content>')
class TranscludeSome {
}
''');
    final code = r"""
<transclude-some><div transclude-me></div></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_provideContentMatchingSelectorsKnowsTag() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some',
    template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeSome {
}
''');
    final code = r"""
<transclude-some><transclude-me></transclude-me></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentMatchingSelectorsAndAllKnowsTag() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeAllAndKnowsTag])
class TestPanel {
}
@Component(
  selector: 'transclude-all-and-knows-tag',
  template:
    '<ng-content select="transclude-me"></ng-content><ng-content></ng-content>')
class TranscludeAllAndKnowsTag {
}
''');
    final code = r"""
<transclude-all-and-knows-tag>
  <transclude-me></transclude-me>
</transclude-all-and-knows-tag>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_noDashesAroundTranscludedContent_stillError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeAllAndKnowsTag])
class TestPanel {
}
@Component(selector: 'nodashes', template: '')
class TranscludeAllAndKnowsTag {
}
''');
    final code = r"""
<nodashes>shouldn't be allowed</nodashes>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.CONTENT_NOT_TRANSCLUDED,
        code, "shouldn't be allowed");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_noDashesAroundTranscludedContent_stillMatchesTag() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeAllAndKnowsTag])
class TestPanel {
}
@Component(selector: 'nodashes',
    template: '<ng-content select="custom-tag"></ng-content>')
class TranscludeAllAndKnowsTag {
}
''');
    final code = r"""
<nodashes>
  <custom-tag></custom-tag>
</nodashes>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentMatchingSelectorsReportsUnknownTag() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some',
    template: '<ng-content select="[transclude-me]"></ng-content>')
class TranscludeSome {
}
''');
    final code = r"""
<transclude-some><unknown-tag transclude-me></unknown-tag></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.UNRESOLVED_TAG, code, "unknown-tag");
  }

  // ignore: non_constant_identifier_names
  Future test_unResolvedTag_evenThoughMatchedComplexSelector() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [MyTag])
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
@Component(selector: 'my-tag.not-this-class,[my-prop]', template: '')
class MyTag {
}
''');
    final code = r"""
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

  // ignore: non_constant_identifier_names
  Future test_resolvedTag_evenThoughAlsoMatchesNonTagMatch() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [MyTag])
class TestPanel {
  void handleClick(MouseEvent e) {
  }
}
@Component(selector: '[red-herring],my-tag,[unrelated]', template: '')
class MyTag {
}
''');
    final code = r"""
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

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNotMatchingSelectorsButMatchesContentChildElementRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some',
    template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeSome {
  @ContentChild(ElementRef)
  ElementRef foo;
}
''');
    final code = r"""
<transclude-some><div></div></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNotMatchingSelectorsButMatchesContentChildElement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some',
    template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeSome {
  @ContentChild(Element)
  Element foo;
}
''');
    final code = r"""
<transclude-some><div></div></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNotMatchingSelectorsButMatchesContentChildHtmlElement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some',
    template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeSome {
  @ContentChild(HtmlElement)
  HtmlElement foo;
}
''');
    final code = r"""
<transclude-some><div></div></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNotMatchingSelectorsButMatchesContentChildTemplateRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone])
class TestPanel {
}
@Component(selector: 'transclude-none',
    template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeNone {
  @ContentChild(TemplateRef)
  TemplateRef foo;
}
''');
    final code = r"""
<transclude-none><template></template></transclude-none>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNoTransclusionsButMatchesContentChildTemplateRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone])
class TestPanel {
}
@Component(selector: 'transclude-none', template: '')
class TranscludeNone {
  @ContentChild(TemplateRef)
  TemplateRef foo;
}
''');
    final code = r"""
<transclude-none><template></template></transclude-none>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNoTransclusionsButMatchesContentChildDirective() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone, ContentChildComponent])
class TestPanel {
}
@Component(selector: 'transclude-none', template: '')
class TranscludeNone {
  @ContentChild(ContentChildComponent)
  ContentChildComponent foo;
}
@Component(selector: 'content-child-comp', template: '')
class ContentChildComponent {
}
''');
    final code = r"""
<transclude-none><content-child-comp></content-child-comp></transclude-none>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNoTransclusionsButMatchesContentChildLetBoundElement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone])
class TestPanel {
}
@Component(selector: 'transclude-none', template: '')
class TranscludeNone {
  @ContentChild('contentChild', read: Element)
  Element foo;
  @ContentChild('contentChild')
  ElementRef foo; // to be deprecated, but ok
  @ContentChild('contentChild')
  dynamic fooDynamicShouldBeOk;
  @ContentChild('contentChild')
  Object fooObjectShouldBeOk;
}
''');
    final code = r"""
<transclude-none><div #contentChild></div></transclude-none>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNoTransclusionsButMatchesContentChildLetBoundTemplateRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone])
class TestPanel {
}
@Component(selector: 'transclude-none', template: '')
class TranscludeNone {
  @ContentChild('contentChild')
  TemplateRef foo;
  @ContentChild('contentChild')
  dynamic fooDynamicShouldBeOk;
  @ContentChild('contentChild')
  Object fooObjectShouldBeOk;
}
''');
    final code = r"""
<transclude-none><template #contentChild></template></transclude-none>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNoTransclusionsButMatchesContentChildLetBoundDirective() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone, ContentChildDirective])
class TestPanel {
}
@Component(selector: 'transclude-none', template: '')
class TranscludeNone {
  @ContentChild('contentChild')
  ContentChildDirective foo;
  @ContentChild('contentChild')
  dynamic fooDynamicShouldBeOk;
  @ContentChild('contentChild')
  Object fooObjectShouldBeOk;
  @ContentChild('contentChild')
  Superclass fooSuperclassShouldBeOk;
}
@Directive(selector: '[content-child]', exportAs: 'contentChild')
class ContentChildDirective extends Superclass {
}

class Superclass {}
''');
    final code = r"""
<transclude-none><div content-child #contentChild="contentChild"></div></transclude-none>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNoTransclusionsButMatchesContentChildLetBoundComponent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone, ContentChildComponent])
class TestPanel {
}
@Component(selector: 'transclude-none', template: '')
class TranscludeNone {
  @ContentChild('contentChild')
  ContentChildComponent foo;
  @ContentChild('contentChild')
  dynamic fooDynamicShouldBeOk;
  @ContentChild('contentChild')
  Object fooObjectShouldBeOk;
  @ContentChild('contentChild')
  Superclass fooSuperclassShouldBeOk;
}
@Component(selector: 'content-child-comp', template: '')
class ContentChildComponent extends Superclass {
}

class Superclass {}
''');
    final code = r"""
<transclude-none><content-child-comp #contentChild></content-child-comp></transclude-none>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNotMatchingSelectorsOrContentChildElementRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some',
    template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeSome {
  @ContentChild(ElementRef)
  ElementRef foo;
}
''');
    final code = r"""
<transclude-some><template></template></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.CONTENT_NOT_TRANSCLUDED,
        code, "<template></template>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNotMatchingSelectorsOrContentChildElement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeSome])
class TestPanel {
}
@Component(selector: 'transclude-some',
    template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeSome {
  @ContentChild(Element)
  Element foo;
}
''');
    final code = r"""
<transclude-some><template></template></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.CONTENT_NOT_TRANSCLUDED,
        code, "<template></template>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNotMatchingSelectorsOrContentChildTemplateRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone])
class TestPanel {
}
@Component(selector: 'transclude-some',
    template: '<ng-content select="transclude-me"></ng-content>')
class TranscludeNone {
  @ContentChild(TemplateRef)
  TemplateRef foo;
}
''');
    final code = r"""
<transclude-some><div></div></transclude-some>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_NOT_TRANSCLUDED, code, "<div></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNoTransclusionsNoChildElementRefMatch() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone])
class TestPanel {
}
@Component(selector: 'transclude-none', template: '')
class TranscludeNone {
  @ContentChild(ElementRef)
  ElementRef foo;
}
''');
    final code = r"""
<transclude-none><template></template></transclude-none>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.CONTENT_NOT_TRANSCLUDED,
        code, "<template></template>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNoTransclusionsNoChildElementMatch() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone])
class TestPanel {
}
@Component(selector: 'transclude-none', template: '')
class TranscludeNone {
  @ContentChild(Element)
  Element foo;
}
''');
    final code = r"""
<transclude-none><template></template></transclude-none>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.CONTENT_NOT_TRANSCLUDED,
        code, "<template></template>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNoTransclusionsNoContentChildTemplateRefMatch() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone])
class TestPanel {
}
@Component(selector: 'transclude-none', template: '')
class TranscludeNone {
  @ContentChild(TemplateRef)
  TemplateRef foo;
}
''');
    final code = r"""
<transclude-none><div></div></transclude-none>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_NOT_TRANSCLUDED, code, "<div></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentNoTransclusionsNoContentChildDirectiveMatch() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone, ContentChildComponent])
class TestPanel {
}
@Component(selector: 'transclude-none', template: '')
class TranscludeNone {
  @ContentChild(ContentChildComponent)
  ContentChildComponent foo;
}
@Component(selector: 'content-child-comp', template: '')
class ContentChildComponent {
}
''');
    final code = r"""
<transclude-none><div></div></transclude-none>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.CONTENT_NOT_TRANSCLUDED, code, "<div></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentMatchingHigherComponentsIsStillNotTranscludedError() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [TranscludeNone, TranscludeAllWithContentChild])
class TestPanel {
}
@Component(selector: 'transclude-none', template: '')
class TranscludeNone {
}
@Component(selector: 'transclude-all-with-content-child',
    template: '<ng-content></ng-content>')
class TranscludeAllWithContentChild {
  @ContentChild("contentChildOfHigherComponent", read: Element)
  Element foo;
}
''');
    final code = r"""
<transclude-all-with-content-child>
  <transclude-none>
    <div #contentChildOfHigherComponent></div>
  </transclude-none>
</transclude-all-with-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(AngularWarningCode.CONTENT_NOT_TRANSCLUDED,
        code, "<div #contentChildOfHigherComponent></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_templateNotElementRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  ElementRef foo;
}
''');
    final code = r"""
<has-content-child><template #contentChild></template></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<template #contentChild></template>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_templateNotElement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild', read: Element)
  Element foo;
}
''');
    final code = r"""
<has-content-child><template #contentChild></template></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<template #contentChild></template>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_componentNotElementRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild, SomeComponent])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  ElementRef foo;
}
@Component(selector: 'some-component', template: '')
class SomeComponent {
}
''');
    final code = r"""
<has-content-child><some-component #contentChild></some-component></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<some-component #contentChild></some-component>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_componentNotElement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild, SomeComponent])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild', read: Element)
  Element foo;
}
@Component(selector: 'some-component', template: '')
class SomeComponent {
}
''');
    final code = r"""
<has-content-child><some-component #contentChild></some-component></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<some-component #contentChild></some-component>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_directiveNotElementRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild, SomeDirective])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  ElementRef foo;
}
@Directive(selector: '[some-directive]', template: '', exportAs: "theDirective")
class SomeDirective {
}
''');
    final code = r"""
<has-content-child><div some-directive #contentChild="theDirective"></div></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<div some-directive #contentChild=\"theDirective\"></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_directiveNotElement() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild, SomeDirective])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild', read: Element)
  Element foo;
}
@Directive(selector: '[some-directive]', template: '', exportAs: "theDirective")
class SomeDirective {
}
''');
    final code = r"""
<has-content-child><div some-directive #contentChild="theDirective"></div></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<div some-directive #contentChild=\"theDirective\"></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_elementNotTemplateRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  TemplateRef foo;
}
''');
    final code = r"""
<has-content-child><div #contentChild></div></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<div #contentChild></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_componentNotTemplateRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild, SomeComponent])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  TemplateRef foo;
}
@Component(selector: 'some-component', template: '')
class SomeComponent {
}
''');
    final code = r"""
<has-content-child><some-component #contentChild></some-component></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<some-component #contentChild></some-component>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_directiveNotTemplateRef() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild, SomeDirective])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  TemplateRef foo;
}
@Directive(selector: '[some-directive]', template: '', exportAs: "theDirective")
class SomeDirective {
}
''');
    final code = r"""
<has-content-child><div some-directive #contentChild></div></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<div some-directive #contentChild></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_elementNotComponent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  SomeComponent foo;
}
@Component(selector: 'some-component', template: '')
class SomeComponent {
}
''');
    final code = r"""
<has-content-child><div #contentChild></div></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<div #contentChild></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_templateNotComponent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  SomeComponent foo;
}
@Component(selector: 'some-component', template: '')
class SomeComponent {
}
''');
    final code = r"""
<has-content-child><template #contentChild></template></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<template #contentChild></template>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_wrongComponent() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild, SomeOtherComponent])
class TestPanel {
}
@Component(selector: 'has-content-child',
  template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  SomeComponent foo;
}
@Component(selector: 'some-component', template: '')
class SomeComponent {
}
@Component(selector: 'some-other-component', template: '')
class SomeOtherComponent {
}
''');
    final code = r"""
<has-content-child><some-other-component #contentChild></some-other-component></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<some-other-component #contentChild></some-other-component>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_elementNotDirective() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  SomeDirective foo;
}
@Directive(selector: '[some-directive]')
class SomeDirective {
}
''');
    final code = r"""
<has-content-child><div #contentChild></div></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<div #contentChild></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_element_directiveNotExported() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild, SomeDirective])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  SomeDirective foo;
}
@Directive(selector: '[some-directive]')
class SomeDirective {
}
''');
    final code = r"""
<has-content-child><div some-directive #contentChild></div></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<div some-directive #contentChild></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_templateNotDirective() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  SomeDirective foo;
}
@Directive(selector: '[some-directive]')
class SomeDirective {
}
''');
    final code = r"""
<has-content-child><template #contentChild></template></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<template #contentChild></template>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_wrongDirective() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild, SomeOtherDirective])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild')
  SomeDirective foo;
}
@Directive(selector: '[some-directive]', exportAs: 'right')
class SomeDirective {
}
@Directive(selector: '[some-other-directive]', exportAs: 'wrong')
class SomeOtherDirective {
}
''');
    final code = r"""
<has-content-child><div some-other-directive #contentChild="wrong"></div></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<div some-other-directive #contentChild=\"wrong\"></div>");
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_readValueIsAlwaysOk() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '')
class HasContentChild {
  @ContentChild('contentChild', read: ViewContainerRef)
  ViewContainerRef foo;
}
''');
    final code = r"""
<has-content-child><div #contentChild></div></has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplate_provideContentChildLetBound_directiveNotElement_deeplyNested() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChild, SomeDirective])
class TestPanel {
}
@Component(selector: 'has-content-child', template: '<ng-content></ng-content>')
class HasContentChild {
  @ContentChild('contentChild', read: Element)
  Element foo;
}
@Directive(selector: '[some-directive]', template: '', exportAs: "theDirective")
class SomeDirective {
}
''');
    final code = r"""
<has-content-child>
  <div>
    <span>
      <div>
        <div some-directive #contentChild="theDirective"></div>
      </div>
    </span>
  </div>
</has-content-child>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
        code,
        "<div some-directive #contentChild=\"theDirective\"></div>");
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_provideDuplicateContentChildError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChildElementRef])
class TestPanel {
}
@Component(selector: 'has-content-child-element-ref', template: '')
class HasContentChildElementRef {
  @ContentChild(ElementRef)
  ElementRef theElement;
}
''');
    final code = r"""
<has-content-child-element-ref>
  <div first></div>
  <div second></div>
</has-content-child-element-ref>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.SINGULAR_CHILD_QUERY_MATCHED_MULTIPLE_TIMES,
        code,
        "<div second></div>");
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_provideDuplicateContentChildrenOk() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChildrenElement])
class TestPanel {
}
@Component(selector: 'has-content-children-element', template: '')
class HasContentChildrenElement {
  @ContentChildren(Element)
  List<Element> theElement;
}
''');
    final code = r"""
<has-content-children-element>
  <div first></div>
  <div second></div>
</has-content-children-element>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_provideDuplicateContentChildNestedOk() async {
    _addDartSource(r'''
import 'dart:html';
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChildElement])
class TestPanel {
}
@Component(selector: 'has-content-child-element', template: '')
class HasContentChildElement {
  @ContentChild(Element)
  Element theElement;
}
''');
    final code = r"""
<has-content-child-element>
  <div first>
    <div second></div>
  </div>
</has-content-child-element>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  Future
      // ignore: non_constant_identifier_names
      test_resolveTemplateRef_provideDuplicateContentChildSiblingsError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [HasContentChildTemplateRef])
class TestPanel {
}
@Component(selector: 'has-content-child-template-ref',
    template: '<ng-content></ng-content>')
class HasContentChildTemplateRef {
  @ContentChild(TemplateRef)
  TemplateRef theTemplate;
}
''');
    final code = r"""
<has-content-child-template-ref>
  <div>
    <template first></template>
  </div>
  <div>
    <template second></template>
  </div>
</has-content-child-template-ref>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        AngularWarningCode.SINGULAR_CHILD_QUERY_MATCHED_MULTIPLE_TIMES,
        code,
        "<template second></template>");
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_exportsNoErrors() async {
    newSource('/prefixed.dart', r'''
const double otherAccessor = 2.0;
enum OtherEnum { otherVal }
void otherFunction() {}
class OtherClass {
  static void otherStatic() {
  }
}
''');
    _addDartSource(r'''
import '/prefixed.dart' as prefixed;
const int myAccessor = 1;
enum MyEnum { myVal }
void myFunction() {}
class MyClass {
  static void myStatic() {
  }
}

@Component(
  selector: 'test-panel',
  templateUrl: 'test_panel.html',
  exports: const [
    myAccessor,
    MyEnum,
    myFunction,
    MyClass,
    prefixed.otherAccessor,
    prefixed.OtherEnum,
    prefixed.otherFunction,
    prefixed.OtherClass
])
class TestPanel {
  static void componentStatic() {
  }
}
''');
    final code = r'''
static on current class ok:
{{TestPanel.componentStatic()}}
exports ok:
{{myAccessor}}
{{MyEnum.myVal}}
{{myFunction()}}
{{MyClass.myStatic()}}
{{prefixed.otherAccessor}}
{{prefixed.OtherEnum.otherVal}}
{{prefixed.otherFunction()}} 
{{prefixed.OtherClass.otherStatic()}}
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(18));
    _assertElement('TestPanel').dart.at('TestPanel {');
    _assertElement('componentStatic').dart.method.at('componentStatic() {');
    _assertElement('myAccessor').dart.getter.at('myAccessor = 1');
    _assertElement('MyEnum').dart.at('MyEnum {');
    _assertElement('myVal').dart.at('myVal }');
    _assertElement('myFunction').dart.at('myFunction() {');
    _assertElement('MyClass').dart.at('MyClass {');
    _assertElement('myStatic').dart.at('myStatic() {');
    _assertElement('prefixed').dart.prefix.at('prefixed;');
    _assertElement('otherAccessor')
        .dart
        .getter
        .inFile('/prefixed.dart')
        .at('otherAccessor = 2.0');
    _assertElement('OtherEnum').dart.inFile('/prefixed.dart').at('OtherEnum {');
    _assertElement('otherVal').dart.inFile('/prefixed.dart').at('otherVal }');
    _assertElement('otherFunction')
        .dart
        .inFile('/prefixed.dart')
        .at('otherFunction() {');
    _assertElement('OtherClass')
        .dart
        .inFile('/prefixed.dart')
        .at('OtherClass {');
    _assertElement('otherStatic')
        .dart
        .inFile('/prefixed.dart')
        .at('otherStatic() {');
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_notExportedError() async {
    newSource('/prefixed.dart', r'''
const double otherAccessor = 2.0;
enum OtherEnum { otherVal }
void otherFunction() {}
var otherTopLevel = null;
typedef void OtherFnTypedef();
class OtherClass {
  static void otherStatic() {
  }
}
''');
    _addDartSource(r'''
import '/prefixed.dart' as prefixed;
const int myAccessor = 1;
enum MyEnum { otherVal }
void myFunction() {}
var myTopLevel = null;
typedef void MyFnTypedef();
class MyClass {
  static void myStatic() {
  }
}

@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    exports: const [])
class TestPanel {
}
''');
    final code = r'''
not exported:
{{myAccessor}}
{{MyEnum.otherVal}}
{{myFunction()}}
{{MyClass.myStatic()}}
{{prefixed.otherAccessor}}
{{prefixed.OtherEnum.otherVal}}
{{prefixed.otherFunction()}} 
{{prefixed.OtherClass.otherStatic()}}
can't be exported:
{{myTopLevel}}
{{MyFnTypedef}}
{{prefixed.otherTopLevel}}
{{prefixed.OtherFnTypedef}}
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(0));
    errorListener.assertErrorsWithCodes([
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      StaticTypeWarningCode.UNDEFINED_METHOD,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_exportsCantUsePrefixes() async {
    newSource('/prefixed.dart', 'const int prefixRequired = 1;');
    _addDartSource(r'''
import '/prefixed.dart' as prefixed;
const int prefixNotAllowed = 1;

@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    exports: const [prefixNotAllowed, prefixed.prefixRequired])
class TestPanel {
}
''');
    final code = r'''
component class can't be used with a prefix: {{prefixed.TestPanel}}
{{prefixed.prefixNotAllowed}}
{{prefixRequired}}
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(2)); // the 'prefixed' prefixes only
    errorListener.assertErrorsWithCodes([
      StaticWarningCode.UNDEFINED_GETTER,
      StaticWarningCode.UNDEFINED_GETTER,
      StaticWarningCode.UNDEFINED_IDENTIFIER,
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_invalidExportDoesntCrash() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    exports: const [garbage])
class TestPanel {
}
''');
    final code = '{{garbage}}';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(0));
    errorListener.assertErrorsWithCodes([
      StaticWarningCode.UNDEFINED_IDENTIFIER,
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_resolvingBogusImportDoesntCrash() async {
    _addDartSource(r'''
import ; // synthetic import
@Component(selector: 'test-panel', templateUrl: 'test_panel.html')
class TestPanel {
}
''');
    final code = '{{pants}}';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(0));
    errorListener.assertErrorsWithCodes([
      StaticWarningCode.UNDEFINED_IDENTIFIER,
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_nanTokenizationRangeError() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [NgIf])
class TestPanel {
  int i;
}
''');
    final code = r'''
<div *ngIf="i > 0e"></div>
''';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertErrorsWithCodes([
      ScannerErrorCode.MISSING_DIGIT,
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_customTagNames() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [])
class TestPanel {
  String foo;
}
''');
    final code = r"""
<my-first-custom-tag [unknownInput]="foo" (unknownOutput)="foo" #first str="val">
  <my-second-custom-tag [unknownInput]="foo" (unknownOutput)="foo" #second str="val">
  </my-second-custom-tag>
</my-first-custom-tag>

{{first.foo}} should be treated as "dynamic" and pass this check
{{first.bar}} should be treated as "dynamic" and pass this check
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_customTagNames_unsuppressedErrors() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [])
class TestPanel {
  String aString;
}
''');
    final code = r"""
<my-first-custom-tag
    [input]="nosuchgetter"
    #foo="nosuchexport"
    *noSuchStar
    (x.noReductionAllowed)=""
    (emptyEvent)
    [emptyInput]>
  {{aString + 1}}
  <other-unknown-tag></other-unknown-tag>
</my-first-custom-tag>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertErrorsWithCodes([
      StaticWarningCode.UNDEFINED_IDENTIFIER,
      AngularWarningCode.NO_DIRECTIVE_EXPORTED_BY_SPECIFIED_NAME,
      AngularWarningCode.TEMPLATE_ATTR_NOT_USED,
      AngularWarningCode.EVENT_REDUCTION_NOT_ALLOWED,
      AngularWarningCode.EMPTY_BINDING,
      AngularWarningCode.EMPTY_BINDING,
      AngularWarningCode.EMPTY_BINDING,
      StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE,
      AngularWarningCode.UNRESOLVED_TAG
    ]);
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_customEvent_valid() async {
    newSource('/custom-event.dart', r'''
class CustomEvent {
  int foo;
}
''');
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [])
class TestPanel {
  void acceptInt(int x) {}
}
''');
    final code = r"""
<div (custom-event)="acceptInt($event.foo)">
</div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future test_resolveTemplate_customEvent_invalid() async {
    newSource('/custom_event.dart', r'''
class CustomEvent {}
''');
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [])
class TestPanel {
  void acceptInt(int x) {}
}
''');
    final code = r"""
<div (custom-event)="acceptInt($event)">
</div>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    assertErrorInCodeAtPosition(
        StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE, code, r'$event');
  }

  Future test_strongModeSemantics_strongEnabled() async {
    _addDartSource(r'''
@Component(selector: 'test-panel', templateUrl: 'test_panel.html',
    directives: const [])
class TestPanel {
}
''');
    final code = r"""
{{[1,2,3].add("five")}}
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertErrorsWithCodes(
        [StaticWarningCode.ARGUMENT_TYPE_NOT_ASSIGNABLE]);
  }

  // ignore: non_constant_identifier_names
  Future test_futureOr() async {
    _addDartSource(r'''
import 'dart:async';
@Component(selector: 'future-or-apis', templateUrl: 'test_panel.html',
    directives: const [FutureOrApis])
class FutureOrApis {
  @Input()
  FutureOr<int> futureOrInt;
  @Input()
  Future<int> futureInt;
  @Input()
  int justInt;
}
''');
    final code = r"""
<future-or-apis [futureOrInt]="futureInt"></future-or-apis>
<future-or-apis [futureOrInt]="justInt"></future-or-apis>
    """;
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  // ignore: non_constant_identifier_names
  Future solo_test_tripleEq() async {
    _addDartSource(r'''
import 'dart:async';
@Component(selector: 'a', templateUrl: 'test_panel.html')
class UseTripleEq {
  bool a;
  int b;
}
''');
    final code = r'{{a === b}}';
    _addHtmlSource(code);
    await _resolveSingleTemplate(dartSource);
    errorListener.assertNoErrors();
  }

  void _addDartSource(final code) {
    dartCode = '''
import 'package:angular2/angular2.dart';
$code
''';
    dartSource = newSource('/test_panel.dart', dartCode);
  }

  void _addHtmlSource(final code) {
    htmlCode = code;
    htmlSource = newSource('/test_panel.html', htmlCode);
  }

  ElementAssert _assertElement(String atString,
      [ResolvedRangeCondition condition]) {
    final resolvedRange = _findResolvedRange(atString, condition);

    return new ElementAssert(dartCode, dartSource, htmlCode, htmlSource,
        resolvedRange.element, resolvedRange.range.offset);
  }

  ElementAssert _assertInputElement(String atString) =>
      _assertElement(atString, _isInputElement);

  ElementAssert _assertSelectorElement(String atString) =>
      _assertElement(atString, _isSelectorName);

  /// Return the [ResolvedRange] that starts at the position of the give
  /// [search] and, if specified satisfies the given [condition].
  ResolvedRange _findResolvedRange(String search,
          [ResolvedRangeCondition condition]) =>
      getResolvedRangeAtString(htmlCode, ranges, search, condition);

  /// Compute all the views declared in the given [dartSource], and resolve the
  /// external template of the last one.
  Future _resolveSingleTemplate(Source dartSource) async {
    final result = await angularDriver.requestDartResult(dartSource.fullName);
    bool finder(AbstractDirective d) =>
        d is Component && d.view.templateUriSource != null;
    fillErrorListener(result.errors);
    errorListener.assertNoErrors();
    directives = result.directives;
    final directive = result.directives.singleWhere(finder);
    final htmlPath = (directive as Component).view.templateUriSource.fullName;
    final result2 = await angularDriver.requestHtmlResult(htmlPath);
    fillErrorListener(result2.errors);
    final view = (result2.directives.singleWhere(finder) as Component).view;

    template = view.template;
    ranges = template.ranges;
  }

  static bool _isInputElement(ResolvedRange region) =>
      region.element is InputElement;

  static bool _isSelectorName(ResolvedRange region) =>
      region.element is SelectorName;
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
