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
import 'package:tuple/tuple.dart';
import 'package:source_span/source_span.dart';

class HtmlTreeConverter {
  final EmbeddedDartParser dartParser;
  final Source templateSource;
  final AnalysisErrorListener errorListener;

  HtmlTreeConverter(this.dartParser, this.templateSource, this.errorListener);

  DocumentInfo convertFromAstList(List<StandaloneTemplateAst> asts) {
    final root = new DocumentInfo();
    if (asts.isEmpty) {
      root.childNodes.add(new TextInfo(0, '', root, []));
    }
    for (final node in asts) {
      final convertedNode = convert(node, parent: root);
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
      final localName = node.name;
      final attributes = _convertAttributes(
        attributes: node.attributes,
        bananas: node.bananas,
        events: node.events,
        properties: node.properties,
        references: node.references,
        stars: node.stars,
      )..sort((a, b) => a.offset.compareTo(b.offset));
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

      final element = new ElementInfo(
        localName,
        openingSpan,
        closingSpan,
        openingNameSpan,
        closingNameSpan,
        attributes,
        findTemplateAttribute(attributes),
        parent,
        isTemplate: false,
      );

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
        final pnode = node as ParsedEmbeddedContentAst;
        final valueToken = pnode.selectorValueToken;
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

      final ngContent = new ElementInfo(
        localName,
        openingSpan,
        closingSpan,
        openingNameSpan,
        closingNameSpan,
        attributes,
        null,
        parent,
        isTemplate: false,
      );

      for (final attribute in attributes) {
        attribute.parent = ngContent;
      }

      return ngContent;
    }
    if (node is EmbeddedTemplateAst) {
      final localName = 'template';
      final attributes = _convertAttributes(
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

      final element = new ElementInfo(
        localName,
        openingSpan,
        closingSpan,
        openingNameSpan,
        closingNameSpan,
        attributes,
        findTemplateAttribute(attributes),
        parent,
        isTemplate: true,
      );

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
    if (node is TextAst) {
      final offset = node.sourceSpan.start.offset;
      final text = node.value;
      return new TextInfo(
          offset, text, parent, dartParser.findMustaches(text, offset));
    }
    if (node is InterpolationAst) {
      final offset = node.sourceSpan.start.offset;
      final text = '{{${node.value}}}';
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
    final returnAttributes = <AttributeInfo>[];

    for (final attribute in attributes) {
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

    for (final reference in references) {
      String value;
      int valueOffset;
      if (reference.valueToken != null) {
        value = reference.valueToken.innerValue.lexeme;
        valueOffset = reference.valueToken.innerValue.offset;
      }
      returnAttributes.add(new TextAttribute(
          '${reference.prefixToken.lexeme}${reference.nameToken.lexeme}',
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
    String prefix;
    int nameOffset;

    String value;
    int valueOffset;

    String origName;
    int origNameOffset;

    var virtualAttributes = [];

    if (ast is ParsedStarAst) {
      value = ast.value;
      valueOffset = ast.valueOffset;

      origName = '${ast.prefixToken.lexeme}${ast.nameToken.lexeme}';
      origNameOffset = ast.prefixToken.offset;

      name = ast.nameToken.lexeme;
      nameOffset = ast.nameToken.offset;

      String fullAstName;
      if (value != null) {
        final whitespacePad =
            ' ' * (ast.valueToken.innerValue.offset - ast.nameToken.end);
        fullAstName = "${ast.name}$whitespacePad${value ?? ''}";
      } else {
        fullAstName = '${ast.name} ';
      }

      final tuple =
          dartParser.parseTemplateVirtualAttributes(nameOffset, fullAstName);
      virtualAttributes = tuple.item2;
      prefix = tuple.item1;
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
      ParsedEventAst ast) {
    final prefixComponent =
        (ast.prefixToken.errorSynthetic ? '' : ast.prefixToken.lexeme);
    final suffixComponent =
        ((ast.suffixToken == null) || ast.suffixToken.errorSynthetic)
            ? ''
            : ast.suffixToken.lexeme;
    final origName = '$prefixComponent${ast.name}$suffixComponent';
    final origNameOffset = ast.prefixToken.offset;

    final value = ast.value;
    if ((value == null || value.isEmpty) &&
        !ast.prefixToken.errorSynthetic &&
        !ast.suffixToken.errorSynthetic) {
      errorListener.onError(new AnalysisError(templateSource, origNameOffset,
          origName.length, AngularWarningCode.EMPTY_BINDING, [ast.name]));
    }
    final valueOffset = ast.valueOffset;

    final propName = ast.nameToken.lexeme;
    final propNameOffset = ast.nameToken.offset;

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
    var bound = ExpressionBoundType.input;

    final parsed = ast as ParsedDecoratorAst;
    String origName;
    {
      final _prefix =
          parsed.prefixToken.errorSynthetic ? '' : parsed.prefixToken.lexeme;
      final _suffix =
          (parsed.suffixToken == null || parsed.suffixToken.errorSynthetic)
              ? ''
              : parsed.suffixToken.lexeme;
      origName = '$_prefix${parsed.nameToken.lexeme}$_suffix';
    }
    final origNameOffset = parsed.prefixToken.offset;

    var propName = parsed.nameToken.lexeme;
    var propNameOffset = parsed.nameToken.offset;

    if (ast is ParsedPropertyAst) {
      final name = ast.name;
      if (ast.postfix != null) {
        var replacePropName = false;
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
          final _unitName = ast.unit == null ? '' : '.${ast.unit}';
          propName = '${ast.postfix}$_unitName';
          propNameOffset = parsed.nameToken.offset + name.length + '.'.length;
        }
      }
    } else {
      bound = ExpressionBoundType.twoWay;
    }

    final value = parsed.valueToken?.innerValue?.lexeme;
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
    final valueOffset = parsed.valueToken?.innerValue?.offset;

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

  List<NodeInfo> _convertChildren(
      StandaloneTemplateAst node, ElementInfo parent) {
    final children = <NodeInfo>[];
    for (final child in node.childNodes) {
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
    for (final attribute in attributes) {
      if (attribute is TemplateAttribute) {
        return attribute;
      }
    }
    return null;
  }

  SourceRange _toSourceRange(int offset, int length) =>
      new SourceRange(offset, length);
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
    if (code.trim().isEmpty) {
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
        // Check for empty `of` and `trackBy` bindings, but NOT empty `ngIf`!
        // NgFor (and other star directives) often result in a harmless, empty
        // `[ngFor]` as a first attr. Don't flag it unless it matches an input
        // (like `ngIf` does), which is checked by [SingleScopeResolver].
        if (attributes.isNotEmpty) {
          errorReporter.reportErrorForOffset(AngularWarningCode.EMPTY_BINDING,
              originalNameOffset, originalName.length);
        }

        attributes.add(new ExpressionBoundAttribute(key, keyOffset, null, null,
            originalName, originalNameOffset, null, ExpressionBoundType.input));
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
