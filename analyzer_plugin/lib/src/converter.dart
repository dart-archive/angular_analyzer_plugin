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
import 'package:angular_ast/angular_ast.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/ng_expr_parser.dart';
import 'package:angular_analyzer_plugin/src/ignoring_error_listener.dart';
import 'package:angular_analyzer_plugin/src/strings.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html;

html.Element firstElement(html.Node node) {
  for (html.Element child in node.children) {
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

  NodeInfo convertFromAstList(List<StandaloneTemplateAst> asts) {
    NodeInfo root;
    if (asts.length == 1 && (asts[0] as ElementAst).name == 'html') {
      root = convert(asts[0]);
      return root;
    } else {
      root = new ElementInfo(
        'html',
        null,
        null,
        null,
        null,
        false,
        <AttributeInfo>[],
        null,
        null,
      );
    }
    for (StandaloneTemplateAst node in asts) {
      convert(node, parent: root);
    }
    return root;
  }

  NodeInfo convert(StandaloneTemplateAst node, {ElementInfo parent}) {
    // TODO: Handle EmbeddedContentAst case separately
    if (node is ElementAst) {
      String localName = node.name;
      List<AttributeInfo> attributes = _convertAttributes(node);
      bool isTemplate = localName == 'template';
      TemplateAst closeComponent = node.closeComplement;
      SourceRange openingSpan;
      SourceRange closingSpan;

      if (node.isSynthetic) {
        openingSpan = _toSourceRange(closeComponent.beginToken.offset, 0);
      } else {
        openingSpan = _toSourceRange(
            node.beginToken.offset, node.endToken.end - node.beginToken.offset);
      }
      if (closeComponent.isSynthetic) {
        closingSpan = _toSourceRange(node.endToken.end, 0);
      } else {
        closingSpan = _toSourceRange(closeComponent.beginToken.offset,
            closeComponent.endToken.end - closeComponent.beginToken.offset);
      }

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
          findTemplateAttribute(attributes),
          parent);

      for (AttributeInfo attribute in attributes) {
        attribute.parent = element;
      }

      List<NodeInfo> children = _convertChildren(node, element);
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
    if (node is TextAst) {
      int offset = node.sourceSpan.start.offset;
      String text = node.value;
      return new TextInfo(
          offset, text, parent, dartParser.findMustaches(text, offset));
    }
    if (node is InterpolationAst) {
      int offset = node.sourceSpan.start.offset;
      String text = "{{" + node.value + "}}";
      return new TextInfo(
          offset, text, parent, dartParser.findMustaches(text, offset));
    }
    return null;
  }

  List<AttributeInfo> _convertAttributes(ElementAst element) {
    List<AttributeInfo> attributes = <AttributeInfo>[];

    // Atttribute/event/properties/etc. within
    // [ElementAst] cannot be synthetic as long as Desugaring never occurs.
    if (element is ElementAst) {
      element.attributes.forEach((AttributeAst attribute) {
        if (attribute.name.startsWith('on-')) {
          attributes
              .add(_convertStatementsBoundAttribute(attribute, "on-", null));
        } else if (attribute.name.startsWith('bind-')) {
          attributes.add(_convertExpressionBoundAttribute(
              attribute, "bind-", null, ExpressionBoundType.input));
        } else if (attribute.name == 'template') {
          attributes.add(_convertTemplateAttribute(attribute));
        } else {
          ParsedAttributeAst _attr = attribute as ParsedAttributeAst;
          String value = _attr.valueToken.innerValue.lexeme;
          int valueOffset = _attr.valueToken.innerValue.offset;
          attributes.add(new TextAttribute(_attr.name, _attr.nameOffset, value,
              valueOffset, dartParser.findMustaches(value, valueOffset)));
        }
      });

      element.events.forEach((event) {
        attributes.add(_convertStatementsBoundAttribute(event, "(", ")"));
      });

      element.bananas.forEach((banana) {
        attributes.add(_convertExpressionBoundAttribute(
            banana, "[(", ")]", ExpressionBoundType.twoWay));
      });

      element.properties.forEach((property) {
        if (property.name == "class") {
          attributes.add(_convertExpressionBoundAttribute(
              property, "[class.", "]", ExpressionBoundType.clazz));
        } else if (property.name == "attr") {
          attributes.add(_convertExpressionBoundAttribute(
              property, "[attr.", "]", ExpressionBoundType.attr));
        } else if (property.name == "style") {
          attributes.add(_convertExpressionBoundAttribute(
              property, "[style.", "]", ExpressionBoundType.style));
        } else {
          attributes.add(_convertExpressionBoundAttribute(
              property, "[", "]", ExpressionBoundType.input));
        }
      });

      element.references.forEach((reference) {
        ParsedReferenceAst _attr = reference as ParsedReferenceAst;
        String value = _attr.valueToken.innerValue.lexeme;
        int valueOffset = _attr.valueToken.innerValue.offset;
        attributes.add(new TextAttribute(
            _attr.prefixToken.lexeme + _attr.nameToken.lexeme,
            _attr.prefixToken.offset,
            value,
            valueOffset,
            dartParser.findMustaches(value, valueOffset)));
      });

      element.stars.forEach((star) {
        attributes.add(_convertTemplateAttribute(star));
      });
    }
//    element.attributes.forEach((name, String value) {
//      if (name is String) {
//        try {
//          if (name == "") {
//            attributes.add(_convertSyntheticAttribute(element));
//          } else if (name.startsWith('*')) {
//            attributes.add(_convertTemplateAttribute(element, name, true));
//          } else if (name == 'template') {
//            attributes.add(_convertTemplateAttribute(element, name, false));
//          } else if (name.startsWith('[(')) {
//            attributes.add(_convertExpressionBoundAttribute(
//                element, name, "[(", ")]", ExpressionBoundType.twoWay));
//          } else if (name.startsWith('[class.')) {
//            attributes.add(_convertExpressionBoundAttribute(
//                element, name, "[class.", "]", ExpressionBoundType.clazz));
//          } else if (name.startsWith('[attr.')) {
//            attributes.add(_convertExpressionBoundAttribute(
//                element, name, "[attr.", "]", ExpressionBoundType.attr));
//          } else if (name.startsWith('[style.')) {
//            attributes.add(_convertExpressionBoundAttribute(
//                element, name, "[style.", "]", ExpressionBoundType.style));
//          } else if (name.startsWith('[')) {
//            attributes.add(_convertExpressionBoundAttribute(
//                element, name, "[", "]", ExpressionBoundType.input));
//          } else if (name.startsWith('bind-')) {
//            attributes.add(_convertExpressionBoundAttribute(
//                element, name, "bind-", null, ExpressionBoundType.input));
//          } else if (name.startsWith('on-')) {
//            attributes.add(
//                _convertStatementsBoundAttribute(element, name, "on-", null));
//          } else if (name.startsWith('(')) {
//            attributes
//                .add(_convertStatementsBoundAttribute(element, name, "(", ")"));
//          } else {
//            var valueOffset = _valueOffset(element, name);
//            if (valueOffset == null) {
//              value = null;
//            }
//
//            attributes.add(new TextAttribute(
//                name,
//                _nameOffset(element, name),
//                value,
//                valueOffset,
//                dartParser.findMustaches(value, valueOffset)));
//          }
//        } on IgnorableHtmlInternalError {
//          // See https://github.com/dart-lang/html/issues/44, this error will
//          // be thrown looking for nameOffset. Catch it so that analysis else
//          // where continues.
//          return;
//        }
//      }
//    });
    return attributes;
  }

  TemplateAttribute _convertTemplateAttribute(TemplateAst ast) {
    String name;
    int nameOffset;

    String value;
    int valueOffset;

    String origName;
    int origNameOffset;

    List<AttributeInfo> virtualAttributes;

    if (ast is ParsedStarAst) {
      value = ast.value;
      valueOffset = ast.valueOffset;

      origName = ast.prefixToken.lexeme + ast.nameToken.lexeme;
      origNameOffset = ast.prefixToken.offset;

      name = ast.nameToken.lexeme;
      nameOffset = ast.nameToken.offset;

      String fullAstName;
      if (value != null) {
        fullAstName = ast.name +
            (' ' * (ast.equalSignOffset - ast.nameToken.end)) +
            ' ' +
            (' ' * (ast.valueToken.offset - ast.equalSignToken.end)) +
            (value ?? '');
      } else {
        fullAstName = ast.name + ' ';
      }

      virtualAttributes =
          dartParser.parseTemplateVirtualAttributes(nameOffset, fullAstName);
    }
    if (ast is ParsedAttributeAst) {
      value = ast.value;
      valueOffset = ast.valueOffset;

      origName = ast.name;
      origNameOffset = ast.nameOffset;

      name = origName;
      nameOffset = origNameOffset;

      virtualAttributes =
          dartParser.parseTemplateVirtualAttributes(valueOffset, value);
    }

    TemplateAttribute templateAttribute = new TemplateAttribute(
        name,
        nameOffset,
        value,
        valueOffset,
        origName,
        origNameOffset,
        virtualAttributes);

    for (AttributeInfo virtualAttribute in virtualAttributes) {
      virtualAttribute.parent = templateAttribute;
    }

    return templateAttribute;
  }

  StatementsBoundAttribute _convertStatementsBoundAttribute(
      TemplateAst ast, String prefix, String suffix) {
    String propName;
    int propNameOffset;

    String value;
    int valueOffset;

    String origName;
    int origNameOffset;

    // TODO: refactor once a generic DecoratorAst is created
    if (ast is ParsedAttributeAst) {
      origName = ast.name;
      origNameOffset = ast.nameOffset;

      value = ast.value;
      if (value == null) {
        errorListener.onError(new AnalysisError(
            templateSource,
            origNameOffset,
            ast.nameToken.length,
            AngularWarningCode.EMPTY_BINDING,
            [ast.name]));
      }
      valueOffset = ast.valueOffset;

      propName = _removePrefixSuffix(origName, prefix, suffix);
      propNameOffset = origNameOffset + prefix.length;
    } else if (ast is ParsedEventAst) {
      origName = ast.prefixToken.lexeme +
          ast.nameToken.lexeme +
          ast.suffixToken.lexeme;
      origNameOffset = ast.prefixToken.offset;

      value = ast.value;
      if (value == null) {
        errorListener.onError(new AnalysisError(
            templateSource,
            origNameOffset,
            ast.nameToken.length,
            AngularWarningCode.EMPTY_BINDING,
            [ast.name]));
      }
      valueOffset = ast.valueOffset;

      propName = _removePrefixSuffix(origName, prefix, suffix);
      propNameOffset = origNameOffset + prefix.length;
    }
    return new StatementsBoundAttribute(
        propName,
        propNameOffset,
        value,
        valueOffset,
        origName,
        origNameOffset,
        dartParser.parseDartStatements(valueOffset, value));
  }

  ExpressionBoundAttribute _convertExpressionBoundAttribute(TemplateAst ast,
      String prefix, String suffix, ExpressionBoundType bound) {
    String propName;
    int propNameOffset;

    String value;
    int valueOffset;

    String origName;
    int origNameOffset;

    // TODO: Refactor once DecoratorAst is introduced
    if (ast is ParsedAttributeAst) {
      origName = ast.name;
      origNameOffset = ast.nameOffset;

      value = ast.value;
      if (value == null || value == "") {
        errorListener.onError(new AnalysisError(templateSource, origNameOffset,
            origName.length, AngularWarningCode.EMPTY_BINDING, [origName]));
      }
      valueOffset = ast.valueOffset;

      propName = _removePrefixSuffix(origName, prefix, suffix);
      propNameOffset = origNameOffset + prefix.length;
    }
    if (ast is ParsedEventAst) {
      origName = ast.prefixToken.lexeme +
          ast.nameToken.lexeme +
          ast.suffixToken.lexeme;
      origNameOffset = ast.prefixToken.offset;

      value = ast.value;
      if (value == null || value == "") {
        errorListener.onError(new AnalysisError(templateSource, origNameOffset,
            origName.length, AngularWarningCode.EMPTY_BINDING, [origName]));
      }
      valueOffset = ast.valueOffset;

      propName = _removePrefixSuffix(origName, prefix, suffix);
      propNameOffset = origNameOffset + prefix.length;
    }
    if (ast is ParsedBananaAst) {
      origName = ast.prefixToken.lexeme +
          ast.nameToken.lexeme +
          ast.suffixToken.lexeme;
      origNameOffset = ast.prefixToken.offset;

      value = ast.value;
      if (value == null || value == "") {
        errorListener.onError(new AnalysisError(templateSource, origNameOffset,
            origName.length, AngularWarningCode.EMPTY_BINDING, [origName]));
      }
      valueOffset = ast.valueOffset;

      propName = _removePrefixSuffix(origName, prefix, suffix);
      propNameOffset = origNameOffset + prefix.length;
    }

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

  List<NodeInfo> _convertChildren(
      StandaloneTemplateAst node, ElementInfo parent) {
    List<NodeInfo> children = <NodeInfo>[];
    for (StandaloneTemplateAst child in node.childNodes) {
      NodeInfo childNode = convert(child, parent: parent);
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

  SourceRange _toSourceRange(int offset, int length) {
    return new SourceRange(offset, length);
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
    if (code == null) {
      return null;
    }

    final Token token = _scanDartCode(offset, code);
    Expression expression;

    // suppress errors for this. But still parse it so we can analyze it and stuff
    if (code == "") {
      expression = _parseDartExpressionAtToken(token,
          errorListener: new IgnoringAnalysisErrorListener());
    } else {
      expression = _parseDartExpressionAtToken(token);
    }

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
    List<Statement> allStatements = new List<Statement>();
    if (code == null) {
      return allStatements;
    }
    code = code + ';';
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
  Expression _parseDartExpressionAtToken(Token token,
      {AnalysisErrorListener errorListener}) {
    errorListener ??= this.errorListener;
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
      final int begin = text.indexOf('{{', textOffset);
      final int nextBegin = text.indexOf('{{', begin + 2);
      final int end = text.indexOf('}}', textOffset);
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
      String code = text.substring(exprBegin, exprEnd);
      Expression expression =
          parseDartExpression(fileOffset + exprBegin, code, detectTrailing);

      var offset = fileOffset + begin;
      var length;
      if (end == -1) {
        length = expression.offset + expression.length - offset;
      } else {
        length = end + 2 - begin;
      }

      mustaches.add(new Mustache(offset, length, expression));
    }

    return mustaches;
  }

  bool _startsWithWhitespace(String string) {
    // trim returns the original string when no changes were made
    return !identical(string.trimLeft(), string);
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
      if (_isDelimiter(token)) {
        token = token.next;
        continue;
      }
      // maybe a local variable
      if (_isTemplateVarBeginToken(token)) {
        if (token.type == TokenType.HASH) {
          errorReporter.reportErrorForToken(
              AngularWarningCode.UNEXPECTED_HASH_IN_TEMPLATE, token);
        }
        int originalVarOffset = token.offset;
        String originalName = token.lexeme;
        token = token.next;
        // get the local variable name
        String localVarName = "";
        int localVarOffset = token.offset;
        if (!_tokenMatchesIdentifier(token)) {
          errorReporter.reportErrorForToken(
              AngularWarningCode.EXPECTED_IDENTIFIER, token);
        } else {
          localVarOffset = token.offset;
          localVarName = token.lexeme;
          originalName +=
              ' ' * (token.offset - originalVarOffset) + localVarName;
          token = token.next;
        }
        // get an optional internal variable
        int internalVarOffset = null;
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
      int keyOffset = token.offset;
      String originalName = null;
      int originalNameOffset = keyOffset;
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

        originalName = key;

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
      if (!_isTemplateVarBeginToken(token) &&
          !_isDelimiter(token) &&
          token.type != TokenType.EOF) {
        Expression expression = _parseDartExpressionAtToken(token);
        var start = token.offset - offset;
        token = expression.endToken.next;
        var end = token.offset - offset;
        var exprCode = code.substring(start, end);
        attributes.add(new ExpressionBoundAttribute(
            key,
            keyOffset,
            exprCode,
            token.offset,
            originalName,
            originalNameOffset,
            expression,
            ExpressionBoundType.input));
      } else {
        attributes.add(new TextAttribute.synthetic(
            key, keyOffset, null, null, originalName, originalNameOffset, []));
      }
    }

    return attributes;
  }

  static bool _isDelimiter(Token token) =>
      token.type == TokenType.COMMA || token.type == TokenType.SEMICOLON;

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
