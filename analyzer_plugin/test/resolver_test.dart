library angular2.src.analysis.analyzer_plugin.src.resolver_test;

import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/selector.dart';
import 'package:angular2_analyzer_plugin/src/tasks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';

import 'abstract_angular.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(TemplateResolverTest);
}

void assertPropertyElement(AngularElement element,
    {nameMatcher, sourceMatcher}) {
  expect(element, new isInstanceOf<PropertyElement>());
  PropertyElement propertyElement = element;
  if (nameMatcher != null) {
    expect(propertyElement.name, nameMatcher);
  }
  if (sourceMatcher != null) {
    expect(propertyElement.source.fullName, sourceMatcher);
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

  void test_inheritedFields() {
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
    _resolveSingleTemplate(dartSource);
    expect(ranges, hasLength(1));
    {
      ResolvedRange resolvedRange = _findResolvedRange('text}}');
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'text; // 1');
    }
    errorListener.assertNoErrors();
  }

  void test_localVariable_exportAs() {
    _addDartSource(r'''
@Directive(selector: '[my-directive]', exportAs: 'exported-value')
class MyDirective {
  String aaa; // 1
}

@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [MyDirective])
class TestPanel {}
''');
    _addHtmlSource(r"""
<div my-directive #value='exported-value'>
  {{value.aaa}}
</div>
""");
    _resolveSingleTemplate(dartSource);
    {
      ResolvedRange declarationRange = _findResolvedRange("value=");
      LocalVariableElement valueElement = assertLocalVariable(declarationRange,
          name: 'value', typeName: 'MyDirective');
      _assertHtmlElementAt(valueElement, "value=");
      assertDartElement(_findResolvedRange("value.aaa"), valueElement);
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("aaa}}");
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'aaa; // 1');
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("exported-value'");
      _assertDartAngularElementAt(resolvedRange.element, "exported-value')");
      expect(resolvedRange.element,
          getDirectiveByClassName(directives, 'MyDirective').exportAs);
    }
  }

  void test_ngFor_iterableElementType() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [NgFor])
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
<li template='ng-for #item of items'>
  {{item.length}}
</li>
""");
    _resolveSingleTemplate(dartSource);
    {
      ResolvedRange resolvedRange = _findResolvedRange("item.");
      assertLocalVariable(resolvedRange, name: 'item', typeName: 'String');
    }
    _findResolvedRange("length}}");
  }

  void test_ngFor_star() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<li *ng-for='#item of items; #i = index'>
  {{i}} {{item.length}}
</li>
""");
    _resolveSingleTemplate(dartSource);
    {
      ResolvedRange resolvedRange = _findResolvedRange("item of");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'item', typeName: 'String');
      _assertHtmlElementAt(element, "item of");
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("i = index");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'i', typeName: 'int');
      _assertHtmlElementAt(element, "i = index");
    }
    {
      ResolvedRange resolvedRange =
          _findResolvedRange("of items", _isPropertyElement);
      expect(resolvedRange.range.length, 'of'.length);
      assertPropertyElement(resolvedRange.element,
          nameMatcher: 'ng-for-of', sourceMatcher: endsWith('ng_for.dart'));
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("items;");
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'items = [];');
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("i}}");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'i', typeName: 'int');
      _assertHtmlElementAt(element, "i = index");
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("item.");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'item', typeName: 'String');
      _assertHtmlElementAt(element, "item of");
    }
    _findResolvedRange("length}}");
  }

  void test_ngFor_templateAttribute() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<li template='ng-for #item of items; #i = index'>
  {{i}} {{item.length}}
</li>
""");
    _resolveSingleTemplate(dartSource);
    {
      ResolvedRange resolvedRange = _findResolvedRange("item of");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'item', typeName: 'String');
      _assertHtmlElementAt(element, "item of");
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("i = index");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'i', typeName: 'int');
      _assertHtmlElementAt(element, "i = index");
    }
    {
      ResolvedRange resolvedRange =
          _findResolvedRange("of items", _isPropertyElement);
      expect(resolvedRange.range.length, 'of'.length);
      assertPropertyElement(resolvedRange.element,
          nameMatcher: 'ng-for-of', sourceMatcher: endsWith('ng_for.dart'));
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("items;");
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'items = [];');
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("i}}");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'i', typeName: 'int');
      _assertHtmlElementAt(element, "i = index");
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("item.");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'item', typeName: 'String');
      _assertHtmlElementAt(element, "item of");
    }
    _findResolvedRange("length}}");
  }

  void test_ngFor_templateAttribute2() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<li template='ng-for: #item, of = items, #i=index'>
  {{i}} {{item.length}}
</li>
""");
    _resolveSingleTemplate(dartSource);
    {
      ResolvedRange resolvedRange = _findResolvedRange("item, of");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'item', typeName: 'String');
      _assertHtmlElementAt(element, "item, of");
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("i=index");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'i', typeName: 'int');
      _assertHtmlElementAt(element, "i=index");
    }
    {
      ResolvedRange resolvedRange =
          _findResolvedRange("of = items", _isPropertyElement);
      expect(resolvedRange.range.length, 'of'.length);
      assertPropertyElement(resolvedRange.element,
          nameMatcher: 'ng-for-of', sourceMatcher: endsWith('ng_for.dart'));
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("items,");
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'items = [];');
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("i}}");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'i', typeName: 'int');
      _assertHtmlElementAt(element, "i=index");
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("item.");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'item', typeName: 'String');
      _assertHtmlElementAt(element, "item, of");
    }
    _findResolvedRange("length}}");
  }

  void test_ngFor_templateElement() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [NgFor])
