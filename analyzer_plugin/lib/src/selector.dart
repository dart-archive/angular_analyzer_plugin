library angular2.src.analysis.analyzer_plugin.src.selector;

import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/strings.dart';

/**
 * The [Selector] that matches all of the given [selectors].
 */
class AndSelector implements Selector {
  final List<Selector> selectors;

  AndSelector(this.selectors);

  @override
  bool match(ElementView element, Template template) {
    for (Selector selector in selectors) {
      if (!selector.match(element, null)) {
        return false;
      }
    }
    for (Selector selector in selectors) {
      selector.match(element, template);
    }
    return true;
  }

  @override
  String toString() => selectors.join(' && ');
}

/**
 * The [Selector] that matches elements that have an attribute with the
 * given name, and (optionally) with the given value;
 */
class AttributeSelector implements Selector {
  final AngularElement nameElement;
  final bool isWildcard;
  final String value;

  AttributeSelector(this.nameElement, this.value, this.isWildcard);

  @override
  bool match(ElementView element, Template template) {
    String name = nameElement.name;
    SourceRange attributeSpan = null;
    String attributeValue = null;

    // standard case: exact match, use hash for fast lookup
    if (!isWildcard) {
      if (!element.attributes.containsKey(name)) {
        return false;
      }
      attributeSpan = element.attributeNameSpans[name];
      attributeValue = element.attributes[name];
    } else {
      // nonstandard case: wildcard, check if any start with specified name
      for (String attrName in element.attributes.keys) {
        if (attrName.startsWith(name)) {
          attributeSpan = element.attributeNameSpans[attrName];
          attributeValue = element.attributes[attrName];
          break;
        }
      }

      // no matching prop to wildcard
      if (attributeSpan == null) {
        return false;
      }
    }

    // match the actual value against the required
    if (value != null && attributeValue != value) {
      return false;
    }

    // OK
    if (template != null) {
      template.addRange(
          new SourceRange(attributeSpan.offset, attributeSpan.length),
          nameElement);
    }
    return true;
  }

  @override
  String toString() {
    String name = nameElement.name;
    if (value != null) {
      return '[$name=$value]';
    }
    return '[$name]';
  }
}

/**
 * The [Selector] that matches elements that have an attribute with any name,
 * and with contents that match the given regex.
 */
class AttributeValueRegexSelector implements Selector {
  final String regexpStr;
  final RegExp regexp;

  AttributeValueRegexSelector(this.regexpStr) : regexp = new RegExp(regexpStr);

  @override
  bool match(ElementView element, Template template) {
    for (String value in element.attributes.values) {
      if (regexp.hasMatch(value)) {
        return true;
      }
    }

    return false;
  }

  @override
  String toString() {
    return '[*=$regexpStr]';
  }
}

/**
 * The [Selector] that matches elements with the given (static) classes.
 */
class ClassSelector implements Selector {
  final AngularElement nameElement;

  ClassSelector(this.nameElement);

  @override
  bool match(ElementView element, Template template) {
    String name = nameElement.name;
    String val = element.attributes['class'];
    // no 'class' attribute
    if (val == null) {
      return false;
    }
    // no such class
    if (!val.split(' ').contains(name)) {
      return false;
    }
    // prepare index of "name" int the "class" attribute value
    int index;
    if (val == name || val.startsWith('$name ')) {
      index = 0;
    } else if (val.endsWith(' $name')) {
      index = val.length - name.length;
    } else {
      index = val.indexOf(' $name ') + 1;
    }
    // add resolved range
    int valueOffset = element.attributeValueSpans['class'].offset;
    int offset = valueOffset + index;
    template.addRange(new SourceRange(offset, name.length), nameElement);
    return true;
  }

  @override
  String toString() => '.' + nameElement.name;
}

/**
 * The element name based selector.
 */
class ElementNameSelector implements Selector {
  final AngularElement nameElement;

  ElementNameSelector(this.nameElement);

