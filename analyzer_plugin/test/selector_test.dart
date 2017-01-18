library angular2.src.analysis.analyzer_plugin.src.selector_test;

import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
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
  defineReflectiveTests(NotSelectorTest);
  defineReflectiveTests(AttributeValueRegexSelectorTest);
  defineReflectiveTests(SelectorParserTest);
  defineReflectiveTests(SuggestTagsTest);
  defineReflectiveTests(HtmlTagForSelectorTest);
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
    when(selector1.match(anyObject, anyObject)).thenReturn(true);
    when(selector2.match(anyObject, anyObject)).thenReturn(true);
    when(selector3.match(anyObject, anyObject)).thenReturn(true);
  }

  void test_match() {
    expect(selector.match(element, template), isTrue);
    verify(selector1.match(anyObject, anyObject)).times(2);
    verify(selector1.match(anyObject, anyObject)).times(2);
    verify(selector1.match(anyObject, anyObject)).times(2);
  }

  void test_match_false1() {
    when(selector1.match(anyObject, anyObject)).thenReturn(false);
    expect(selector.match(element, template), isFalse);
    verify(selector1.match(anyObject, anyObject)).times(1);
    verify(selector2.match(anyObject, anyObject)).times(0);
    verify(selector3.match(anyObject, anyObject)).times(0);
  }

  void test_match_false2() {
    when(selector2.match(anyObject, anyObject)).thenReturn(false);
    expect(selector.match(element, template), isFalse);
    verify(selector1.match(anyObject, anyObject)).times(1);
    verify(selector2.match(anyObject, anyObject)).times(1);
    verify(selector3.match(anyObject, anyObject)).times(0);
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
    AttributeSelector selector =
        new AttributeSelector(nameElement, null, false);
    when(element.attributes).thenReturn({'not-kind': 'no-matter'});
    expect(selector.match(element, template), isFalse);
  }

  void test_match_notValue() {
    AttributeSelector selector =
        new AttributeSelector(nameElement, 'silly', false);
    when(element.attributes).thenReturn({'kind': 'strange'});
    when(element.attributeNameSpans)
        .thenReturn({'kind': _newStringSpan(100, "kind")});
    expect(selector.match(element, template), isFalse);
  }

  void test_match_noValue() {
    AttributeSelector selector =
        new AttributeSelector(nameElement, null, false);
    when(element.attributes).thenReturn({'kind': 'no-matter'});
    when(element.attributeNameSpans)
        .thenReturn({'kind': _newStringSpan(100, "kind")});
    // verify
    expect(selector.match(element, template), isTrue);
    _assertRange(resolvedRanges[0], 100, 4, selector.nameElement);
  }

  void test_match_wildCard() {
    AttributeSelector selector = new AttributeSelector(nameElement, null, true);
    when(element.attributes).thenReturn({'kindatrue': 'no-matter'});
    when(element.attributeNameSpans)
        .thenReturn({'kindatrue': _newStringSpan(100, "kindatrue")});
    // verify
    expect(selector.match(element, template), isTrue);
    _assertRange(resolvedRanges[0], 100, 9, selector.nameElement);
  }

  void test_noMatch_wildCard() {
    AttributeSelector selector = new AttributeSelector(nameElement, null, true);
    when(element.attributes).thenReturn({'indatrue': 'no-matter'});
    when(element.attributeNameSpans)
        .thenReturn({'indatrue': _newStringSpan(100, "indatrue")});
    // verify
    expect(selector.match(element, template), isFalse);
  }

  void test_toString_hasValue() {
    AttributeSelector selector =
        new AttributeSelector(nameElement, 'daffy', false);
    expect(selector.toString(), '[kind=daffy]');
  }

  void test_toString_noValue() {
    AttributeSelector selector =
        new AttributeSelector(nameElement, null, false);
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
    expect(selector.match(element, template), isFalse);
  }

  void test_match_false_noSuchClass() {
    when(element.attributes).thenReturn({'class': 'not-nice'});
    expect(selector.match(element, template), isFalse);
  }

  void test_match_true_first() {
    String classValue = 'nice some other';
    when(element.attributes).thenReturn({'class': classValue});
    when(element.attributeValueSpans)
        .thenReturn({'class': _newStringSpan(100, classValue)});
    expect(selector.match(element, template), isTrue);
    expect(resolvedRanges, hasLength(1));
    _assertRange(resolvedRanges[0], 100, 4, selector.nameElement);
  }

  void test_match_true_last() {
    String classValue = 'some other nice';
    when(element.attributes).thenReturn({'class': classValue});
    when(element.attributeValueSpans)
        .thenReturn({'class': _newStringSpan(100, classValue)});
    expect(selector.match(element, template), isTrue);
    expect(resolvedRanges, hasLength(1));
    _assertRange(resolvedRanges[0], 111, 4, selector.nameElement);
  }

  void test_match_true_middle() {
    String classValue = 'some nice other';
    when(element.attributes).thenReturn({'class': classValue});
    when(element.attributeValueSpans)
        .thenReturn({'class': _newStringSpan(100, classValue)});
    expect(selector.match(element, template), isTrue);
    expect(resolvedRanges, hasLength(1));
    _assertRange(resolvedRanges[0], 105, 4, selector.nameElement);
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
    when(element.openingNameSpan).thenReturn(_newStringSpan(100, 'panel'));
    when(element.closingNameSpan).thenReturn(_newStringSpan(200, 'panel'));
    expect(selector.match(element, template), isTrue);
    _assertRange(resolvedRanges[0], 100, 5, selector.nameElement);
    _assertRange(resolvedRanges[1], 200, 5, selector.nameElement);
  }

  void test_match_not() {
    when(element.localName).thenReturn('not-panel');
    expect(selector.match(element, template), isFalse);
  }

  void test_toString() {
    expect(selector.toString(), 'panel');
  }
}

