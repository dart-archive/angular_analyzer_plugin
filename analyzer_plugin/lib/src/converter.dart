import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/ast/token.dart' hide SimpleToken;
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/ng_expr_parser.dart';
import 'package:angular_analyzer_plugin/src/strings.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;
import 'package:source_span/source_span.dart';

class HtmlTreeConverter {
  EmbeddedDartParser dartParser;

  HtmlTreeConverter(this.dartParser);

  NodeInfo convert(html.Node node) {
    if (node is html.Element) {
      String localName = node.localName;
      List<AttributeInfo> attributes = _convertAttributes(node);
      bool isTemplate = localName == 'template';
      SourceRange openingSpan = _toSourceRange(node.sourceSpan);
      SourceRange closingSpan = _toSourceRange(node.endSourceSpan);
      SourceRange openingNameSpan = openingSpan != null
          ? new SourceRange(openingSpan.offset + '<'.length, localName.length)
          : null;
      SourceRange closingNameSpan = closingSpan != null
          ? new SourceRange(closingSpan.offset + '</'.length, localName.length)
          : null;
      ElementInfo element = new ElementInfo(
          localName,
          openingSpan,
          closingSpan,
          openingNameSpan,
          closingNameSpan,
          isTemplate,
          attributes,
          findTemplateAttribute(attributes));
      List<NodeInfo> children = _convertChildren(node);
      element.childNodes.addAll(children);
      return element;
    }
    if (node is html.Text) {
      int offset = node.sourceSpan.start.offset;
      String text = node.text;
      return new TextInfo(offset, text, dartParser.findMustaches(text, offset));
    }
    return null;
  }