  @override
  bool match(ElementView element, Template template) {
    String name = nameElement.name;
    // match
    if (element.localName != name) {
      return false;
    }
    // done if no template
    if (template == null) {
      return true;
    }
    // record resolution
    if (element.openingNameSpan != null) {
      template.addRange(element.openingNameSpan, nameElement);
    }
    if (element.closingNameSpan != null) {
      template.addRange(element.closingNameSpan, nameElement);
    }
    return true;
  }

  @override
  String toString() => nameElement.name;
}

abstract class ElementView {
  Map<String, SourceRange> get attributeNameSpans;
  Map<String, String> get attributes;
  Map<String, SourceRange> get attributeValueSpans;
  SourceRange get closingNameSpan;
  SourceRange get closingSpan;
  String get localName;
  SourceRange get openingNameSpan;
  SourceRange get openingSpan;
}

/**
 * The [Selector] that matches one of the given [selectors].
 */
class OrSelector implements Selector {
  final List<Selector> selectors;

  OrSelector(this.selectors);

  @override
  bool match(ElementView element, Template template) {
    for (Selector selector in selectors) {
      if (selector.match(element, template)) {
        return true;
      }
    }
    return false;
  }

  @override
  String toString() => selectors.join(' || ');
}

/**
 * The [Selector] that confirms the inner [Selector] condition does NOT match
 */
class NotSelector implements Selector {
  final Selector condition;

  NotSelector(this.condition);

  @override
  bool match(ElementView element, Template template) {
    return !condition.match(element, template);
  }

  @override
  String toString() => ":not($condition)";
}

/**
 * The [Selector] that checks a TextNode for contents by a regex
 */
class ContainsSelector implements Selector {
  final String regex;

  ContainsSelector(this.regex);

  @override
  bool match(ElementView element, Template template) {
    // TODO check against actual text contents so we know which :contains
    // directives were used (for when we want to advise removal of unused
    // directives).
    //
    // We could also highlight the matching region in the text node with a color
    // so users know it was applied.
    //
    // Not sure what else we could do.
    //
    // Never matches elements. Only matches [TextNode]s. Return false for now.
    return false;
  }

  @override
  String toString() => ":contains($regex)";
}

/**
 * The base class for all Angular selectors.
 */
abstract class Selector {
  /**
   * Check whether the given [element] matches this selector.
   * If yes, then record resolved ranges into [template].
   */
  bool match(ElementView element, Template template);
}

enum _SelectorRegexMatch {
  NotStart,
  NotEnd,
  Attribute,
  Tag,
  Comma,
  Class,
  Contains
}

class SelectorParseError extends FormatException {
  int length;
  SelectorParseError(String message, String source, int offset, this.length)
      : super(message, source, offset);
}

class SelectorParser {
  Match currentMatch;
  Iterator<Match> matches;
  int lastOffset = 0;
  final int fileOffset;
  final String str;
  String currentMatchStr;
  _SelectorRegexMatch currentMatchType;
  final Source source;
  SelectorParser(this.source, this.fileOffset, this.str);

  final RegExp _regExp = new RegExp(r'(\:not\()|' +
      r'([-\w]+)|' +
      r'(?:\.([-\w]+))|' +
      r'(?:\[([-\w*]+)(?:=([^\]]*))?\])|' +
      r'(\))|' +
      r'(\s*,\s*)|' +
      r'(^\:contains\(\/(.+)\/\)$)'); // :contains doesn't mix with the rest

  static const Map<int, _SelectorRegexMatch> matchIndexToType =
      const <int, _SelectorRegexMatch>{
    1: _SelectorRegexMatch.NotStart,
    2: _SelectorRegexMatch.Tag,
    3: _SelectorRegexMatch.Class,
    4: _SelectorRegexMatch.Attribute,
    // 5 is part of Attribute. Not a match type
    6: _SelectorRegexMatch.NotEnd,
    7: _SelectorRegexMatch.Comma,
    8: _SelectorRegexMatch.Contains,
  };

