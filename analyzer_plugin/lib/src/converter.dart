import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/ast/token.dart' hide SimpleToken;
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/ng_expr_parser.dart';
import 'package:angular_analyzer_plugin/src/ignoring_error_listener.dart';
import 'package:angular_analyzer_plugin/src/angular_html_parser.dart';
import 'package:angular_analyzer_plugin/src/strings.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;
import 'package:meta/meta.dart';
import 'package:tuple/tuple.dart';
import 'package:source_span/source_span.dart';

html.Element firstElement(html.Node node) {
  for (final child in node.children) {
    if (child is html.Element) {
      return child;
    }
  }
  return null;
}

class HtmlTreeConverter {
  final EmbeddedDartParser dartParser;
  final Source templateSource;
  final AnalysisErrorListener errorListener;

  HtmlTreeConverter(this.dartParser, this.templateSource, this.errorListener);

  NodeInfo convert(html.Node node, {ElementInfo parent}) {
    if (node is html.Element) {
      final localName = node.localName;
      final attributes = _convertAttributes(node);
      final isTemplate = localName == 'template';
      final openingSpan = _toSourceRange(node.sourceSpan);
      final closingSpan = _toSourceRange(node.endSourceSpan);
      final openingNameSpan = openingSpan != null
          ? new SourceRange(openingSpan.offset + '<'.length, localName.length)
          : null;
      final closingNameSpan = closingSpan != null
          ? new SourceRange(closingSpan.offset + '</'.length, localName.length)
          : null;
      final element = new ElementInfo(
          localName,
          openingSpan,
          closingSpan,
          openingNameSpan,
          closingNameSpan,
          attributes,
          findTemplateAttribute(attributes),
          parent,
          isTemplate: isTemplate);

      for (final attribute in attributes) {
        attribute.parent = element;
      }

      final children = _convertChildren(node, element);
      element.childNodes.addAll(children);

      if (!element.isSynthetic &&
          element.openingSpanIsClosed &&
          closingSpan != null &&
          (openingSpan.offset + openingSpan.length) == closingSpan.offset) {
        element.childNodes.add(new TextInfo(
            openingSpan.offset + openingSpan.length, '', element, [],
            synthetic: true));
      }

      return element;
    }
    if (node is html.Text) {
      final offset = node.sourceSpan.start.offset;
      final text = node.text;
      return new TextInfo(
          offset, text, parent, dartParser.findMustaches(text, offset));
    }
    return null;
  }

  List<AttributeInfo> _convertAttributes(html.Element element) {
    final attributes = <AttributeInfo>[];
    element.attributes.forEach((name, value) {
      if (name is String) {
        try {
          if (name == "") {
            attributes.add(_convertSyntheticAttribute(element));
          } else if (name.startsWith('*')) {
            attributes.add(_convertTemplateAttribute(element, name, true));
          } else if (name == 'template') {
            attributes.add(_convertTemplateAttribute(element, name, false));
          } else if (name.startsWith('[(')) {
            attributes.add(_convertExpressionBoundAttribute(
                element, name, "[(", ")]", ExpressionBoundType.twoWay));
          } else if (name.startsWith('[class.')) {
            attributes.add(_convertExpressionBoundAttribute(
                element, name, "[class.", "]", ExpressionBoundType.clazz));
          } else if (name.startsWith('[attr.')) {
            attributes.add(_convertExpressionBoundAttribute(
                element, name, "[attr.", "]", ExpressionBoundType.attr));
          } else if (name.startsWith('[style.')) {
            attributes.add(_convertExpressionBoundAttribute(
                element, name, "[style.", "]", ExpressionBoundType.style));
          } else if (name.startsWith('[')) {
            attributes.add(_convertExpressionBoundAttribute(
                element, name, "[", "]", ExpressionBoundType.input));
          } else if (name.startsWith('bind-')) {
            attributes.add(_convertExpressionBoundAttribute(
                element, name, "bind-", null, ExpressionBoundType.input));
          } else if (name.startsWith('on-')) {
            attributes.add(
                _convertStatementsBoundAttribute(element, name, "on-", null));
          } else if (name.startsWith('(')) {
            attributes
                .add(_convertStatementsBoundAttribute(element, name, "(", ")"));
          } else {
            final valueOffset = _valueOffset(element, name);
            if (valueOffset == null) {
              value = null;
            }

            attributes.add(new TextAttribute(
                name,
                _nameOffset(element, name),
                value,
                valueOffset,
                dartParser.findMustaches(value, valueOffset)));
          }
        } on IgnorableHtmlInternalException {
          // See https://github.com/dart-lang/html/issues/44, this error will
          // be thrown looking for nameOffset. Catch it so that analysis else
          // where continues.
          return;
        }
      }
    });
    return attributes;
  }