  List<AttributeInfo> _convertAttributes(html.Element element) {
    List<AttributeInfo> attributes = <AttributeInfo>[];
    element.attributes.forEach((name, String value) {
      if (name is String) {
        try {
          if (name.startsWith('*')) {
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
            var valueOffset = _valueOffset(element, name);
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
        } on IgnorableHtmlInternalError {
          // See https://github.com/dart-lang/html/issues/44, this error will
          // be thrown looking for nameOffset. Catch it so that analysis else
          // where continues.
          return;
        }
      }
    });
    return attributes;
  }

  TemplateAttribute _convertTemplateAttribute(
      html.Element element, String origName, bool starSugar) {
    int origNameOffset = _nameOffset(element, origName);
    String value = element.attributes[origName];
    int valueOffset = _valueOffset(element, origName);
    String name;
    int nameOffset;
    List<AttributeInfo> virtualAttributes;
    if (starSugar) {
      nameOffset = origNameOffset + '*'.length;
      name = _removePrefixSuffix(origName, '*', null);
      virtualAttributes = dartParser.parseTemplateVirtualAttributes(
          nameOffset, name + (' ' * '="'.length) + value);
    } else {
      name = origName;
      nameOffset = origNameOffset;
      virtualAttributes =
          dartParser.parseTemplateVirtualAttributes(valueOffset, value);
    }

    return new TemplateAttribute(name, nameOffset, value, valueOffset, origName,
        origNameOffset, virtualAttributes);
  }

  StatementsBoundAttribute _convertStatementsBoundAttribute(
      html.Element element, String origName, String prefix, String suffix) {
    int origNameOffset = _nameOffset(element, origName);
    String value = element.attributes[origName];
    int valueOffset = _valueOffset(element, origName);
    int propNameOffset = origNameOffset + prefix.length;
    String propName = _removePrefixSuffix(origName, prefix, suffix);
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
    int origNameOffset = _nameOffset(element, origName);
    String value = element.attributes[origName];
    int valueOffset = _valueOffset(element, origName);
    int propNameOffset = origNameOffset + prefix.length;
    String propName = _removePrefixSuffix(origName, prefix, suffix);
    return new ExpressionBoundAttribute(
        propName,
        propNameOffset,
        value,
        valueOffset,
        origName,
        origNameOffset,
        dartParser.parseDartExpression(valueOffset, value, true),
        bound);
  }

  List<NodeInfo> _convertChildren(html.Element node) {
    List<NodeInfo> children = <NodeInfo>[];
    for (html.Node child in node.nodes) {
      NodeInfo node = convert(child);
      if (node != null) {
        children.add(node);
      }
    }
    return children;
  }

  TemplateAttribute findTemplateAttribute(List<AttributeInfo> attributes) {
    // TODO report errors when there are two or when its already a <template>
    for (AttributeInfo attribute in attributes) {
      if (attribute is TemplateAttribute) {
        return attribute;
      }
    }
    return null;
  }

  String _removePrefixSuffix(String value, String prefix, String suffix) {
    value = value.substring(prefix.length);
    if (suffix != null && value.endsWith(suffix)) {
      return value.substring(0, value.length - suffix.length);
    }
    return value;
  }

  int _nameOffset(html.Element element, String name) {
    try {
      String lowerName = name.toLowerCase();
      return element.attributeSpans[lowerName].start.offset;
      // See https://github.com/dart-lang/html/issues/44.
    } catch (e) {
      throw new IgnorableHtmlInternalError(e);
    }
  }

  int _valueOffset(html.Element element, String name) {
    try {
      SourceSpan span = element.attributeValueSpans[name.toLowerCase()];
      if (span != null) {
        return span.start.offset;
      } else {
        return null;
      }
    } catch (e) {
      throw new IgnorableHtmlInternalError(e);
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
  final TypeProvider typeProvider;
  final ErrorReporter errorReporter;

  EmbeddedDartParser(this.templateSource, this.errorListener, this.typeProvider,
      this.errorReporter);

  /**
   * Parse the given Dart [code] that starts at [offset].
   */
  Expression parseDartExpression(int offset, String code, bool detectTrailing) {
    Token token = _scanDartCode(offset, code);
    Expression expression = _parseDartExpressionAtToken(token);

    if (detectTrailing && expression.endToken.next.type != TokenType.EOF) {
      int trailingExpressionBegin = expression.endToken.next.offset;
      errorListener.onError(new AnalysisError(
          templateSource,
          trailingExpressionBegin,
          offset + code.length - trailingExpressionBegin,
          AngularWarningCode.TRAILING_EXPRESSION));
    }

    return expression;
  }

  /**
   * Parse the given Dart [code] that starts ot [offset].
   * Also removes and reports dangling closing brackets.
   */
  List<Statement> parseDartStatements(int offset, String code) {
    code = code + ';';
    List<Statement> allStatements = new List<Statement>();
    Token token = _scanDartCode(offset, code);

    while (token.type != TokenType.EOF) {
      List<Statement> currentStatements = _parseDartStatementsAtToken(token);

      if (currentStatements.isNotEmpty) {
        allStatements.addAll(currentStatements);
        token = currentStatements.last.endToken.next;
      }
      if (token.type == TokenType.EOF) {
        break;
      }
      if (token.type == TokenType.CLOSE_CURLY_BRACKET) {
        int startCloseBracket = token.offset;
        while (token.type == TokenType.CLOSE_CURLY_BRACKET) {
          token = token.next;
        }
        int length = token.offset - startCloseBracket;
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

  /**
   * Parse the Dart expression starting at the given [token].
   */
  Expression _parseDartExpressionAtToken(Token token) {
    Parser parser =
        new NgExprParser(templateSource, errorListener, typeProvider);
    return parser.parseExpression(token);
  }

  /**
   * Parse the Dart statement starting at the given [token].
   */
  List<Statement> _parseDartStatementsAtToken(Token token) {
    Parser parser = new Parser(templateSource, errorListener);
    return parser.parseStatements(token);
  }

  /**
   * Scan the given Dart [code] that starts at [offset].
   */
  Token _scanDartCode(int offset, String code) {
    String text = ' ' * offset + code;
    CharSequenceReader reader = new CharSequenceReader(text);
    Scanner scanner = new Scanner(templateSource, reader, errorListener);
    return scanner.tokenize();
  }

  /**
   * Scan the given [text] staring at the given [offset] and resolve all of
   * its embedded expressions.
   */
  List<Mustache> findMustaches(String text, int fileOffset) {
    List<Mustache> mustaches = <Mustache>[];
    if (text == null || text.length < 2) {
      return mustaches;
    }

    int textOffset = 0;
    while (true) {
      // begin
      int begin = text.indexOf('{{', textOffset);
      int nextBegin = text.indexOf('{{', begin + 2);
      int end = text.indexOf('}}', textOffset);
      int exprBegin, exprEnd;
      bool detectTrailing = false;
      if (begin == -1 && end == -1) {
        break;
      }

      if (end == -1) {
        errorListener.onError(new AnalysisError(templateSource,
            fileOffset + begin, 2, AngularWarningCode.UNTERMINATED_MUSTACHE));
        // Move the cursor ahead and keep looking for more unmatched mustaches.
        textOffset = begin + 2;
        exprBegin = textOffset;
        exprEnd = text.length;
      } else if (begin == -1) {
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
        begin += 2;
        exprBegin = begin;
        exprEnd = end;
        textOffset = end + 2;
        detectTrailing = true;
      }
      // resolve
      String code = text.substring(exprBegin, exprEnd);
      Expression expression =
          parseDartExpression(fileOffset + exprBegin, code, detectTrailing);
      mustaches.add(new Mustache(fileOffset + begin, end + 2, expression));
    }

    return mustaches;
  }

  /**
   * Desugar a template="" or *blah="" attribute into its list of virtual [AttributeInfo]s
   */
  List<AttributeInfo> parseTemplateVirtualAttributes(int offset, String code) {
    List<AttributeInfo> attributes = <AttributeInfo>[];
    Token token = _scanDartCode(offset, code);
    String prefix = null;
    while (token.type != TokenType.EOF) {
      // skip optional comma or semicolons
      if (token.type == TokenType.COMMA || token.type == TokenType.SEMICOLON) {
        token = token.next;
        continue;
      }
      // maybe a local variable
      if (_isTemplateVarBeginToken(token)) {
        if (token.type == TokenType.HASH) {
          errorReporter.reportErrorForToken(
              AngularWarningCode.UNEXPECTED_HASH_IN_TEMPLATE, token);
        }
        token = token.next;
        // get the local variable name
        if (!_tokenMatchesIdentifier(token)) {
          errorReporter.reportErrorForToken(
              AngularWarningCode.EXPECTED_IDENTIFIER, token);
          break;
        }
        int localVarOffset = token.offset;
        String localVarName = token.lexeme;
        token = token.next;
        // get an optional internal variable
        int internalVarOffset = -1;
        String internalVarName = null;
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
        attributes.add(new TextAttribute(
            'let-$localVarName',
            localVarOffset - 'let-'.length,
            internalVarName,
            internalVarOffset, []));
        continue;
      }
      // key
      int keyOffset = token.offset;
      String key = null;
      if (_tokenMatchesIdentifier(token)) {
        // scan for a full attribute name
        key = '';
        int lastEnd = token.offset;
        while (token.offset == lastEnd &&
            (_tokenMatchesIdentifier(token) || token.type == TokenType.MINUS)) {
          key += token.lexeme;
          lastEnd = token.end;
          token = token.next;
        }
        // add the prefix
        if (prefix == null) {
          prefix = key;
        } else {
          key = prefix + capitalize(key);
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
      if (!_isTemplateVarBeginToken(token)) {
        Expression expression = _parseDartExpressionAtToken(token);
        var start = token.offset - offset;
        token = expression.endToken.next;
        var end = token.offset - offset;
        var exprCode = code.substring(start, end);
        attributes.add(new ExpressionBoundAttribute(key, keyOffset, key,
            keyOffset, exprCode, start, expression, ExpressionBoundType.input));
      } else {
        attributes.add(new TextAttribute(key, keyOffset, null, null, []));
      }
    }

    return attributes;
  }

  static bool _isTemplateVarBeginToken(Token token) {
    return token is KeywordToken && token.keyword == Keyword.VAR ||
        (token.type == TokenType.IDENTIFIER && token.lexeme == 'let') ||
        token.type == TokenType.HASH;
  }

  static bool _tokenMatchesBuiltInIdentifier(Token token) =>
      token is KeywordToken && token.keyword.isPseudoKeyword;

  static bool _tokenMatchesIdentifier(Token token) =>
      token.type == TokenType.IDENTIFIER ||
      _tokenMatchesBuiltInIdentifier(token);
}

class IgnorableHtmlInternalError extends StateError {
  IgnorableHtmlInternalError(String msg) : super(msg);
}
