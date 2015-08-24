library angular2.src.analysis.analyzer_plugin.src.resolver;

import 'package:analyzer/src/generated/error.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/selector.dart';
import 'package:angular2_analyzer_plugin/tasks.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;
import 'package:source_span/source_span.dart';

/// [DartTemplateResolver]s resolve inline [View] templates.
class DartTemplateResolver {
  final View view;
  final AnalysisErrorListener errorListener;

  Template template;

  DartTemplateResolver(this.view, this.errorListener);

  Template resolve() {
    String templateText = view.templateText;
    if (templateText == null) {
      return null;
    }
    // Parse HTML.
    html.DocumentFragment document;
    {
      String fragmentText = ' ' * view.templateOffset + templateText;
      html.HtmlParser parser =
          new html.HtmlParser(fragmentText, generateSpans: true);
      parser.compatMode = 'quirks';
      document = parser.parseFragment('template');
      _addParseErrors(parser);
    }
    // Create and resolve Template.
    template = new Template(view, document);
    view.template = template;
    _resolveNode(document);
    return template;
  }

  /// Report HTML errors as [AnalysisError]s.
  void _addParseErrors(html.HtmlParser parser) {
    List<html.ParseError> parseErrors = parser.errors;
    for (html.ParseError parseError in parseErrors) {
      SourceSpan span = parseError.span;
      _reportErrorForSpan(
          span, HtmlErrorCode.PARSE_ERROR, [parseError.message]);
    }
  }

  void _reportErrorForSpan(SourceSpan span, ErrorCode errorCode,
      [List<Object> arguments]) {
    errorListener.onError(new AnalysisError(
        view.source, span.start.offset, span.length, errorCode, arguments));
  }

  /// Resolve the given [node] in [template].
  void _resolveNode(html.Node node) {
    if (node is html.Element) {
      html.Element element = node;
      bool tagIsStandard = _isStandardTag(element);
      bool tagIsResolved = false;
      for (AbstractDirective directive in view.directives) {
        Selector selector = directive.selector;
        bool match = selector.match(element, template);
        if (match && selector is ElementNameSelector) {
          tagIsResolved = true;
        }
      }
      if (!tagIsStandard && !tagIsResolved) {
        _reportErrorForSpan(element.sourceSpan,
            AngularWarningCode.UNRESOLVED_TAG, [element.localName]);
      }
    }
    node.nodes.forEach(_resolveNode);
  }

  /// Check whether the given [element] is a standard HTML5 tag.
  static bool _isStandardTag(html.Element element) {
    return !element.localName.contains('-');
  }
}