  TextAttribute _convertSyntheticAttribute(html.Element element) {
    final openSourceSpan = element.sourceSpan;
    final nameOffset = openSourceSpan.start.offset + openSourceSpan.length;
    final textAttribute = new TextAttribute("", nameOffset, null, null, []);
    return textAttribute;
  }

  TemplateAttribute _convertTemplateAttribute(
      html.Element element, String origName, bool starSugar) {
    final origNameOffset = _nameOffset(element, origName);
    final valueOffset = _valueOffset(element, origName);
    final value = valueOffset == null ? null : element.attributes[origName];

    String name;
    String prefix;
    int nameOffset;
    var virtualAttributes = <AttributeInfo>[];

    if (starSugar) {
      nameOffset = origNameOffset + '*'.length;
      name = _removePrefixSuffix(origName, '*', null);
      // ignore: prefer_interpolation_to_compose_strings
      final desugaredValue = name + (' ' * '="'.length) + (value ?? '');
      final tuple =
          dartParser.parseTemplateVirtualAttributes(nameOffset, desugaredValue);
      virtualAttributes = tuple.item2;
      prefix = tuple.item1;
    } else {
      name = origName;
      nameOffset = origNameOffset;
      if (value == null || value.isEmpty) {
        errorListener.onError(new AnalysisError(templateSource, origNameOffset,
            origName.length, AngularWarningCode.EMPTY_BINDING, [origName]));
      } else {
        virtualAttributes =
            dartParser.parseTemplateVirtualAttributes(valueOffset, value).item2;
      }
    }

    final templateAttribute = new TemplateAttribute(name, nameOffset, value,
        valueOffset, origName, origNameOffset, virtualAttributes,
        prefix: prefix);

    for (final virtualAttribute in virtualAttributes) {
      virtualAttribute.parent = templateAttribute;
    }

    return templateAttribute;
  }

  StatementsBoundAttribute _convertStatementsBoundAttribute(
      html.Element element, String origName, String prefix, String suffix) {
    final origNameOffset = _nameOffset(element, origName);
    final valueOffset = _valueOffset(element, origName);
    final value = valueOffset == null ? null : element.attributes[origName];
    if (value == null) {
      errorListener.onError(new AnalysisError(templateSource, origNameOffset,
          origName.length, AngularWarningCode.EMPTY_BINDING, [origName]));
    }
    final propNameOffset = origNameOffset + prefix.length;
    final propName = _removePrefixSuffix(origName, prefix, suffix);
    return new StatementsBoundAttribute(
        propName,
        propNameOffset,
        value,
        valueOffset,
        origName,
        origNameOffset,
        dartParser.parseDartStatements(valueOffset, value));
  }

  ExpressionBoundAttribute _convertExpressionBoundAttribute(
      html.Element element,
      String origName,
      String prefix,
      String suffix,
      ExpressionBoundType bound) {
    final origNameOffset = _nameOffset(element, origName);
    final valueOffset = _valueOffset(element, origName);
    final value = valueOffset == null ? null : element.attributes[origName];
    if (value == null || value == "") {
      errorListener.onError(new AnalysisError(templateSource, origNameOffset,
          origName.length, AngularWarningCode.EMPTY_BINDING, [origName]));
      //value = value == ""
      //    ? "null"
      //    : value; // we've created a warning. Suppress parse error now.
    }
    final propNameOffset = origNameOffset + prefix.length;
    final propName = _removePrefixSuffix(origName, prefix, suffix);
    return new ExpressionBoundAttribute(
        propName,
        propNameOffset,
        value,
        valueOffset,
        origName,
        origNameOffset,
        dartParser.parseDartExpression(valueOffset, value,
            detectTrailing: true),
        bound);
  }

