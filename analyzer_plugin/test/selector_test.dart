library angular2.src.analysis.analyzer_plugin.src.selector_test;

import 'package:analyzer/src/generated/source.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/selector.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:typed_mock/typed_mock.dart';
import 'package:unittest/unittest.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(AndSelectorTest);
  defineReflectiveTests(AttributeSelectorTest);
  defineReflectiveTests(ClassSelectorTest);
  defineReflectiveTests(ElementNameSelectorTest);
  defineReflectiveTests(OrSelectorTest);
  defineReflectiveTests(SelectorParserTest);
}

@reflectiveTest
class AndSelectorTest extends _SelectorTest {
  Selector selector1 = new _SelectorMock('aaa');
  Selector selector2 = new _SelectorMock('bbb');
  Selector selector3 = new _SelectorMock('ccc');

  AndSelector selector;

  void setUp() {
    super.setUp();
    selector = new AndSelector(<Selector>[selector1, selector2, selector3]);
    when(selector1.match(anyObject)).thenReturn(true);
    when(selector2.match(anyObject)).thenReturn(true);
    when(selector3.match(anyObject)).thenReturn(true);
  }

  void test_match() {
    expect(selector.match(element), isTrue);
    verify(selector1.match(anyObject)).times(1);
    verify(selector1.match(anyObject)).times(1);
    verify(selector1.match(anyObject)).times(1);
  }

  void test_match_false1() {
    when(selector1.match(anyObject)).thenReturn(false);
    expect(selector.match(element), isFalse);
    verify(selector1.match(anyObject)).times(1);
    verify(selector2.match(anyObject)).times(0);
    verify(selector3.match(anyObject)).times(0);
  }

  void test_match_false2() {
    when(selector2.match(anyObject)).thenReturn(false);
    expect(selector.match(element), isFalse);
    verify(selector1.match(anyObject)).times(1);
    verify(selector2.match(anyObject)).times(1);
    verify(selector3.match(anyObject)).times(0);
  }

  void test_toString() {
    expect(selector.toString(), 'aaa && bbb && ccc');
  }
}

@reflectiveTest
class AttributeSelectorTest extends _SelectorTest {
  final AngularElement nameElement =
      new AngularElementImpl('kind', 10, 5, null);

  void test_match_notName() {
    AttributeSelector selector = new AttributeSelector(nameElement, null);
    when(element.attributes).thenReturn({'not-kind': 'no-matter'});
    expect(selector.match(element), isFalse);
  }

  void test_match_notValue() {
    AttributeSelector selector = new AttributeSelector(nameElement, 'silly');
    when(element.attributes).thenReturn({'kind': 'strange'});
    expect(selector.match(element), isFalse);
  }

  void test_match_noValue() {
    AttributeSelector selector = new AttributeSelector(nameElement, null);
    when(element.attributes).thenReturn({'kind': 'no-matter'});
    expect(selector.match(element), isTrue);
  }

  void test_toString_hasValue() {
    AttributeSelector selector = new AttributeSelector(nameElement, 'daffy');
    expect(selector.toString(), '[kind=daffy]');
  }

  void test_toString_noValue() {
    AttributeSelector selector = new AttributeSelector(nameElement, null);
    expect(selector.toString(), '[kind]');
  }
}

@reflectiveTest
class ClassSelectorTest extends _SelectorTest {
  final AngularElement nameElement =
      new AngularElementImpl('nice', 10, 5, null);
  ClassSelector selector;

  void setUp() {
    super.setUp();
    selector = new ClassSelector(nameElement);
  }

  void test_match_false_noClass() {
    when(element.attributes).thenReturn({'not-class': 'no-matter'});
    expect(selector.match(element), isFalse);
  }

  void test_match_false_noSuchClass() {
    when(element.attributes).thenReturn({'class': 'not-nice'});
    expect(selector.match(element), isFalse);
  }

  void test_match_true_first() {
    String classValue = 'nice some other';
    when(element.attributes).thenReturn({'class': classValue});
    expect(selector.match(element), isTrue);
  }

  void test_match_true_last() {
    String classValue = 'some other nice';
    when(element.attributes).thenReturn({'class': classValue});
    expect(selector.match(element), isTrue);
  }

  void test_match_true_middle() {
    String classValue = 'some nice other';
    when(element.attributes).thenReturn({'class': classValue});
    expect(selector.match(element), isTrue);
  }

  void test_toString() {
    expect(selector.toString(), '.nice');
  }
}

@reflectiveTest
class ElementNameSelectorTest extends _SelectorTest {
  ElementNameSelector selector;

  void setUp() {
    super.setUp();
    selector =
        new ElementNameSelector(new AngularElementImpl('panel', 10, 5, null));
  }

  void test_match() {
    when(element.localName).thenReturn('panel');
    expect(selector.match(element), isTrue);
  }

  void test_match_not() {
    when(element.localName).thenReturn('not-panel');
    expect(selector.match(element), isFalse);
  }

  void test_toString() {
    expect(selector.toString(), 'panel');
  }
}

@reflectiveTest
class OrSelectorTest extends _SelectorTest {
  Selector selector1 = new _SelectorMock('aaa');
  Selector selector2 = new _SelectorMock('bbb');
  Selector selector3 = new _SelectorMock('ccc');

  OrSelector selector;