@reflectiveTest
class AttributeValueRegexSelectorTest extends _SelectorTest {
  AttributeValueRegexSelector selector = new AttributeValueRegexSelector("abc");

  void test_noMatch() {
    when(element.attributes).thenReturn({'kind': 'bcd'});
    expect(selector.match(element, template), isFalse);
  }

  void test_noMatch_any() {
    when(element.attributes)
        .thenReturn({'kind': 'bcd', 'plop': 'cde', 'klark': 'efg'});
    expect(selector.match(element, template), isFalse);
  }

  void test_match() {
    when(element.attributes).thenReturn({'kind': '0abcd'});
    expect(selector.match(element, template), isTrue);
  }

  void test_match_justOne() {
    when(element.attributes)
        .thenReturn({'kind': 'bcd', 'plop': 'zabcz', 'klark': 'efg'});
    expect(selector.match(element, template), isTrue);
  }
}

@reflectiveTest
class NotSelectorTest extends _SelectorTest {
  Selector condition = new _SelectorMock('aaa');

  NotSelector selector;

  void setUp() {
    super.setUp();
    selector = new NotSelector(condition);
  }

  void test_notFalse() {
    when(condition.match(anyObject, anyObject)).thenReturn(false);
    expect(selector.match(element, template), isTrue);
  }

  void test_notTrue() {
    when(condition.match(anyObject, anyObject)).thenReturn(true);
    expect(selector.match(element, template), isFalse);
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
    when(selector1.match(anyObject, anyObject)).thenReturn(false);
    when(selector2.match(anyObject, anyObject)).thenReturn(false);
    when(selector3.match(anyObject, anyObject)).thenReturn(false);
  }

  void test_match1() {
    when(selector1.match(anyObject, anyObject)).thenReturn(true);
    expect(selector.match(element, template), isTrue);
    verify(selector1.match(anyObject, anyObject)).times(1);
    verify(selector2.match(anyObject, anyObject)).times(0);
    verify(selector3.match(anyObject, anyObject)).times(0);
  }