  List<NodeInfo> _convertChildren(html.Element node, ElementInfo parent) {
    final children = <NodeInfo>[];
    for (final child in node.nodes) {
      final childNode = convert(child, parent: parent);
      if (childNode != null) {
        children.add(childNode);
        if (childNode is ElementInfo) {
          parent.childNodesMaxEnd = childNode.childNodesMaxEnd;
        } else {
          parent.childNodesMaxEnd = childNode.offset + childNode.length;
        }
      }
    }
    return children;
  }

  TemplateAttribute findTemplateAttribute(List<AttributeInfo> attributes) {
    // TODO report errors when there are two or when its already a <template>
    for (final attribute in attributes) {
      if (attribute is TemplateAttribute) {
        return attribute;
      }
    }
    return null;
  }

  String _removePrefixSuffix(String value, String prefix, String suffix) {
    // ignore: parameter_assignments
    value = value.substring(prefix.length);
    if (suffix != null && value.endsWith(suffix)) {
      return value.substring(0, value.length - suffix.length);
    }
    return value;
  }

  int _nameOffset(html.Element element, String name) {
    final lowerName = name.toLowerCase();
    try {
      return element.attributeSpans[lowerName].start.offset;
      // See https://github.com/dart-lang/html/issues/44.
    } catch (e) {
      try {
        final AttributeSpanContainer container =
            AttributeSpanContainer.generateAttributeSpans(element);
        return container.attributeSpans[name].start.offset;
      } catch (e) {
        throw new IgnorableHtmlInternalException(e);
      }
    }
  }

  int _valueOffset(html.Element element, String name) {
    final lowerName = name.toLowerCase();
    try {
      final span = element.attributeValueSpans[lowerName];
      if (span != null) {
        return span.start.offset;
      } else {
        final AttributeSpanContainer container =
            AttributeSpanContainer.generateAttributeSpans(element);
        return (container.attributeValueSpans.containsKey(name))
            ? container.attributeValueSpans[name].start.offset
            : null;
      }
    } catch (e) {
      throw new IgnorableHtmlInternalException(e);
    }
  }

  SourceRange _toSourceRange(SourceSpan span) {
    if (span != null) {
      return new SourceRange(span.start.offset, span.length);
    }
    return null;
  }
}

class EmbeddedDartParser {
  final Source templateSource;
  final AnalysisErrorListener errorListener;
  final ErrorReporter errorReporter;

  EmbeddedDartParser(
      this.templateSource, this.errorListener, this.errorReporter);

  /// Parse the given Dart [code] that starts at [offset].
  Expression parseDartExpression(int offset, String code,
      {@required bool detectTrailing}) {
    if (code == null) {
      return null;
    }

    final token = _scanDartCode(offset, code);
    Expression expression;

    // suppress errors for this. But still parse it so we can analyze it and stuff
    if (code == "") {
      expression = _parseDartExpressionAtToken(token,
          errorListener: new IgnoringAnalysisErrorListener());
    } else {
      expression = _parseDartExpressionAtToken(token);
    }

    if (detectTrailing && expression.endToken.next.type != TokenType.EOF) {
      final trailingExpressionBegin = expression.endToken.next.offset;
      errorListener.onError(new AnalysisError(
          templateSource,
          trailingExpressionBegin,
          offset + code.length - trailingExpressionBegin,
          AngularWarningCode.TRAILING_EXPRESSION));
    }

    return expression;
  }

  /// Parse the given Dart [code] that starts ot [offset].
  /// Also removes and reports dangling closing brackets.
  List<Statement> parseDartStatements(int offset, String code) {
    final allStatements = <Statement>[];
    if (code == null) {
      return allStatements;
    }

    // ignore: parameter_assignments, prefer_interpolation_to_compose_strings
    code = code + ';';

    var token = _scanDartCode(offset, code);

    while (token.type != TokenType.EOF) {
      final currentStatements = _parseDartStatementsAtToken(token);

      if (currentStatements.isNotEmpty) {
        allStatements.addAll(currentStatements);
        token = currentStatements.last.endToken.next;
      }
      if (token.type == TokenType.EOF) {
        break;
      }
      if (token.type == TokenType.CLOSE_CURLY_BRACKET) {
        final startCloseBracket = token.offset;
        while (token.type == TokenType.CLOSE_CURLY_BRACKET) {
          token = token.next;
        }
        final length = token.offset - startCloseBracket;
        errorListener.onError(new AnalysisError(
            templateSource,
            startCloseBracket,
            length,
            ParserErrorCode.UNEXPECTED_TOKEN,
            ["}"]));
        continue;
      } else {
        //Nothing should trigger here, but just in case to prevent infinite loop
        token = token.next;
      }
    }
    return allStatements;
  }

