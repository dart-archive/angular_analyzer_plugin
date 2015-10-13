library angular2.src.analysis.analyzer_plugin.src.selector_test;

import 'package:analyzer/src/generated/source.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/selector.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:typed_mock/typed_mock.dart';
import 'package:unittest/unittest.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(SelectorParserTest);
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

class _SourceMock extends TypedMock implements Source {
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
