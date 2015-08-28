library angular2.src.analysis.analyzer_plugin.src.selector;

import 'package:analyzer/src/generated/source.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:html/dom.dart' as html;
import 'package:source_span/source_span.dart';

/// The element name based selector.
class ElementNameSelector implements Selector {
  final AngularElement nameElement;

  ElementNameSelector(this.nameElement);

  Iterable<AngularElement> get elements => <AngularElement>[nameElement];

  bool match(html.Element element, Template template) {
    String name = nameElement.name;
    if (element.localName == name) {
      {
        SourceSpan span = element.sourceSpan;
        int offset = span.start.offset + '<'.length;
        SourceRange range = new SourceRange(offset, name.length);
        template.addRange(range, nameElement);
      }
      {
        SourceSpan span = element.endSourceSpan;
        if (span != null) {
          int offset = span.start.offset + '</'.length;
          SourceRange range = new SourceRange(offset, name.length);
          template.addRange(range, nameElement);
        }
      }
      return true;
    }
    return false;
  }

  @override
  String toString() => nameElement.name;
}

/// The base class for all Angular selectors.
abstract class Selector {
  static final RegExp _elementNameRegExp = new RegExp(r'([-\w]+)$');

  /// The [AngularElement]s declared by this [Selector].
  Iterable<AngularElement> get elements;

  /// Check whether the given [element] matches this selector.
  /// If yes, then record resolved ranges into [template].
  bool match(html.Element element, Template template);

  static Selector parse(Source source, int offset, String str) {
    if (str == null) return null;
    if (_elementNameRegExp.matchAsPrefix(str) != null) {
      return new ElementNameSelector(
          new AngularElementImpl(str, offset, source));
    }
    return null;
  }
}