  /// Parse the Dart expression starting at the given [token].
  Expression _parseDartExpressionAtToken(Token token,
      {AnalysisErrorListener errorListener}) {
    errorListener ??= this.errorListener;
    final parser = new NgExprParser(templateSource, errorListener);
    return parser.parseExpression(token);
  }

  /// Parse the Dart statement starting at the given [token].
  List<Statement> _parseDartStatementsAtToken(Token token) {
    final parser = new Parser(templateSource, errorListener);
    return parser.parseStatements(token);
  }

  /// Scan the given Dart [code] that starts at [offset].
  Token _scanDartCode(int offset, String code) {
    // ignore: prefer_interpolation_to_compose_strings
    final text = ' ' * offset + code;
    final reader = new CharSequenceReader(text);
    final scanner = new Scanner(templateSource, reader, errorListener);
    return scanner.tokenize();
  }

  /// Scan the given [text] staring at the given [offset] and resolve all of
  /// its embedded expressions.
  List<Mustache> findMustaches(String text, int fileOffset) {
    final mustaches = <Mustache>[];
    if (text == null || text.length < 2) {
      return mustaches;
    }

    var textOffset = 0;
    while (true) {
      // begin
      final begin = text.indexOf('{{', textOffset);
      final nextBegin = text.indexOf('{{', begin + 2);
      final end = text.indexOf('}}', textOffset);

      int exprBegin, exprEnd;
      var detectTrailing = false;
      if (begin == -1 && end == -1) {
        break;
      }

      if (end == -1) {
        errorListener.onError(new AnalysisError(templateSource,
            fileOffset + begin, 2, AngularWarningCode.UNTERMINATED_MUSTACHE));
        // Move the cursor ahead and keep looking for more unmatched mustaches.
        textOffset = begin + 2;
        exprBegin = textOffset;
        exprEnd = _startsWithWhitespace(text.substring(exprBegin))
            ? exprBegin
            : text.length;
      } else if (begin == -1 || end < begin) {
        errorListener.onError(new AnalysisError(templateSource,
            fileOffset + end, 2, AngularWarningCode.UNOPENED_MUSTACHE));
        // Move the cursor ahead and keep looking for more unmatched mustaches.
        textOffset = end + 2;
        continue;
      } else if (nextBegin != -1 && nextBegin < end) {
        errorListener.onError(new AnalysisError(templateSource,
            fileOffset + begin, 2, AngularWarningCode.UNTERMINATED_MUSTACHE));
        // Skip this open mustache, check the next open we found
        textOffset = begin + 2;
        exprBegin = textOffset;
        exprEnd = nextBegin;
      } else {
        exprBegin = begin + 2;
        exprEnd = end;
        textOffset = end + 2;
        detectTrailing = true;
      }
      // resolve
      final code = text.substring(exprBegin, exprEnd);
      final expression = parseDartExpression(fileOffset + exprBegin, code,
          detectTrailing: detectTrailing);

      final offset = fileOffset + begin;

      int length;
      if (end == -1) {
        length = expression.offset + expression.length - offset;
      } else {
        length = end + 2 - begin;
      }

      mustaches.add(new Mustache(offset, length, expression));
    }

    return mustaches;
  }

  bool _startsWithWhitespace(String string) =>
      // trim returns the original string when no changes were made
      !identical(string.trimLeft(), string);