  Match advance() {
    if (!matches.moveNext()) {
      currentMatch = null;
      return null;
    }

    currentMatch = matches.current;
    // no content should be skipped
    {
      String skipStr = str.substring(lastOffset, currentMatch.start);
      if (!isBlank(skipStr)) {
        _unexpected(skipStr, lastOffset + fileOffset);
      }
      lastOffset = currentMatch.end;
    }

    for (int index in matchIndexToType.keys) {
      if (currentMatch[index] != null) {
        currentMatchType = matchIndexToType[index];
        currentMatchStr = currentMatch[index];
        return currentMatch;
      }
    }

    currentMatchType = null;
    currentMatchStr = null;
    return null;
  }

  Selector parse() {
    if (str == null) {
      return null;
    }
    matches = _regExp.allMatches(str).iterator;
    advance();
    Selector selector = parseNested();
    if (currentMatch != null) {
      _unexpected(
          currentMatchStr, fileOffset + (currentMatch?.start ?? lastOffset));
    }
    return selector;
  }

  Selector parseNested() {
    List<Selector> selectors = <Selector>[];
    while (currentMatch != null) {
      if (currentMatchType == _SelectorRegexMatch.NotEnd) {
        // don't advance, just know we're at the end of this And
        break;
      }

      if (currentMatchType == _SelectorRegexMatch.NotStart) {
        selectors.add(parseNotSelector());
      } else if (currentMatchType == _SelectorRegexMatch.Tag) {
        int nameOffset = fileOffset + currentMatch.start;
        String name = currentMatchStr;
        selectors.add(new ElementNameSelector(
            new SelectorName(name, nameOffset, name.length, source)));
        advance();
      } else if (currentMatchType == _SelectorRegexMatch.Class) {
        int nameOffset = fileOffset + currentMatch.start + 1;
        String name = currentMatchStr;
        selectors.add(new ClassSelector(
            new SelectorName(name, nameOffset, name.length, source)));
        advance();
      } else if (currentMatchType == _SelectorRegexMatch.Attribute) {
        int nameIndex = currentMatch.start + '['.length;
        String name = currentMatch[4];
        int nameOffset = fileOffset + nameIndex;
        bool isWildcard = false;
        String value = currentMatch[5];
        advance();

        if (name == '*' &&
            value != null &&
            value.startsWith('/') &&
            value.endsWith('/')) {
          selectors.add(new AttributeValueRegexSelector(
              value.substring(1, value.length - 1)));
          continue;
        } else if (name.endsWith('*')) {
          isWildcard = true;
          name = name.replaceAll('*', '');
        }

        selectors.add(new AttributeSelector(
            new SelectorName(name, nameOffset, name.length, source),
            value,
            isWildcard));
      } else if (currentMatchType == _SelectorRegexMatch.Comma) {
        advance();
        Selector rhs = parseNested();
        if (rhs is OrSelector) {
          // flatten "a, b, c, d" from (a, (b, (c, d))) into (a, b, c, d)
          return new OrSelector(
              <Selector>[_andSelectors(selectors)]..addAll(rhs.selectors));
        } else {
          return new OrSelector(<Selector>[_andSelectors(selectors), rhs]);
        }
      } else if (currentMatchType == _SelectorRegexMatch.Contains) {
        selectors.add(new ContainsSelector(currentMatch[9]));
        advance();
      } else {
        break;
      }
    }
    // final result
    return _andSelectors(selectors);
  }

  NotSelector parseNotSelector() {
    advance();
    Selector condition = parseNested();
    if (currentMatchType != _SelectorRegexMatch.NotEnd) {
      _unexpected(
          currentMatchStr, fileOffset + (currentMatch?.start ?? lastOffset));
    }
    advance();
    return new NotSelector(condition);
  }

  void _unexpected(String eString, int eOffset) {
    throw new SelectorParseError(
        "Unexpected $eString", str, eOffset, eString.length);
  }

  Selector _andSelectors(List<Selector> selectors) {
    if (selectors.length == 1) {
      return selectors[0];
    }
    return new AndSelector(selectors);
  }
}

/**
 * A name that is a part of a [Selector].
 */
class SelectorName extends AngularElementImpl {
  SelectorName(String name, int nameOffset, int nameLength, Source source)
      : super(name, nameOffset, nameLength, source);
}
