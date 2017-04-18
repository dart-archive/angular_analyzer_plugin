import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/ast/token.dart' hide SimpleToken;
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_ast/angular_ast.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/ng_expr_parser.dart';
import 'package:angular_analyzer_plugin/src/ignoring_error_listener.dart';
import 'package:angular_analyzer_plugin/src/strings.dart';
import 'package:angular_analyzer_plugin/tasks.dart';

import 'package:meta/meta.dart';

class HtmlTreeConverter {
  final EmbeddedDartParser dartParser;
  final Source templateSource;
  final AnalysisErrorListener errorListener;

  // Following Angular2 Logic:
  // https://github.com/dart-lang/angular2/blob/8220ba3a693aff51eed33cd1ec9542bde9017423/lib/src/compiler/schema/dom_element_schema_registry.dart#L199
  static const attrToPropMap = const {
    'class': 'className',
    'innerHtml': 'innerHTML',
    'readonly': 'readOnly',
    'tabindex': 'tabIndex',
  };

  HtmlTreeConverter(this.dartParser, this.templateSource, this.errorListener);

  DocumentInfo convertFromAstList(List<StandaloneTemplateAst> asts) {
    DocumentInfo root = new DocumentInfo();
    if (asts.isEmpty) {
      root.childNodes.add(new TextInfo(0, '', root, []));
    }
    for (StandaloneTemplateAst node in asts) {
      var convertedNode = convert(node, parent: root);
      if (convertedNode != null) {
        root.childNodes.add(convertedNode);
      }
    }
    return root;
  }

