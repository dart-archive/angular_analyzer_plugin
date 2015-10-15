library angular2.src.analysis.analyzer_plugin.src.resolver;

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/src/generated/error_verifier.dart';
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

html.Element _firstElement(html.Node node) {
  for (html.Element child in node.children) {
    if (child is html.Element) {
      return child;
    }
  }
  return null;
}

/**
 * Information about an attribute that may be bound to a property.
 */
class AttributePropertyInfo {
  final String name;
  final int offset;
  final int length;

  AttributePropertyInfo(this.name, this.offset, this.length);

  @override
  String toString() => '($name, $offset, $length)';
}

/// [DartTemplateResolver]s resolve inline [View] templates.
class DartTemplateResolver {
  final TypeProvider typeProvider;
  final AnalysisErrorListener errorListener;
  final View view;

  DartTemplateResolver(this.typeProvider, this.errorListener, this.view);

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
    Template template = new Template(view, _firstElement(document));
    view.template = template;
    new TemplateResolver(typeProvider, errorListener).resolve(template);
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
    MethodElementImpl methodElement = new MethodElementImpl('angularVars', -1);
    (view.classElement as ElementImpl).encloseElement(methodElement);
    LocalVariableElementImpl localVariable =
        new LocalVariableElementImpl(name, -1);
    localVariable.type = type;
    methodElement.encloseElement(localVariable);
    nameScope.define(localVariable);
  }

  void _reportErrorForSpan(SourceSpan span, ErrorCode errorCode,
      [List<Object> arguments]) {
    errorListener.onError(new AnalysisError(
        view.source, span.start.offset, span.length, errorCode, arguments));
  }
}

/**
 * The [html.Element] implementation of [ElementView].
 */
class HtmlElementView implements ElementView {
  final html.Element element;

  @override
  final Map<String, String> attributes = <String, String>{};

  HtmlElementView(this.element) {
    element.attributes.forEach((key, String value) {
      if (key is String) {
        attributes[key] = value;
      }
    });
  }

  @override
  String get localName => element.localName;
}

/// [HtmlTemplateResolver]s resolve templates in separate Html files.
class HtmlTemplateResolver {
  final TypeProvider typeProvider;
  final AnalysisErrorListener errorListener;
  final View view;
  final html.Document document;

  HtmlTemplateResolver(
      this.typeProvider, this.errorListener, this.view, this.document);

  HtmlTemplate resolve() {
    HtmlTemplate template =
        new HtmlTemplate(view, _firstElement(document), view.templateSource);
    view.template = template;
    new TemplateResolver(typeProvider, errorListener).resolve(template);
    return template;
  }
}

/**
 * The implementation of [ElementView] for the short form of an inline template.
 *
 * The following template declares two attributes - `ng-for` and `ng-for-of`.
 *     <li template="ng-for #item of items; #i = index">...</li>
 */
class ShortTemplateElementView implements ElementView {
  @override
  String localName;

  @override
  final Map<String, String> attributes = <String, String>{};
}

/// [TemplateResolver]s resolve [Template]s.
class TemplateResolver {
  final TypeProvider typeProvider;
  final AnalysisErrorListener errorListener;

  Template template;
  View view;

  TemplateResolver(this.typeProvider, this.errorListener);

  void resolve(Template template) {
    this.template = template;
    this.view = template.view;
    _resolveNode(template.element);
  }

  void _addElementTagRanges(html.Element element, AngularElement nameElement) {
    String name = nameElement.name;
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
  }

  void _defineBuiltInVariable(Scope nameScope, DartType type, String name) {
    MethodElementImpl methodElement = new MethodElementImpl('angularVars', -1);
    (view.classElement as ElementImpl).encloseElement(methodElement);
    LocalVariableElementImpl localVariable =
        new LocalVariableElementImpl(name, -1);
    localVariable.type = type;
    methodElement.encloseElement(localVariable);
    nameScope.define(localVariable);
  }

  AttributePropertyInfo _getAttributeProperty(int offset, String name) {
    if (name.startsWith('[') && name.endsWith(']')) {
      offset += 1;
      name = name.substring(1, name.length - 1);
    } else if (name.startsWith('bind-')) {
      int bindLength = 'bind-'.length;
      offset += bindLength;
      name = name.substring(bindLength);
    } else if (name.startsWith('(') && name.endsWith(')')) {
      offset += 1;
      name = name.substring(1, name.length - 1);
    }
    int length = name.length;
    return new AttributePropertyInfo(name, offset, length);
  }

  /// Parse the given Dart [code] that starts at [offset].
  Expression _parseDartExpression(int offset, String code) {
    Token token = _scanDartCode(offset, code);
    return _parseDartExpressionAtToken(token);
  }

  /**
   * Parse the Dart expression starting at the given [token].
   */
  Expression _parseDartExpressionAtToken(Token token) {
    Parser parser = new Parser(view.source, errorListener);
    return parser.parseExpression(token);
  }

  /**
   * Record [ResolvedRange]s for the given [expression].
   */
  void _recordExpressionResolvedRanges(Expression expression) {
    if (expression != null) {
      expression.accept(new _DartReferencesRecorder(template));
    }
  }

  void _reportErrorForSpan(SourceSpan span, ErrorCode errorCode,
      [List<Object> arguments]) {
    errorListener.onError(new AnalysisError(
        view.source, span.start.offset, span.length, errorCode, arguments));
  }

  /// Resolve the given [node] attribute names to properties of [directive].
  void _resolveAttributeNames(html.Element node, AbstractDirective directive) {
    node.attributes.forEach((key, String value) {
      if (key is String) {
        int attrOffset = node.attributeSpans[key].start.offset;
        AttributePropertyInfo info = _getAttributeProperty(attrOffset, key);
        for (PropertyElement property in directive.properties) {
          if (info.name == property.name) {
            SourceRange range = new SourceRange(info.offset, info.length);
            template.addRange(range, property);
          }
        }
      }
    });
  }