class TestPanel {
  List<String> items = [];
}
''');
    _addHtmlSource(r"""
<template ng-for #item [ng-for-of]='items' #i='index'>
  <li>{{i}} {{item.length}}</li>
</template>
""");
    _resolveSingleTemplate(dartSource);
    {
      ResolvedRange resolvedRange = _findResolvedRange("item [ng-for-of");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'item', typeName: 'String');
      _assertHtmlElementAt(element, "item [ng-for-of");
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("i='index'");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'i', typeName: 'int');
      _assertHtmlElementAt(element, "i='index'");
    }
    {
      ResolvedRange resolvedRange =
          _findResolvedRange("ng-for-of]", _isPropertyElement);
      assertPropertyElement(resolvedRange.element,
          nameMatcher: 'ng-for-of', sourceMatcher: endsWith('ng_for.dart'));
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("items'");
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'items = [];');
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("i}}");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'i', typeName: 'int');
      _assertHtmlElementAt(element, "i='index");
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("item.");
      LocalVariableElement element =
          assertLocalVariable(resolvedRange, name: 'item', typeName: 'String');
      _assertHtmlElementAt(element, "item [");
    }
    _findResolvedRange("length}}");
  }

  void test_ngIf_star() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [NgIf])
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<span *ng-if='text.length != 0'>
""");
    _resolveSingleTemplate(dartSource);
    {
      ResolvedRange resolvedRange =
          _findResolvedRange('ng-if=', _isPropertyElement);
      expect(resolvedRange.range.length, 'ng-if'.length);
      assertPropertyElement(resolvedRange.element,
          nameMatcher: 'ng-if', sourceMatcher: endsWith('ng_if.dart'));
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange('text.length');
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'text; // 1');
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange('length != 0');
      PropertyAccessorElement element = assertGetter(resolvedRange);
      expect(element.source.isInSystemLibrary, isTrue);
    }
  }

  void test_ngIf_templateAttribute() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [NgIf])
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<span template='ng-if text.length != 0'>
""");
    _resolveSingleTemplate(dartSource);
    {
      ResolvedRange resolvedRange =
          _findResolvedRange('ng-if text', _isPropertyElement);
      expect(resolvedRange.range.length, 'ng-if'.length);
      assertPropertyElement(resolvedRange.element,
          nameMatcher: 'ng-if', sourceMatcher: endsWith('ng_if.dart'));
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange('text.length');
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'text; // 1');
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange('length != 0');
      PropertyAccessorElement element = assertGetter(resolvedRange);
      expect(element.source.isInSystemLibrary, isTrue);
    }
  }

  void test_ngIf_templateElement() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html', directives: [NgIf])
class TestPanel {
  String text; // 1
}
''');
    _addHtmlSource(r"""
<template [ng-if]='text.length != 0'></template>
""");
    _resolveSingleTemplate(dartSource);
    {
      ResolvedRange resolvedRange =
          _findResolvedRange("ng-if]", _isSelectorName);
      expect(resolvedRange.range.length, 'ng-if'.length);
      SelectorName nameElement = resolvedRange.element;
      expect(nameElement.name, 'ng-if');
      expect(nameElement.source.fullName, endsWith('ng_if.dart'));
    }
    {
      ResolvedRange resolvedRange =
          _findResolvedRange("ng-if]", _isPropertyElement);
      expect(resolvedRange.range.length, 'ng-if'.length);
      PropertyElement propertyElement = resolvedRange.element;
      expect(propertyElement.name, 'ng-if');
      expect(propertyElement.source.fullName, endsWith('ng_if.dart'));
    }
    {
      ResolvedRange resolvedRange = _findResolvedRange("text.length");
      PropertyAccessorElement element = assertGetter(resolvedRange);
      _assertDartElementAt(element, 'text; // 1');
    }
    _findResolvedRange("length !=");
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

  void test_ngContent() {
    _addDartSource(r'''
@Component(selector: 'test-panel')
@View(templateUrl: 'test_panel.html')
class TestPanel {}
''');
    _addHtmlSource(r"""
<ng-content></ng-content>>
""");
    _resolveSingleTemplate(dartSource);
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

  void _assertDartAngularElementAt(AngularElement element, String search) {
    expect(element.nameOffset, dartCode.indexOf(search));
    expect(element.source, dartSource);
  }

  void _assertDartElementAt(Element element, String search) {
    expect(element.nameOffset, dartCode.indexOf(search));
    expect(element.source, dartSource);
  }

  void _assertHtmlElementAt(Element element, String search) {
    expect(element.nameOffset, htmlCode.indexOf(search));
    expect(element.source, htmlSource);
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

  static _isPropertyElement(ResolvedRange region) {
    return region.element is PropertyElement;
  }

  static _isSelectorName(ResolvedRange region) {
    return region.element is SelectorName;
  }
}
