library angular2.src.analysis.analyzer_plugin.src.resolver_test;

import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/tasks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';

import 'abstract_angular.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(TemplateResolverTest);
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

  void test_expression_eventBinding() {
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
<div (click)='handleClick()'></div>
""");
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    {
      ResolvedRange resolvedRange = _findResolvedRange("handleClick()'>");
      MethodElement element = assertMethod(resolvedRange);
      _assertDartElementAt(element, 'handleClick(MouseEvent');
    }
  }

  void test_expression_eventBinding_on() {
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
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    {
      ResolvedRange resolvedRange = _findResolvedRange("handleClick()'>");
      MethodElement element = assertMethod(resolvedRange);
      _assertDartElementAt(element, 'handleClick(MouseEvent');
    }
  }

  void test_expression_propertyBinding() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<span [title]='text'></span>
""");
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    {
      ResolvedRange resolvedRange = _findResolvedRange("text'>");
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'text; // 1');
    }
  }

  void test_expression_propertyBinding_bind() {
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
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    {
      ResolvedRange resolvedRange = _findResolvedRange("text'>");
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'text; // 1');
    }
  }

  void test_propertyInterpolation() {
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
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(2));
    {
      ResolvedRange resolvedRange = _findResolvedRange('aaa}}');
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'aaa; // 1');
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange('bbb}}');
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'bbb; // 2');
    }
  }

  void test_propertyReference() {
    _addDartSource(r'''
@Component(
    selector: 'name-panel',
    properties: const ['aaa', 'bbb', 'ccc'])
@View(template: r"<div>AAA</div>")
class NamePanel {
  int aaa;
  int bbb;
  int ccc;
}
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [NamePanel])
class TestPanel {}
''');
    _addHtmlSource(r"""
<name-panel aaa='1' [bbb]='2' bind-ccc='3'></name-panel>
""");
    _resolveSingleTemplate(dartSource);
    Component namePanel = getComponentByClassName(directives, 'NamePanel');
    {
      ResolvedRange resolvedRange = _findResolvedRange('aaa=');
      expect(resolvedRange.range.length, 3);
      assertPropertyReference(resolvedRange, namePanel, 'aaa');
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange('bbb]=');
      expect(resolvedRange.range.length, 3);
      assertPropertyReference(resolvedRange, namePanel, 'bbb');
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange('ccc=');
      expect(resolvedRange.range.length, 3);
      assertPropertyReference(resolvedRange, namePanel, 'ccc');
    }
  }

  void test_textInterpolation() {
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
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(2));
    {
      ResolvedRange resolvedRange = _findResolvedRange('aaa}}');
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'aaa; // 1');
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange('bbb}}');
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'bbb; // 2');
    }
  }

  void _addDartSource(String code) {
    dartCode = '''
import '/angular2/metadata.dart';
$code
''';
    dartSource = newSource('/test_panel.dart', dartCode);
  }

  void _addHtmlSource(String code) {
    htmlCode = code;
    htmlSource = newSource('/test_panel.html', htmlCode);
  }

  void _assertDartElementAt(Element element, String search) {
    expect(element.nameOffset, dartCode.indexOf(search));
  }

  ResolvedRange _findResolvedRange(String search) {
    return getResolvedRangeAtString(htmlCode, ranges, search);
  }

  /**
   * Compute all the views declared in the given [dartSource], and resolve the
   * external template of the last one.
   */
  void _resolveSingleTemplate(Source dartSource) {
    directives = computeLibraryDirectives(dartSource);
    List<View> views = computeLibraryViews(dartSource);
    View view = views.last;
    // resolve this View
    computeResult(view, HTML_TEMPLATE);
    template = outputs[HTML_TEMPLATE];
    ranges = template.ranges;
  }
}