  void setUp() {
    super.setUp();
    selector = new OrSelector(<Selector>[selector1, selector2, selector3]);
    when(selector1.match(anyObject)).thenReturn(false);
    when(selector2.match(anyObject)).thenReturn(false);
    when(selector3.match(anyObject)).thenReturn(false);
  }

  void test_match1() {
    when(selector1.match(anyObject)).thenReturn(true);
    expect(selector.match(element), isTrue);
    verify(selector1.match(anyObject)).times(1);
    verify(selector2.match(anyObject)).times(0);
    verify(selector3.match(anyObject)).times(0);
  }

  void test_match2() {
    when(selector2.match(anyObject)).thenReturn(true);
    expect(selector.match(element), isTrue);
    verify(selector1.match(anyObject)).times(1);
    verify(selector2.match(anyObject)).times(1);
    verify(selector3.match(anyObject)).times(0);
  }

  void test_match_false() {
    expect(selector.match(element), isFalse);
    verify(selector1.match(anyObject)).times(1);
    verify(selector2.match(anyObject)).times(1);
    verify(selector3.match(anyObject)).times(1);
  }

  void test_toString() {
    expect(selector.toString(), 'aaa || bbb || ccc');
  }
}

@reflectiveTest
class SelectorParserTest {
  final Source source = new _SourceMock();

  void test_and() {
    AndSelector selector = Selector.parse(source, 10, '[ng-for][ng-for-of]');
    expect(selector, new isInstanceOf<AndSelector>());
    expect(selector.selectors, hasLength(2));
    {
      AttributeSelector subSelector = selector.selectors[0];
      AngularElement nameElement = subSelector.nameElement;
      expect(nameElement.source, source);
      expect(nameElement.name, 'ng-for');
      expect(nameElement.nameOffset, 11);
      expect(nameElement.nameLength, 'ng-for'.length);
    }
    {
      AttributeSelector subSelector = selector.selectors[1];
      AngularElement nameElement = subSelector.nameElement;
      expect(nameElement.source, source);
      expect(nameElement.name, 'ng-for-of');
      expect(nameElement.nameOffset, 19);
      expect(nameElement.nameLength, 'ng-for-of'.length);
    }
  }

  void test_attribute_hasValue() {
    AttributeSelector selector = Selector.parse(source, 10, '[kind=pretty]');
    expect(selector, new isInstanceOf<AttributeSelector>());
    {
      AngularElement nameElement = selector.nameElement;
      expect(nameElement.source, source);
      expect(nameElement.name, 'kind');
      expect(nameElement.nameOffset, 11);
      expect(nameElement.nameLength, 'kind'.length);
    }
    expect(selector.value, 'pretty');
  }

  void test_attribute_noValue() {
    AttributeSelector selector = Selector.parse(source, 10, '[ng-for]');
    expect(selector, new isInstanceOf<AttributeSelector>());
    {
      AngularElement nameElement = selector.nameElement;
      expect(nameElement.source, source);
      expect(nameElement.name, 'ng-for');
      expect(nameElement.nameOffset, 11);
      expect(nameElement.nameLength, 'ng-for'.length);
    }
    expect(selector.value, isNull);
  }

  void test_bad() {
    Selector selector = Selector.parse(source, 0, '+name');
    expect(selector, isNull);
  }

  void test_class() {
    ClassSelector selector = Selector.parse(source, 10, '.nice');
    expect(selector, new isInstanceOf<ClassSelector>());
    AngularElement nameElement = selector.nameElement;
    expect(nameElement.source, source);
    expect(nameElement.name, 'nice');
    expect(nameElement.nameOffset, 11);
    expect(nameElement.nameLength, 'nice'.length);
  }

  void test_elementName() {
    ElementNameSelector selector = Selector.parse(source, 10, 'text-panel');
    expect(selector, new isInstanceOf<ElementNameSelector>());
    AngularElement nameElement = selector.nameElement;
    expect(nameElement.source, source);
    expect(nameElement.name, 'text-panel');
    expect(nameElement.nameOffset, 10);
    expect(nameElement.nameLength, 'text-panel'.length);
  }

  void test_or() {
    OrSelector selector = Selector.parse(source, 10, 'aaa,bbb');
    expect(selector, new isInstanceOf<OrSelector>());
    expect(selector.selectors, hasLength(2));
    {
      ElementNameSelector subSelector = selector.selectors[0];
      AngularElement nameElement = subSelector.nameElement;
      expect(nameElement.source, source);
      expect(nameElement.name, 'aaa');
      expect(nameElement.nameOffset, 10);
      expect(nameElement.nameLength, 'aaa'.length);
    }
    {
      ElementNameSelector subSelector = selector.selectors[1];
      AngularElement nameElement = subSelector.nameElement;
      expect(nameElement.source, source);
      expect(nameElement.name, 'bbb');
      expect(nameElement.nameOffset, 14);
      expect(nameElement.nameLength, 'bbb'.length);
    }
  }
}

class _ElementViewMock extends TypedMock implements ElementView {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SelectorMock extends TypedMock implements Selector {
  final String text;

  _SelectorMock(this.text);

  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  String toString() => text;
}

class _SelectorTest {
  ElementView element = new _ElementViewMock();

  void setUp() {}
}

class _SourceMock extends TypedMock implements Source {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