  /// Desugar a template="" or *blah="" attribute into its list of virtual
  /// [AttributeInfo]s
  Tuple2<String, List<AttributeInfo>> parseTemplateVirtualAttributes(
      int offset, String code) {
    final attributes = <AttributeInfo>[];

    var token = _scanDartCode(offset, code);
    String prefix;
    while (token.type != TokenType.EOF) {
      // skip optional comma or semicolons
      if (_isDelimiter(token)) {
        token = token.next;
        continue;
      }
      // maybe a local variable
      if (_isTemplateVarBeginToken(token)) {
        final originalVarOffset = token.offset;
        if (token.type == TokenType.HASH) {
          errorReporter.reportErrorForToken(
              AngularWarningCode.UNEXPECTED_HASH_IN_TEMPLATE, token);
        }

        var originalName = token.lexeme;

        // get the local variable name
        token = token.next;
        var localVarName = "";
        var localVarOffset = token.offset;
        if (!_tokenMatchesIdentifier(token)) {
          errorReporter.reportErrorForToken(
              AngularWarningCode.EXPECTED_IDENTIFIER, token);
        } else {
          localVarOffset = token.offset;
          localVarName = token.lexeme;
          // ignore: prefer_interpolation_to_compose_strings
          originalName +=
              ' ' * (token.offset - originalVarOffset - 'let'.length) +
                  localVarName;
          token = token.next;
        }

        // get an optional internal variable
        int internalVarOffset;
        String internalVarName;
        if (token.type == TokenType.EQ) {
          token = token.next;
          // get the internal variable
          if (!_tokenMatchesIdentifier(token)) {
            errorReporter.reportErrorForToken(
                AngularWarningCode.EXPECTED_IDENTIFIER, token);
            break;
          }
          internalVarOffset = token.offset;
          internalVarName = token.lexeme;
          token = token.next;
        }
        // declare the local variable
        // Note the care that the varname's offset is preserved in place.
        attributes.add(new TextAttribute.synthetic(
            'let-$localVarName',
            localVarOffset - 'let-'.length,
            internalVarName,
            internalVarOffset,
            originalName,
            originalVarOffset, []));
        continue;
      }

      // key
      String key;
      final keyBuffer = new StringBuffer();
      final keyOffset = token.offset;
      String originalName;
      final originalNameOffset = keyOffset;
      if (_tokenMatchesIdentifier(token)) {
        // scan for a full attribute name
        var lastEnd = token.offset;
        while (token.offset == lastEnd &&
            (_tokenMatchesIdentifier(token) || token.type == TokenType.MINUS)) {
          keyBuffer.write(token.lexeme);
          lastEnd = token.end;
          token = token.next;
        }

        originalName = keyBuffer.toString();

        // add the prefix
        if (prefix == null) {
          prefix = keyBuffer.toString();
          key = keyBuffer.toString();
        } else {
          // ignore: prefer_interpolation_to_compose_strings
          key = prefix + capitalize(keyBuffer.toString());
        }
      } else {
        errorReporter.reportErrorForToken(
            AngularWarningCode.EXPECTED_IDENTIFIER, token);
        break;
      }
      // skip optional ':' or '='
      if (token.type == TokenType.COLON || token.type == TokenType.EQ) {
        token = token.next;
      }
      // expression
      if (!_isTemplateVarBeginToken(token) &&
          !_isDelimiter(token) &&
          token.type != TokenType.EOF) {
        final expression = _parseDartExpressionAtToken(token);
        final start = token.offset - offset;

        token = expression.endToken.next;
        final end = token.offset - offset;
        final exprCode = code.substring(start, end);
        attributes.add(new ExpressionBoundAttribute(
            key,
            keyOffset,
            exprCode,
            expression.offset,
            originalName,
            originalNameOffset,
            expression,
            ExpressionBoundType.input));
      } else {
        attributes.add(new TextAttribute.synthetic(
            key, keyOffset, null, null, originalName, originalNameOffset, []));
      }
    }

    return new Tuple2(prefix, attributes);
  }

  static bool _isDelimiter(Token token) =>
      token.type == TokenType.COMMA || token.type == TokenType.SEMICOLON;

  static bool _isTemplateVarBeginToken(Token token) =>
      token is KeywordToken && token.keyword == Keyword.VAR ||
      (token.type == TokenType.IDENTIFIER && token.lexeme == 'let') ||
      token.type == TokenType.HASH;

  static bool _tokenMatchesBuiltInIdentifier(Token token) =>
      token is KeywordToken && token.keyword.isBuiltInOrPseudo;

  static bool _tokenMatchesIdentifier(Token token) =>
      token.type == TokenType.IDENTIFIER ||
      _tokenMatchesBuiltInIdentifier(token);
}

class IgnorableHtmlInternalException implements Exception {
  String msg;
  IgnorableHtmlInternalException(this.msg);

  @override
  String toString() => "IgnorableHtmlInternalException: $msg";
}
