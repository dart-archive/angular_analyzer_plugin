import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/task/dart.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/tasks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';
import 'package:angular_analyzer_plugin/ast.dart';

import 'abstract_angular.dart';

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
//
//  void test_inline_conversion() {
//    String code = r'''
//import '/angular2/angular2.dart';
//
//@Component(selector: 'text-panel',
//    template: r"<div> {{text.length + text}} </div>")
//class TextPanel {
//  String text;
//}
//''';
//    Source source = newSource('/test.dart', code);
//    LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
//    //computeResult(target, DART_TEMPLATES);
//    computeResult(target, VIEWS1);
//    final view = outputs[VIEWS1][0];
//    print(view.template);
//    print(view.templateText);
//  }
//
//  void test_event_attribute() {
//    _addDartSource(r'''
//import 'dart:html';
//@Component(selector: 'test-panel')
//@View(templateUrl: 'test_panel.html')
//class TestPanel {
//  void handleClick(MouseEvent e) {
//  }
//}
//''');
//    _addHtmlSource(r"""
//<div (click)='handleClick($event)'></div>
//""");
//
//    computeResult(
//        new LibrarySpecificUnit(dartSource, dartSource), ANGULAR_ASTS);
//    _resolveSingleTemplate(dartSource);
//    expect(template.ast, new isInstanceOf<ElementInfo>());
//    ElementInfo root = template.ast;
//    expect(root.localName, 'html');
//    expect(root.childNodes.length, 2);
//    ElementInfo div = root.childNodes[0];
//    expect(div.localName, 'div');
//    expect(div.attributes.length, 1);
//    AttributeInfo event = div.attributes[0];
//    expect(event.originalName, '(click)');
//    expect(event.name, 'click');
//    expect(event.value, 'handleClick(\$event)');
//  }
//
//  void test_property_attribute() {
//    _addDartSource(r'''
//import 'dart:html';
//@Component(selector: 'test-panel')
//@View(templateUrl: 'test_panel.html')
//class TestPanel {
//  void handleClick(MouseEvent e) {
//  }
//}
//''');
//    _addHtmlSource(r"""
//<div>
//  <comp-a [firstValue]='1' [second]='2'></comp-a>
//</div>
//""");
//    computeResult(
//        new LibrarySpecificUnit(dartSource, dartSource), ANGULAR_ASTS);
//    _resolveSingleTemplate(dartSource);
//
//  }

  void test_scratch() {
    String code = r'''
import '/angular2/angular2.dart';
import 'child_file.dart';

import '/angular2/angular2.dart';
@Component(selector: 'my-component', templateUrl: 'test.html',
    directives: const [ChildComponent])
class MyComponent {}
''';
    String childCode = r'''
import '/angular2/angular2.dart';
@Component(selector: 'child-component',
    template: 'My template <ng-content></ng-content>',
    directives: const [])
class ChildComponent {}
''';
    Source source = newSource('/test.dart', code);
    Source childSource = newSource('/child_file.dart', childCode);
    newSource('/test.html', '');
    View view;
    {
      LibrarySpecificUnit target = new LibrarySpecificUnit(source, source);
      computeResult(target, VIEWS_WITH_HTML_TEMPLATES1);
      expect(task, new isInstanceOf<BuildUnitViewsTask>());
      List<View> views;
      views = outputs[VIEWS_WITH_HTML_TEMPLATES1];
      expect(views, hasLength(1));
      view = views.first;
    }
    computeResult(view, HTML_TEMPLATE);
    Template template = outputs[HTML_TEMPLATE];
    expect(template, isNotNull);
  }

  void _addDartSource(String code) {
    dartCode = '''
import '/angular2/angular2.dart';
$code
''';
    dartSource = newSource('/test_panel.dart#inline', dartCode);
  }

  void _addHtmlSource(String code) {
    htmlCode = code;
    htmlSource = newSource('/test_panel.html#inline', htmlCode);
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