  NodeInfo convert(
    StandaloneTemplateAst node, {
    @required ElementInfo parent,
  }) {
    if (node is ElementAst) {
      String localName = node.name;
      List<AttributeInfo> attributes = _convertAttributes(
        attributes: node.attributes,
        bananas: node.bananas,
        events: node.events,
        properties: node.properties,
        references: node.references,
        stars: node.stars,
      );
      attributes.sort((a, b) => a.offset.compareTo(b.offset));
      final closeComponent = node.closeComplement;
      SourceRange openingSpan;
      SourceRange openingNameSpan;
      SourceRange closingSpan;
      SourceRange closingNameSpan;

      if (node.isSynthetic) {
        openingSpan = _toSourceRange(closeComponent.beginToken.offset, 0);
        openingNameSpan = openingSpan;
      } else {
        openingSpan = _toSourceRange(
            node.beginToken.offset, node.endToken.end - node.beginToken.offset);
        openingNameSpan = new SourceRange(
            (node as ParsedElementAst).identifierToken.offset,
            (node as ParsedElementAst).identifierToken.lexeme.length);
      }
      // Check for void element cases (has closing complement)
      // If closeComponent is synthetic, handle it after child nodes are found.
      if (closeComponent != null && !closeComponent.isSynthetic) {
        closingSpan = _toSourceRange(closeComponent.beginToken.offset,
            closeComponent.endToken.end - closeComponent.beginToken.offset);
        closingNameSpan =
            new SourceRange(closingSpan.offset + '</'.length, localName.length);
      }

      ElementInfo element = new ElementInfo(
          localName,
          openingSpan,
          closingSpan,
          openingNameSpan,
          closingNameSpan,
          false,
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
    if (node is EmbeddedContentAst) {
      final localName = 'ng-content';
      final attributes = <AttributeInfo>[];
      final closeComplement = node.closeComplement;
      SourceRange openingSpan;
      SourceRange openingNameSpan;
      SourceRange closingSpan;
      SourceRange closingNameSpan;

      if (node.isSynthetic) {
        openingSpan = _toSourceRange(closeComplement.beginToken.offset, 0);
        openingNameSpan = openingSpan;
      } else {
        openingSpan = _toSourceRange(
            node.beginToken.offset, node.endToken.end - node.beginToken.offset);
        openingNameSpan =
            new SourceRange(openingSpan.offset + '<'.length, localName.length);
        var pnode = node as ParsedEmbeddedContentAst;
        var valueToken = pnode.selectorValueToken;
        if (pnode.selectToken != null) {
          attributes.add(new TextAttribute(
            'select',
            pnode.selectToken.offset,
            valueToken?.innerValue?.lexeme,
            valueToken?.innerValue?.offset,
            [],
          ));
        }
      }

      if (closeComplement.isSynthetic) {
        closingSpan = _toSourceRange(node.endToken.end, 0);
        closingNameSpan = closingSpan;
      } else {
        closingSpan = _toSourceRange(closeComplement.beginToken.offset,
            closeComplement.endToken.end - closeComplement.beginToken.offset);
        closingNameSpan =
            new SourceRange(closingSpan.offset + '</'.length, localName.length);
      }

      var ngContent = new ElementInfo(localName, openingSpan, closingSpan,
          openingNameSpan, closingNameSpan, false, attributes, null, parent);
      return ngContent;
    }
    if (node is EmbeddedTemplateAst) {
      String localName = 'template';
      List<AttributeInfo> attributes = _convertAttributes(
        attributes: node.attributes,
        events: node.events,
        properties: node.properties,
        references: node.references,
      );
      final closeComponent = node.closeComplement;
      SourceRange openingSpan;
      SourceRange openingNameSpan;
      SourceRange closingSpan;
      SourceRange closingNameSpan;

      if (node.isSynthetic) {
        openingSpan = _toSourceRange(closeComponent.beginToken.offset, 0);
        openingNameSpan = openingSpan;
      } else {
        openingSpan = _toSourceRange(
            node.beginToken.offset, node.endToken.end - node.beginToken.offset);
        openingNameSpan =
            new SourceRange(openingSpan.offset + '<'.length, localName.length);
      }
      // Check for void element cases (has closing complement)
      if (closeComponent != null) {
        if (closeComponent.isSynthetic) {
          closingSpan = _toSourceRange(node.endToken.end, 0);
          closingNameSpan = closingSpan;
        } else {
          closingSpan = _toSourceRange(closeComponent.beginToken.offset,
              closeComponent.endToken.end - closeComponent.beginToken.offset);
          closingNameSpan = new SourceRange(
              closingSpan.offset + '</'.length, localName.length);
        }
      }

      ElementInfo element = new ElementInfo(
          localName,
          openingSpan,
          closingSpan,
          openingNameSpan,
          closingNameSpan,
          true,
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
      String text = '{{' + node.value + '}}';
      return new TextInfo(
          offset, text, parent, dartParser.findMustaches(text, offset));
    }
    return null;
  }

  List<AttributeInfo> _convertAttributes({
    List<ParsedAttributeAst> attributes: const [],
    List<ParsedBananaAst> bananas: const [],
    List<ParsedEventAst> events: const [],
    List<ParsedPropertyAst> properties: const [],
    List<ParsedReferenceAst> references: const [],
    List<ParsedStarAst> stars: const [],
  }) {
    List<AttributeInfo> returnAttributes = <AttributeInfo>[];

    for (ParsedAttributeAst attribute in attributes) {
      if (attribute.name == 'template') {
        returnAttributes.add(_convertTemplateAttribute(attribute));
      } else {
        String value;
        int valueOffset;
        if (attribute.valueToken != null) {
          value = attribute.valueToken.innerValue.lexeme;
          valueOffset = attribute.valueToken.innerValue.offset;
        }
        returnAttributes.add(new TextAttribute(
          attribute.name,
          attribute.nameOffset,
          value,
          valueOffset,
          dartParser.findMustaches(value, valueOffset),
        ));
      }
    }

    bananas.map(_convertExpressionBoundAttribute).forEach(returnAttributes.add);
    events.map(_convertStatementsBoundAttribute).forEach(returnAttributes.add);
    properties
        .map(_convertExpressionBoundAttribute)
        .forEach(returnAttributes.add);

    for (ParsedReferenceAst reference in references) {
      String value;
      int valueOffset;
      if (reference.valueToken != null) {
        value = reference.valueToken.innerValue.lexeme;
        valueOffset = reference.valueToken.innerValue.offset;
      }
      returnAttributes.add(new TextAttribute(
          reference.prefixToken.lexeme + reference.nameToken.lexeme,
          reference.prefixToken.offset,
          value,
          valueOffset,
          dartParser.findMustaches(value, valueOffset)));
    }

    stars.map(_convertTemplateAttribute).forEach(returnAttributes.add);

    return returnAttributes;
  }

  TemplateAttribute _convertTemplateAttribute(TemplateAst ast) {
    String name;
    int nameOffset;

    String value;
    int valueOffset;

    String origName;
    int origNameOffset;

    var virtualAttributes = [];

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
            (' ' * (ast.valueToken.innerValue.offset - ast.nameToken.end)) +
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

      if (value == null || value.isEmpty) {
        errorListener.onError(new AnalysisError(templateSource, origNameOffset,
            origName.length, AngularWarningCode.EMPTY_BINDING, [origName]));
      } else {
        virtualAttributes =
            dartParser.parseTemplateVirtualAttributes(valueOffset, value);
      }
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
      ParsedEventAst ast) {
    var prefixComponent =
        (ast.prefixToken.errorSynthetic ? '' : ast.prefixToken.lexeme);
    var suffixComponent =
        ((ast.suffixToken == null) || ast.suffixToken.errorSynthetic)
            ? ''
            : ast.suffixToken.lexeme;
    var origName = prefixComponent + ast.name + suffixComponent;
    var origNameOffset = ast.prefixToken.offset;

    var value = ast.value;
    if ((value == null || value.isEmpty) &&
        !ast.prefixToken.errorSynthetic &&
        !ast.suffixToken.errorSynthetic) {
      errorListener.onError(new AnalysisError(templateSource, origNameOffset,
          origName.length, AngularWarningCode.EMPTY_BINDING, [ast.name]));
    }
    var valueOffset = ast.valueOffset;

    var propName = ast.nameToken.lexeme;
    var propNameOffset = ast.nameToken.offset;

    return new StatementsBoundAttribute(
        propName,
        propNameOffset,
        value,
        valueOffset,
        origName,
        origNameOffset,
        dartParser.parseDartStatements(valueOffset, value));
  }

  ExpressionBoundAttribute _convertExpressionBoundAttribute(TemplateAst ast) {
    // Default starting.
    ExpressionBoundType bound = ExpressionBoundType.input;

    var parsed = ast as ParsedDecoratorAst;
    var origName =
        (parsed.prefixToken.errorSynthetic ? '' : parsed.prefixToken.lexeme) +
            parsed.nameToken.lexeme +
            ((parsed.suffixToken == null || parsed.suffixToken.errorSynthetic)
                ? ''
                : parsed.suffixToken.lexeme);
    var origNameOffset = parsed.prefixToken.offset;

    var propName = parsed.nameToken.lexeme;
    var propNameOffset = parsed.nameToken.offset;

    if (ast is ParsedPropertyAst) {
      var name = ast.name;
      if (ast.postfix != null) {
        bool replacePropName = false;
        if (name == 'class') {
          bound = ExpressionBoundType.clazz;
          replacePropName = true;
        } else if (name == 'attr') {
          bound = ExpressionBoundType.attr;
          replacePropName = true;
        } else if (name == 'style') {
          bound = ExpressionBoundType.style;
          replacePropName = true;
        }
        if (replacePropName) {
          propName = ast.postfix + (ast.unit == null ? '' : '.${ast.unit}');
          propNameOffset = parsed.nameToken.offset + name.length + '.'.length;
        }
      }
    } else {
      bound = ExpressionBoundType.twoWay;
    }

    var value = parsed.valueToken?.innerValue?.lexeme;
    if ((value == null || value.isEmpty) &&
        !parsed.prefixToken.errorSynthetic &&
        !parsed.suffixToken.errorSynthetic) {
      errorListener.onError(new AnalysisError(
        templateSource,
        origNameOffset,
        origName.length,
        AngularWarningCode.EMPTY_BINDING,
        [origName],
      ));
    }
    var valueOffset = parsed.valueToken?.innerValue?.offset;

    propName = attrToPropMap[propName] ?? propName;

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
    for (AttributeInfo attribute in attributes) {
      if (attribute is TemplateAttribute) {
        return attribute;
      }
    }
    return null;
  }

  SourceRange _toSourceRange(int offset, int length) {
    return new SourceRange(offset, length);
  }
}

class EmbeddedDartParser {
  final Source templateSource;
  final AnalysisErrorListener errorListener;
  final ErrorReporter errorReporter;

  EmbeddedDartParser(
      this.templateSource, this.errorListener, this.errorReporter);

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
    if (code.trim().isEmpty) {
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
    Parser parser = new NgExprParser(templateSource, errorListener);
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

      // Absolutely no mustaches - simple text.
      if (begin == -1 && end == -1) {
        break;
      }

      if (end == -1) {
        // Begin mustache exists, but no end mustache.
        errorListener.onError(new AnalysisError(templateSource,
            fileOffset + begin, 2, AngularWarningCode.UNTERMINATED_MUSTACHE));
        // Move the cursor ahead and keep looking for more unmatched mustaches.
        textOffset = begin + 2;
        exprBegin = textOffset;
        exprEnd = _startsWithWhitespace(text.substring(exprBegin))
            ? exprBegin
            : text.length;
      } else if (begin == -1 || end < begin) {
        // Both exists, but there is an end before a begin.
        // Example: blah }} {{ mustache ...
        errorListener.onError(new AnalysisError(templateSource,
            fileOffset + end, 2, AngularWarningCode.UNOPENED_MUSTACHE));
        // Move the cursor ahead and keep looking for more unmatched mustaches.
        textOffset = end + 2;
        continue;
      } else if (nextBegin != -1 && nextBegin < end) {
        // Two open mustaches, but both opens are in sequence before an end.
        // Example: {{ blah {{ mustache }}
        errorListener.onError(new AnalysisError(templateSource,
            fileOffset + begin, 2, AngularWarningCode.UNTERMINATED_MUSTACHE));
        // Skip this open mustache, check the next open we found
        textOffset = begin + 2;
        exprBegin = textOffset;
        exprEnd = nextBegin;
      } else {
        // Proper open and close mustache exists and in correct order.
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

      mustaches.add(new Mustache(
        offset,
        length,
        expression,
        fileOffset + exprBegin,
        fileOffset + exprEnd,
      ));
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
      token is KeywordToken && token.keyword.isBuiltInOrPseudo;

  static bool _tokenMatchesIdentifier(Token token) =>
      token.type == TokenType.IDENTIFIER ||
      _tokenMatchesBuiltInIdentifier(token);
}

class IgnorableHtmlInternalError extends StateError {
  IgnorableHtmlInternalError(String msg) : super(msg);
}
