import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/task/dart.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/tasks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';

import 'abstract_angular.dart';
import 'element_assert.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(ConverterTest);
}

@reflectiveTest
class ConverterTest extends AbstractAngularTest {
  String dartCode;
  String htmlCode;
  Source dartSource;
  Source htmlSource;

  List<AbstractDirective> directives;

  Template template;
  List<ResolvedRange> ranges;

  void test_inline_conversion() {
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
    //computeResult(target, DART_TEMPLATES);
    computeResult(target, VIEWS1);
    final view = outputs[VIEWS1][0];
    print(view.template);
    print(view.templateText);
  }

  void test_event_attribute() {
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

    computeResult(
        new LibrarySpecificUnit(dartSource, dartSource), ANGULAR_ASTS);
    _resolveSingleTemplate(dartSource);
    expect(template.ast, new isInstanceOf<ElementInfo>());
    ElementInfo root = template.ast;
    expect(root.localName, 'html');
    expect(root.childNodes.length, 2);
    ElementInfo div = root.childNodes[0];
    expect(div.localName, 'div');
    expect(div.attributes.length, 1);
    AttributeInfo event = div.attributes[0];
    expect(event.originalName, '(click)');
    expect(event.name, 'click');
    expect(event.value, 'handleClick(\$event)');
  }

  void test_expression_nativeEventBindingOnComponent() {
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
    _resolveSingleTemplate(dartSource);
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

  void _resolveSingleTemplate(Source dartSource) {
    directives = computeLibraryDirectives(dartSource);
    List<View> views = computeLibraryViews(dartSource);
    View view = views.last;
    // resolve this View
    computeResult(view, HTML_TEMPLATE);
    template = outputs[HTML_TEMPLATE];
    ranges = template.ranges;
    fillErrorListener(HTML_TEMPLATE_ERRORS);
  }
}
