library angular2.src.analysis.analyzer_plugin.src.resolver;

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/scanner.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular2_analyzer_plugin/src/model.dart';
import 'package:angular2_analyzer_plugin/src/selector.dart';
import 'package:angular2_analyzer_plugin/tasks.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;
import 'package:source_span/source_span.dart';

/// [DartTemplateResolver]s resolve inline [View] templates.
class DartTemplateResolver {
  final TypeProvider typeProvider;
  final View view;
  final AnalysisErrorListener errorListener;

  Template template;

  DartTemplateResolver(this.typeProvider, this.view, this.errorListener);

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

  void _defineBuiltInVariable(Scope nameScope, DartType type, String name) {
    ClassElement classElement = view.classElement;
    LocalVariableElementImpl localVariable =
        new LocalVariableElementImpl(name, -1);
    localVariable.type = typeProvider.dynamicType;
    (classElement as ElementImpl).encloseElement(localVariable);
    nameScope.define(localVariable);
  }

  /// Resolve the given Dart [code] that starts at [offset].
  Expression _parseDartExpression(int offset, String code) {
    Token token = _scanDartCode(offset, code);
    Parser parser = new Parser(view.source, errorListener);
    return parser.parseExpression(token);
  }

  void _reportErrorForSpan(SourceSpan span, ErrorCode errorCode,
      [List<Object> arguments]) {
    errorListener.onError(new AnalysisError(
        view.source, span.start.offset, span.length, errorCode, arguments));
  }

  /// Resolve the given [node] attributes to properties of [directive].
  void _resolveAttributes(html.Element node, AbstractDirective directive) {
    node.attributes.forEach((key, String value) {
      if (key is String) {
        String propertyName = key;
        int rangeOffset = node.attributeSpans[key].start.offset;
        if (propertyName.startsWith('[') && propertyName.endsWith(']')) {
          rangeOffset += 1;
          propertyName = propertyName.substring(1, propertyName.length - 1);
        } else if (propertyName.startsWith('(') && propertyName.endsWith(')')) {
          rangeOffset += 1;
          propertyName = propertyName.substring(1, propertyName.length - 1);
        }
        for (PropertyElement property in directive.properties) {
          if (propertyName == property.name) {
            int rangeLength = property.name.length;
            SourceRange range = new SourceRange(rangeOffset, rangeLength);
            template.addRange(range, property);
            break;
          }
        }
      }
    });
  }

  /// Resolve the given [node] attribute values.
  void _resolveAttributeValues(html.Element node) {
    node.attributes.forEach((key, String value) {
      if (key is String) {
        if (key.startsWith('[') && key.endsWith(']') ||
            key.startsWith('(') && key.endsWith(')')) {
          int valueOffset = node.attributeValueSpans[key].start.offset;
          _resolveExpression(valueOffset, value);
        }
      }
    });
  }

  /// Resolve the Dart expression with the given [code] at [offset].
  Expression _resolveDartExpression(int offset, String code) {
    Expression expression = _parseDartExpression(offset, code);
    if (expression != null) {
      ClassElement classElement = view.classElement;
      ResolverVisitor resolver = new ResolverVisitor(
          classElement.library, view.source, typeProvider, errorListener);
      // fill the name scope
      Scope nameScope = resolver.pushNameScope();
      classElement.methods.forEach(nameScope.define);
      classElement.accessors.forEach(nameScope.define);
      _defineBuiltInVariable(nameScope, typeProvider.dynamicType, r'$event');
      // do resolve
      expression.accept(resolver);
    }
    return expression;
  }

  /// Resolve the given Angular [code] at the given [offset].
  /// Currently implemented as resolving as Dart code.
  void _resolveExpression(int offset, String code) {
    Expression expression = _resolveDartExpression(offset, code);
    if (expression != null) {
      expression.accept(new _DartReferencesRecorder(template));
    }
  }

  /// Resolve the given [node] in [template].
  void _resolveNode(html.Node node) {
    if (node is html.Element) {
      html.Element element = node;
      bool tagIsStandard = _isStandardTag(element);
      bool tagIsResolved = false;
      for (AbstractDirective directive in view.directives) {
        Selector selector = directive.selector;
        if (selector.match(element, template)) {
          if (selector is ElementNameSelector) {
            tagIsResolved = true;
          }
          _resolveAttributes(node, directive);
        }
      }
      if (!tagIsStandard && !tagIsResolved) {
        _reportErrorForSpan(element.sourceSpan,
            AngularWarningCode.UNRESOLVED_TAG, [element.localName]);
      }
      _resolveAttributeValues(node);
    }
    node.nodes.forEach(_resolveNode);
  }

  /// Scan the given Dart [code] that starts at [offset].
  Token _scanDartCode(int offset, String code) {
    String text = ' ' * offset + code;
    CharSequenceReader reader = new CharSequenceReader(text);
    Scanner scanner = new Scanner(view.source, reader, errorListener);
    return scanner.tokenize();
  }

  /// Check whether the given [element] is a standard HTML5 tag.
  static bool _isStandardTag(html.Element element) {
    return !element.localName.contains('-');
  }
}

/// An [AstVisitor] that records references to Dart [Element]s into
/// the given [template].
class _DartReferencesRecorder extends RecursiveAstVisitor {
  final Template template;

  _DartReferencesRecorder(this.template);

  @override
  visitSimpleIdentifier(SimpleIdentifier node) {
    Element element = node.bestElement;
    if (element != null) {
      SourceRange range = new SourceRange(node.offset, node.length);
      template.addRange(range, new DartElement(element));
    }
  }
}