  void test_match2() {
    when(selector2.match(anyObject, anyObject)).thenReturn(true);
    expect(selector.match(element, template), isTrue);
    verify(selector1.match(anyObject, anyObject)).times(1);
    verify(selector2.match(anyObject, anyObject)).times(1);
    verify(selector3.match(anyObject, anyObject)).times(0);
  }

  void test_match_false() {
    expect(selector.match(element, template), isFalse);
    verify(selector1.match(anyObject, anyObject)).times(1);
    verify(selector2.match(anyObject, anyObject)).times(1);
    verify(selector3.match(anyObject, anyObject)).times(1);
  }

  void test_toString() {
    expect(selector.toString(), 'aaa || bbb || ccc');
  }
}

@reflectiveTest
class SelectorParserTest {
  final Source source = new _SourceMock();

  void test_and() {
    AndSelector selector =
        new SelectorParser(source, 10, '[ng-for][ng-for-of]').parse();
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
    AttributeSelector selector =
        new SelectorParser(source, 10, '[kind=pretty]').parse();
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

  void test_attribute_hasWildcard() {
    AttributeSelector selector =
        new SelectorParser(source, 10, '[kind*=pretty]').parse();
    expect(selector, new isInstanceOf<AttributeSelector>());
    {
      AngularElement nameElement = selector.nameElement;
      expect(nameElement.source, source);
      expect(nameElement.name, 'kind');
      expect(nameElement.nameOffset, 11);
      expect(nameElement.nameLength, 'kind'.length);
    }
    expect(selector.value, 'pretty');
    expect(selector.isWildcard, true);
  }

  void test_attribute_textRegex() {
    AttributeValueRegexSelector selector =
        new SelectorParser(source, 10, '[*=/pretty/]').parse();
    expect(selector, new isInstanceOf<AttributeValueRegexSelector>());
    expect(selector.regexpStr, 'pretty');
  }

  void test_attribute_noValue() {
    AttributeSelector selector =
        new SelectorParser(source, 10, '[ng-for]').parse();
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
    try {
      new SelectorParser(source, 0, '+name').parse();
    } catch (e) {
      return;
    }
    fail("was supposed to throw");
  }

  void test_class() {
    ClassSelector selector = new SelectorParser(source, 10, '.nice').parse();
    expect(selector, new isInstanceOf<ClassSelector>());
    AngularElement nameElement = selector.nameElement;
    expect(nameElement.source, source);
    expect(nameElement.name, 'nice');
    expect(nameElement.nameOffset, 11);
    expect(nameElement.nameLength, 'nice'.length);
  }

  void test_elementName() {
    ElementNameSelector selector =
        new SelectorParser(source, 10, 'text-panel').parse();
    expect(selector, new isInstanceOf<ElementNameSelector>());
    AngularElement nameElement = selector.nameElement;
    expect(nameElement.source, source);
    expect(nameElement.name, 'text-panel');
    expect(nameElement.nameOffset, 10);
    expect(nameElement.nameLength, 'text-panel'.length);
  }

  void test_or() {
    OrSelector selector = new SelectorParser(source, 10, 'aaa,bbb').parse();
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

  void test_not() {
    NotSelector selector = new SelectorParser(source, 10, ':not(aaa)').parse();
    expect(selector, new isInstanceOf<NotSelector>());
    {
      ElementNameSelector condition = selector.condition;
      AngularElement nameElement = condition.nameElement;
      expect(nameElement.source, source);
      expect(nameElement.name, 'aaa');
      expect(nameElement.nameOffset, 15);
      expect(nameElement.nameLength, 'aaa'.length);
    }
  }

  void test_contains() {
    ContainsSelector selector =
        new SelectorParser(source, 10, ':contains(/aaa/)').parse();
    expect(selector, new isInstanceOf<ContainsSelector>());
    expect(selector.regex, 'aaa');
  }

  void test_complex_ast() {
    OrSelector selector = new SelectorParser(
            source, 10, 'aaa, bbb:not(ccc), :not(:not(ddd)[eee], fff[ggg])')
        .parse();

    expect(selector, new isInstanceOf<OrSelector>());
    expect(
        selector.toString(),
        equals("aaa || bbb && :not(ccc) || " +
            ":not(:not(ddd) && [eee] || fff && [ggg])"));
    {
      ElementNameSelector subSelector = selector.selectors[0];
      expect(subSelector, new isInstanceOf<ElementNameSelector>());
      expect(subSelector.toString(), "aaa");
    }
    {
      AndSelector subSelector = selector.selectors[1];
      expect(subSelector, new isInstanceOf<AndSelector>());
      expect(subSelector.toString(), "bbb && :not(ccc)");
      {
        ElementNameSelector subSelector2 = subSelector.selectors[0];
        expect(subSelector2, new isInstanceOf<ElementNameSelector>());
        expect(subSelector2.toString(), "bbb");
      }
      {
        NotSelector subSelector2 = subSelector.selectors[1];
        expect(subSelector2, new isInstanceOf<NotSelector>());
        expect(subSelector2.toString(), ":not(ccc)");
        {
          ElementNameSelector subSelector3 = subSelector2.condition;
          expect(subSelector3, new isInstanceOf<ElementNameSelector>());
          expect(subSelector3.toString(), "ccc");
        }
      }
    }
    {
      NotSelector subSelector = selector.selectors[2];
      expect(subSelector, new isInstanceOf<NotSelector>());
      expect(
          subSelector.toString(), ":not(:not(ddd) && [eee] || fff && [ggg])");
      {
        OrSelector subSelector2 = subSelector.condition;
        expect(subSelector2, new isInstanceOf<OrSelector>());
        expect(subSelector2.toString(), ":not(ddd) && [eee] || fff && [ggg]");
        {
          AndSelector subSelector3 = subSelector2.selectors[0];
          expect(subSelector3, new isInstanceOf<AndSelector>());
          expect(subSelector3.toString(), ":not(ddd) && [eee]");
          {
            NotSelector subSelector4 = subSelector3.selectors[0];
            expect(subSelector4, new isInstanceOf<NotSelector>());
            expect(subSelector4.toString(), ":not(ddd)");
            {
              ElementNameSelector subSelector5 = subSelector4.condition;
              expect(subSelector5, new isInstanceOf<ElementNameSelector>());
              expect(subSelector5.toString(), "ddd");
            }
          }
          {
            AttributeSelector subSelector4 = subSelector3.selectors[1];
            expect(subSelector4, new isInstanceOf<AttributeSelector>());
            expect(subSelector4.toString(), "[eee]");
          }
        }
        {
          AndSelector subSelector3 = subSelector2.selectors[1];
          expect(subSelector3, new isInstanceOf<AndSelector>());
          expect(subSelector3.toString(), "fff && [ggg]");
          {
            ElementNameSelector subSelector4 = subSelector3.selectors[0];
            expect(subSelector4, new isInstanceOf<ElementNameSelector>());
            expect(subSelector4.toString(), "fff");
          }
          {
            AttributeSelector subSelector4 = subSelector3.selectors[1];
            expect(subSelector4, new isInstanceOf<AttributeSelector>());
            expect(subSelector4.toString(), "[ggg]");
          }
        }
      }
    }
  }
}

@reflectiveTest
class SuggestTagsTest {
  void test_suggestNodeName() {
    Selector selector =
        new ElementNameSelector(new AngularElementImpl('panel', 10, 5, null));

    List<HtmlTagForSelector> suggestions = selector.suggestTags();
    expect(suggestions.length, 1);
    expect(suggestions.first.isValid, isTrue);
    expect(suggestions.first.toString(), equals("<panel"));
  }

  void test_suggestTagsFiltersInvalidResults() {
    Selector selector =
        new ClassSelector(new AngularElementImpl('class', 10, 5, null));
    expect(_evenInvalidSuggestions(selector), hasLength(1));
    expect(_evenInvalidSuggestions(selector).first.isValid, isFalse);
    expect(selector.suggestTags(), hasLength(0));
  }

  void test_suggestClass() {
    Selector selector =
        new ClassSelector(new AngularElementImpl('myclass', 10, 5, null));

    List<HtmlTagForSelector> suggestions = _evenInvalidSuggestions(selector);
    expect(suggestions.length, 1);
    expect(suggestions.first.isValid, isFalse);
    expect(suggestions.first.toString(), equals('<null class="myclass"'));
  }

  void test_suggestClasses() {
    Selector selector1 =
        new ClassSelector(new AngularElementImpl('class1', 10, 5, null));
    Selector selector2 =
        new ClassSelector(new AngularElementImpl('class2', 10, 5, null));

    List<HtmlTagForSelector> suggestions =
        selector2.refineTagSuggestions(_evenInvalidSuggestions(selector1));
    expect(suggestions.length, 1);
    expect(suggestions.first.isValid, isFalse);
    // check ClassSelector used tag.addClass(x), not tag.setAttr("class", x)
    expect(suggestions.first.toString(), equals('<null class="class1 class2"'));
  }

  void test_suggestPropertyNoValue() {
    Selector selector = new AttributeSelector(
        new AngularElementImpl('attr', 10, 5, null), null, false);

    List<HtmlTagForSelector> suggestions = _evenInvalidSuggestions(selector);
    expect(suggestions.length, 1);
    expect(suggestions.first.isValid, isFalse);
    expect(suggestions.first.toString(), equals("<null attr"));
  }

  void test_suggestPropertyWithValue() {
    Selector selector = new AttributeSelector(
        new AngularElementImpl('attr', 10, 5, null), "blah", false);

    List<HtmlTagForSelector> suggestions = _evenInvalidSuggestions(selector);
    expect(suggestions.length, 1);
    expect(suggestions.first.isValid, isFalse);
    expect(suggestions.first.toString(), equals('<null attr="blah"'));
  }

  void test_suggestWildcardProperty() {
    Selector selector = new AttributeSelector(
        new AngularElementImpl('attr', 10, 5, null), null, true);

    List<HtmlTagForSelector> suggestions = _evenInvalidSuggestions(selector);
    expect(suggestions.length, 1);
    expect(suggestions.first.isValid, isFalse);
    // [attr*] tells us they at LEAST want attr
    expect(suggestions.first.toString(), equals('<null attr'));
  }

  void test_suggestWildcardPropertyValue() {
    Selector selector = new AttributeSelector(
        new AngularElementImpl('attr', 10, 5, null), "value", true);

    List<HtmlTagForSelector> suggestions = _evenInvalidSuggestions(selector);
    expect(suggestions.length, 1);
    expect(suggestions.first.isValid, isFalse);
    // [attr*=x] tells us they at LEAST want attr=x
    expect(suggestions.first.toString(), equals('<null attr="value"'));
  }

  void test_suggestContainsIsInvalid() {
    Selector selector = new ContainsSelector("foo");

    List<HtmlTagForSelector> suggestions = _evenInvalidSuggestions(selector);
    expect(suggestions.length, 1);
    expect(suggestions.first.isValid, isFalse);
    // we could assert that it can't be made valid by adding a name,
    // but :contains is only allowed if it comprises the WHOLE selector (which
    // is admittedly not as well as the angular team coulddo and might change,
    // but :contains is so rare we can leave this).
  }

  void test_suggestRegexPropertyValueNoops() {
    Selector selector = new AttributeValueRegexSelector("foo");

    List<HtmlTagForSelector> suggestions = _evenInvalidSuggestions(selector);
    expect(suggestions.length, 1);
    expect(suggestions.first.isValid, isFalse);
    expect(suggestions.first.toString(),
        equals(new HtmlTagForSelector().toString()));
  }

  void test_suggestAndMergesSuggestionConstraints() {
    Selector nameSelector =
        new ElementNameSelector(new AngularElementImpl('panel', 10, 5, null));
    Selector attrSelector = new AttributeSelector(
        new AngularElementImpl('attr', 10, 5, null), "value", true);
    Selector selector = new AndSelector([nameSelector, attrSelector]);

    List<HtmlTagForSelector> suggestions = selector.suggestTags();
    expect(suggestions.length, 1);
    expect(suggestions.first.isValid, isTrue);
    expect(suggestions.first.toString(), equals('<panel attr="value"'));
  }

  void test_suggestOrMergesSuggestionConstraints() {
    Selector nameSelector =
        new ElementNameSelector(new AngularElementImpl('panel', 10, 5, null));
    Selector attrSelector = new AttributeSelector(
        new AngularElementImpl('attr', 10, 5, null), "value", true);
    Selector selector = new OrSelector([nameSelector, attrSelector]);

    List<HtmlTagForSelector> suggestions = _evenInvalidSuggestions(selector);
    expect(suggestions.length, 2);
    Map<String, HtmlTagForSelector> suggestionsMap =
        <String, HtmlTagForSelector>{};
    suggestions.forEach((s) => suggestionsMap[s.toString()] = s);
    expect(suggestionsMap["<panel"], isNotNull);
    expect(suggestionsMap["<panel"].isValid, isTrue);
    expect(suggestionsMap['<null attr="value"'], isNotNull);
    expect(suggestionsMap['<null attr="value"'].isValid, isFalse);
  }

  void test_suggestOrAnd() {
    Selector nameSelector1 =
        new ElementNameSelector(new AngularElementImpl('name1', 10, 5, null));
    Selector attrSelector1 = new AttributeSelector(
        new AngularElementImpl('attr1', 10, 5, null), "value", true);
    Selector andSelector1 = new AndSelector([nameSelector1, attrSelector1]);
    Selector nameSelector2 =
        new ElementNameSelector(new AngularElementImpl('name2', 10, 5, null));
    Selector attrSelector2 = new AttributeSelector(
        new AngularElementImpl('attr2', 10, 5, null), "value", true);
    Selector andSelector2 = new AndSelector([nameSelector2, attrSelector2]);
    Selector selector = new OrSelector([andSelector1, andSelector2]);

    List<HtmlTagForSelector> suggestions = selector.suggestTags();
    expect(suggestions.length, 2);
    Map<String, HtmlTagForSelector> suggestionsMap =
        <String, HtmlTagForSelector>{};
    suggestions.forEach((s) => suggestionsMap[s.toString()] = s);
    expect(suggestionsMap['<name1 attr1="value"'], isNotNull);
    expect(suggestionsMap['<name2 attr2="value"'], isNotNull);
  }

  void test_suggestAndOr() {
    Selector nameSelector1 =
        new ElementNameSelector(new AngularElementImpl('name1', 10, 5, null));
    Selector nameSelector2 =
        new ElementNameSelector(new AngularElementImpl('name2', 10, 5, null));
    Selector orSelector1 = new OrSelector([nameSelector1, nameSelector2]);

    Selector attrSelector1 = new AttributeSelector(
        new AngularElementImpl('attr1', 10, 5, null), "value", true);
    Selector attrSelector2 = new AttributeSelector(
        new AngularElementImpl('attr2', 10, 5, null), "value", true);
    Selector orSelector2 = new OrSelector([attrSelector1, attrSelector2]);

    Selector selector = new AndSelector([orSelector1, orSelector2]);

    List<HtmlTagForSelector> suggestions = selector.suggestTags();
    expect(suggestions.length, 4);
    Map<String, HtmlTagForSelector> suggestionsMap =
        <String, HtmlTagForSelector>{};
    suggestions.forEach((s) => suggestionsMap[s.toString()] = s);

    // basically (name1, name2)(attr1, attr2) though I'm not sure that's legal
    expect(suggestionsMap['<name1 attr1="value"'], isNotNull);
    expect(suggestionsMap['<name1 attr2="value"'], isNotNull);
    expect(suggestionsMap['<name2 attr1="value"'], isNotNull);
    expect(suggestionsMap['<name2 attr2="value"'], isNotNull);
  }

  void test_suggestOrOr() {
    Selector nameSelector1 =
        new ElementNameSelector(new AngularElementImpl('name1', 10, 5, null));
    Selector nameSelector2 =
        new ElementNameSelector(new AngularElementImpl('name2', 10, 5, null));
    Selector orSelector1 = new OrSelector([nameSelector1, nameSelector2]);

    Selector attrSelector1 = new AttributeSelector(
        new AngularElementImpl('attr1', 10, 5, null), "value", true);
    Selector attrSelector2 = new AttributeSelector(
        new AngularElementImpl('attr2', 10, 5, null), "value", true);
    Selector orSelector2 = new OrSelector([attrSelector1, attrSelector2]);

    Selector selector = new OrSelector([orSelector1, orSelector2]);

    List<HtmlTagForSelector> suggestions = _evenInvalidSuggestions(selector);
    expect(suggestions.length, 4);
    Map<String, HtmlTagForSelector> suggestionsMap =
        <String, HtmlTagForSelector>{};
    suggestions.forEach((s) => suggestionsMap[s.toString()] = s);

    // basically (name1, name2),(attr1, attr2) though I'm not sure that's legal
    expect(suggestionsMap['<name1'], isNotNull);
    expect(suggestionsMap['<null attr2="value"'], isNotNull);
    expect(suggestionsMap['<name2'], isNotNull);
    expect(suggestionsMap['<null attr2="value"'], isNotNull);
  }

  /**
   * [refineTagSuggestions] filters out invalid tags, but those are important
   * for us to test sometimes. This will do the same thing, but keep invalid
   * suggestions so we can inspect them.
   */
  List<HtmlTagForSelector> _evenInvalidSuggestions(Selector selector) {
    List<HtmlTagForSelector> tags = <HtmlTagForSelector>[
      new HtmlTagForSelector()
    ];
    return selector.refineTagSuggestions(tags);
  }
}

@reflectiveTest
class HtmlTagForSelectorTest {
  void test_noNameIsInvalid() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    expect(tag.isValid, isFalse);
  }

  void test_setName() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "myname";
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals("<myname"));
  }

  void test_setNameTwice() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "myname";
    tag.name = "myname";
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals("<myname"));
  }

  void test_setNameConflicting() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "myname1";
    tag.name = "myname2";
    expect(tag.isValid, isFalse);
  }

  void test_setAttributeNoValue() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.setAttribute("attr");
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals("<tagname attr"));
  }

  void test_setAttributeNoValueTwice() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.setAttribute("attr");
    tag.setAttribute("attr");
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals("<tagname attr"));
  }

  void test_setAttributeValue() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.setAttribute("attr", value: "value");
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals('<tagname attr="value"'));
  }

  void test_setAttributeValueTwice() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.setAttribute("attr", value: "value");
    tag.setAttribute("attr", value: "value");
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals('<tagname attr="value"'));
  }

  void test_setAttributeValueAfterJustAttr() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.setAttribute("attr");
    tag.setAttribute("attr", value: "value");
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals('<tagname attr="value"'));
  }

  void test_setAttributeNoValueAfterValue() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.setAttribute("attr", value: "value");
    tag.setAttribute("attr");
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals('<tagname attr="value"'));
  }

  void test_setAttributeConflictingValues() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.setAttribute("attr", value: "value1");
    tag.setAttribute("attr", value: "value2");
    expect(tag.isValid, isFalse);
  }

  void test_addClassOneClass() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.addClass("myclass");
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals('<tagname class="myclass"'));
  }

  void test_addClassTwoClasses() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.addClass("myclass");
    tag.addClass("myotherclass");
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals('<tagname class="myclass myotherclass"'));
  }

  void test_addClassMultipleTimesOKDoesntRepeat() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.addClass("myclass");
    tag.addClass("myclass");
    tag.addClass("myclass");
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals('<tagname class="myclass"'));
  }

  void test_classesAndClassAttrBindingInvalid() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.addClass("myclass");
    tag.setAttribute("class", value: "blah");
    expect(tag.isValid, isFalse);
  }

  void test_classesAndEmptyClassAttrBindingValid() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.addClass("myclass");
    tag.setAttribute("class");
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals('<tagname class="myclass"'));
  }

  void test_classesAndMatchingClassAttrBindingValid() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.addClass("myclass");
    tag.setAttribute("class", value: 'myclass');
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals('<tagname class="myclass"'));
  }

  void test_cloneKeepsName() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag = tag.clone();
    expect(tag.toString(), equals("<tagname"));
  }

  void test_cloneKeepsAttributes() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.setAttribute("attr1");
    tag.setAttribute("attr2");
    tag = tag.clone();
    expect(tag.toString(), equals("<tagname attr1 attr2"));
  }

  void test_cloneKeepsAttributeValues() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.setAttribute("attr1", value: 'value1');
    tag.setAttribute("attr2", value: 'value2');
    tag = tag.clone();
    expect(tag.toString(), equals('<tagname attr1="value1" attr2="value2"'));
  }

  void test_cloneKeepsClassnames() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.addClass("class1");
    tag.addClass("class2");
    tag = tag.clone();
    expect(tag.isValid, isTrue);
    expect(tag.toString(), equals('<tagname class="class1 class2"'));
  }

  void test_cloneKeepsValid() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.name = "break this tag";
    tag = tag.clone();
    expect(tag.isValid, isFalse);
  }

  void test_cloneWithoutNameCanBecomeValid() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag = tag.clone();
    tag.name = "tagname";
    expect(tag.isValid, isTrue);
  }

  void test_cloneIsAClone() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    HtmlTagForSelector clone = tag.clone();
    tag.name = "original";
    clone.name = "clone";
    expect(tag, isNot(equals(clone)));
    expect(tag.isValid, isTrue);
    expect(tag.toString(), "<original");
    expect(clone.isValid, isTrue);
    expect(clone.toString(), "<clone");
  }

  void test_cloneHasItsOwnProperties() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    HtmlTagForSelector clone = tag.clone();
    clone.setAttribute("attr");
    expect(tag.toString(), "<tagname");
    expect(clone.toString(), "<tagname attr");
  }

  void test_cloneHasItsOwnClasses() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    HtmlTagForSelector clone = tag.clone();
    clone.addClass("myclass");
    expect(tag.toString(), "<tagname");
    expect(clone.toString(), '<tagname class="myclass"');
  }

  void test_toStringIsAlphabeticalProperties() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.setAttribute("apple");
    tag.setAttribute("flick");
    tag.setAttribute("ziggy");
    tag.setAttribute("cow");
    tag.addClass("classes");
    expect(tag.toString(), '<tagname apple class="classes" cow flick ziggy');
  }

  void test_toStringIsAlphabeticalClasses() {
    HtmlTagForSelector tag = new HtmlTagForSelector();
    tag.name = "tagname";
    tag.addClass("apple");
    tag.addClass("flick");
    tag.addClass("ziggy");
    tag.addClass("cow");
    expect(tag.toString(), '<tagname class="apple cow flick ziggy"');
  }
}

class _ElementViewMock extends TypedMock implements ElementView {}

class _SelectorMock extends TypedMock implements Selector {
  final String text;

  _SelectorMock(this.text);

  @override
  String toString() => text;
}

class _SelectorTest {
  ElementView element = new _ElementViewMock();
  Template template = new _TemplateMock();

  List<ResolvedRange> resolvedRanges = <ResolvedRange>[];

  void setUp() {
    when(template.addRange(anyObject, anyObject))
        .thenInvoke((SourceRange range, AngularElement element) {
      resolvedRanges.add(new ResolvedRange(range, element));
    });
  }

  void _assertRange(ResolvedRange resolvedRange, int offset, int length,
      AngularElement element) {
    SourceRange range = resolvedRange.range;
    expect(range.offset, offset);
    expect(range.length, length);
    expect(resolvedRange.element, element);
  }

  SourceRange _newStringSpan(int offset, String value) =>
      new SourceRange(offset, value.length);
}

class _SourceMock extends TypedMock implements Source {}

class _TemplateMock extends TypedMock implements Template {}