  /// Resolve the given [node] attribute values.
  void _resolveAttributeValues(html.Element node) {
    node.attributes.forEach((key, String value) {
      if (key is String) {
        int valueOffset = node.attributeValueSpans[key].start.offset;
        if (key == 'template') {
          _resolveTemplateAttribute(valueOffset, value);
        } else if (key.startsWith('[') && key.endsWith(']') ||
            key.startsWith('(') && key.endsWith(')') ||
            key.startsWith('bind-') ||
            key.startsWith('on-')) {
          _resolveExpression(valueOffset, value);
        } else {
          _resolveTextExpressions(valueOffset, value);
        }
      }
    });
  }

  /**
   * Resolve the given [expression] and report errors.
   */
  void _resolveDartExpression(Expression expression) {
    ClassElement classElement = view.classElement;
    LibraryElement library = classElement.library;
    ResolverVisitor resolver =
        new ResolverVisitor(library, view.source, typeProvider, errorListener);
    // fill the name scope
    Scope nameScope = resolver.pushNameScope();
    classElement.methods.forEach(nameScope.define);
    classElement.accessors.forEach(nameScope.define);
    // TODO(scheglov) hack, use actual variables
    _defineBuiltInVariable(nameScope, typeProvider.dynamicType, r'$event');
    // do resolve
    expression.accept(resolver);
    // verify
    ErrorVerifier verifier = new ErrorVerifier(
        new ErrorReporter(errorListener, view.source),
        library,
        typeProvider,
        new InheritanceManager(library),
        false);
    expression.accept(verifier);
  }

  /// Resolve the Dart expression with the given [code] at [offset].
  Expression _resolveDartExpressionAt(int offset, String code) {
    Expression expression = _parseDartExpression(offset, code);
    if (expression != null) {
      _resolveDartExpression(expression);
    }
    return expression;
  }

  /// Resolve the given Angular [code] at the given [offset].
  /// Record [ResolvedRange]s.
  void _resolveExpression(int offset, String code) {
    Expression expression = _resolveDartExpressionAt(offset, code);
    _recordExpressionResolvedRanges(expression);
  }

  /// Resolve the given [node] in [template].
  void _resolveNode(html.Node node) {
    if (node is html.Element) {
      html.Element element = node;
      bool tagIsStandard = _isStandardTag(element);
      bool tagIsResolved = false;
      ElementView elementView = new HtmlElementView(element);
      for (AbstractDirective directive in view.directives) {
        Selector selector = directive.selector;
        if (selector.match(elementView)) {
          if (selector is ElementNameSelector) {
            _addElementTagRanges(element, selector.nameElement);
            tagIsResolved = true;
          }
          _resolveAttributeNames(node, directive);
        }
      }
      if (!tagIsStandard && !tagIsResolved) {
        _reportErrorForSpan(element.sourceSpan,
            AngularWarningCode.UNRESOLVED_TAG, [element.localName]);
      }
      _resolveAttributeValues(node);
    }
    if (node is html.Text) {
      int offset = node.sourceSpan.start.offset;
      String text = node.text;
      _resolveTextExpressions(offset, text);
    }
    node.nodes.forEach(_resolveNode);
  }

  /**
   * Resolve the given `template` attribute [code] at [offset].
   */
  void _resolveTemplateAttribute(int offset, String code) {
    // TODO(scheglov) add support for multiple keys, variables
    ShortTemplateElementView elementView = new ShortTemplateElementView();
    List<AttributePropertyInfo> infoList = <AttributePropertyInfo>[];
    Token token = _scanDartCode(offset, code);
    String key = null;
    while (token.type != TokenType.EOF) {
      // key
      if (key == null && token.type == TokenType.IDENTIFIER) {
        int keyOffset = token.offset;
        // scan for a full attribute name
        key = '';
        int lastEnd = token.offset;
        while (token.offset == lastEnd) {
          key += token.lexeme;
          lastEnd = token.end;
          token = token.next;
        }
        // register the attribute
        elementView.attributes[key] = 'some-value';
        // add the attribute to resolve to property
        infoList.add(new AttributePropertyInfo(key, keyOffset, key.length));
        continue;
      }
      // expression
      if (key != null) {
        Expression expression = _parseDartExpressionAtToken(token);
        _resolveDartExpression(expression);
        _recordExpressionResolvedRanges(expression);
        token = expression.endToken.next;
      }
    }
    // match directives
    for (AbstractDirective directive in view.directives) {
      if (directive.selector.match(elementView)) {
        for (PropertyElement property in directive.properties) {
          for (AttributePropertyInfo info in infoList) {
            if (info.name == property.name) {
              SourceRange range = new SourceRange(info.offset, info.length);
              template.addRange(range, property);
            }
          }
        }
        break;
      }
    }
  }

  /// Scan the given [text] staring at the given [offset] and resolve all of
  /// its embedded expressions.
  void _resolveTextExpressions(int offset, String text) {
    int lastEnd = 0;
    while (true) {
      // begin
      int begin = text.indexOf('{{', lastEnd);
      if (begin == -1) {
        break;
      }
      // end
      lastEnd = text.indexOf('}}', begin);
      if (lastEnd == -1) {
        errorListener.onError(new AnalysisError(view.source, offset + begin, 2,
            AngularWarningCode.UNTERMINATED_MUSTACHE));
        break;
      }
      // resolve
      begin += 2;
      String code = text.substring(begin, lastEnd);
      _resolveExpression(offset + begin, code);
    }
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
