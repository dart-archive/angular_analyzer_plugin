import 'dart:math';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/dart/ast/token.dart' hide SimpleToken;
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/errors.dart';
import 'package:angular_analyzer_plugin/src/ignoring_error_listener.dart';
import 'package:angular_analyzer_plugin/src/ng_expr_parser.dart';
import 'package:angular_analyzer_plugin/src/strings.dart';
import 'package:angular_analyzer_plugin/src/tuple.dart';
import 'package:angular_ast/angular_ast.dart';
import 'package:meta/meta.dart';

class EmbeddedDartParser {
  final Source templateSource;
  final AnalysisErrorListener errorListener;
  final ErrorReporter errorReporter;

  EmbeddedDartParser(
      this.templateSource, this.errorListener, this.errorReporter);

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
        // The tokenizer isn't perfect always. Ensure [end] <= [code.length].
        final end = min(token.offset - offset, code.length);
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
        // A special kind of TextAttr that signifies its special.
        final binding = new EmptyStarBinding(
            key, keyOffset, originalName, originalNameOffset,
            isPrefix: attributes.isEmpty);

        attributes.add(binding);

        // Check for empty `of` and `trackBy` bindings, but NOT empty `ngIf`!
        // NgFor (and other star directives) often result in a harmless, empty
        // first attr. Don't flag it unless it matches an input (like `ngIf`
        // does), which is checked by [SingleScopeResolver].
        if (!binding.isPrefix) {
          errorReporter.reportErrorForOffset(AngularWarningCode.EMPTY_BINDING,
              originalNameOffset, originalName.length, [originalName]);
        }
      }
    }

    return new Tuple2(prefix, attributes);
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
    // Warning: we lexically and unintelligently "accept" `===` for now by
    // replacing it with `==`. This is actually OK for us since we can butcher
    // string literal contents fine, and it won't affect analysis.
    final noTripleEquals =
        code.replaceAll('===', '== ').replaceAll('!==', '!= ');

    // ignore: prefer_interpolation_to_compose_strings
    final text = ' ' * offset + noTripleEquals;
    final reader = new CharSequenceReader(text);
    final scanner = new Scanner(templateSource, reader, errorListener);
    return scanner.tokenize();
  }

  bool _startsWithWhitespace(String string) =>
      // trim returns the original string when no changes were made
      !identical(string.trimLeft(), string);

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

class HtmlTreeConverter {
  final EmbeddedDartParser dartParser;
  final Source templateSource;
  final AnalysisErrorListener errorListener;

  HtmlTreeConverter(this.dartParser, this.templateSource, this.errorListener);

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
      SourceRange openingNameSpan;

      if (!node.isSynthetic) {
        openingNameSpan = new SourceRange(
            (node as ParsedElementAst).identifierToken.offset,
            (node as ParsedElementAst).identifierToken.lexeme.length);
      }

      return _elementInfoFromNodeAndCloseComplement(
        node,
        localName,
        attributes,
        node.closeComplement,
        parent,
        openingNameSpanOverride: openingNameSpan,
      );
    } else if (node is ContainerAst) {
      final attributes = _convertAttributes(
        stars: node.stars,
      )..sort((a, b) => a.offset.compareTo(b.offset));

      return _elementInfoFromNodeAndCloseComplement(
        node,
        'ng-container',
        attributes,
        node.closeComplement,
        parent,
      );
    } else if (node is EmbeddedContentAst) {
      final attributes = <AttributeInfo>[];
      SourceRange openingNameSpan;

      if (!node.isSynthetic) {
        openingNameSpan = new SourceRange(
            node.beginToken.offset + '<'.length, 'ng-content'.length);
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

      return _elementInfoFromNodeAndCloseComplement(
        node,
        'ng-content',
        attributes,
        node.closeComplement,
        parent,
        openingNameSpanOverride: openingNameSpan,
      );
    } else if (node is EmbeddedTemplateAst) {
      final attributes = _convertAttributes(
        attributes: node.attributes,
        events: node.events,
        properties: node.properties,
        references: node.references,
        letBindings: node.letBindings,
      );

      return _elementInfoFromNodeAndCloseComplement(
        node,
        'template',
        attributes,
        node.closeComplement,
        parent,
      );
    } else if (node is TextAst) {
      final offset = node.sourceSpan.start.offset;
      final text = node.value;
      return new TextInfo(
          offset, text, parent, dartParser.findMustaches(text, offset));
    } else if (node is InterpolationAst) {
      final offset = node.sourceSpan.start.offset;
      final text = '{{${node.value}}}';
      return new TextInfo(
          offset, text, parent, dartParser.findMustaches(text, offset));
    } else {
      assert(
          node is CommentAst, 'Unknown node type ${node.runtimeType} ($node)');
    }
    return null;
  }

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

  TemplateAttribute findTemplateAttribute(List<AttributeInfo> attributes) {
    for (final attribute in attributes) {
      if (attribute is TemplateAttribute) {
        return attribute;
      }
    }
    return null;
  }

  List<AttributeInfo> _convertAttributes({
    List<AttributeAst> attributes: const [],
    List<BananaAst> bananas: const [],
    List<EventAst> events: const [],
    List<PropertyAst> properties: const [],
    List<ReferenceAst> references: const [],
    List<StarAst> stars: const [],
    List<LetBindingAst> letBindings: const [],
  }) {
    final returnAttributes = <AttributeInfo>[];

    for (final attribute in attributes) {
      if (attribute is ParsedAttributeAst) {
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
    }

    bananas.map(_convertExpressionBoundAttribute).forEach(returnAttributes.add);
    events.map(_convertStatementsBoundAttribute).forEach(returnAttributes.add);
    properties
        .map(_convertExpressionBoundAttribute)
        .forEach(returnAttributes.add);

    for (final reference in references) {
      if (reference is ParsedReferenceAst) {
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
            valueOffset, const <Mustache>[]));
      }
    }

    // Guaranteed to be empty for non-template elements.
    for (final letBinding in letBindings) {
      if (letBinding is ParsedLetBindingAst) {
        String value;
        int valueOffset;
        if (letBinding.valueToken != null) {
          value = letBinding.valueToken.innerValue.lexeme;
          valueOffset = letBinding.valueToken.innerValue.offset;
        }
        returnAttributes.add(new TextAttribute(
            '${letBinding.prefixToken.lexeme}${letBinding.nameToken.lexeme}',
            letBinding.prefixToken.offset,
            value,
            valueOffset, <Mustache>[]));
      }
    }

    stars.map(_convertTemplateAttribute).forEach(returnAttributes.add);

    return returnAttributes;
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

  ExpressionBoundAttribute _convertExpressionBoundAttribute(TemplateAst ast) {
    // Default starting.
    var bound = ExpressionBoundType.input;

    final parsed = ast as ParsedDecoratorAst;
    final suffixToken = parsed.suffixToken;
    final nameToken = parsed.nameToken;
    final prefixToken = parsed.prefixToken;

    String origName;
    {
      final _prefix = prefixToken.errorSynthetic ? '' : prefixToken.lexeme;
      final _suffix = (suffixToken == null || suffixToken.errorSynthetic)
          ? ''
          : suffixToken.lexeme;
      origName = '$_prefix${nameToken.lexeme}$_suffix';
    }
    final origNameOffset = prefixToken.offset;

    var propName = nameToken.lexeme;
    var propNameOffset = nameToken.offset;

    if (ast is ParsedPropertyAst) {
      // For some inputs, like `[class.foo]`, the [ast.name] here is actually
      // not a name, but a prefix. If so, use the [ast.postfix] as the [name] of
      // the [ExpressionBoundAttribute] we're creating here, by changing
      // [propName].
      final nameOrPrefix = ast.name;

      if (ast.postfix != null) {
        var usePostfixForName = false;
        var preserveUnitInName = false;

        if (nameOrPrefix == 'class') {
          bound = ExpressionBoundType.clazz;
          usePostfixForName = true;
          preserveUnitInName = true;
        } else if (nameOrPrefix == 'attr') {
          if (ast.unit == 'if') {
            bound = ExpressionBoundType.attrIf;
          } else {
            bound = ExpressionBoundType.attr;
          }
          usePostfixForName = true;
        } else if (nameOrPrefix == 'style') {
          bound = ExpressionBoundType.style;
          usePostfixForName = true;
          preserveUnitInName = ast.unit != null;
        }

        if (usePostfixForName) {
          final _unitName =
              preserveUnitInName && ast.unit != null ? '.${ast.unit}' : '';
          propName = '${ast.postfix}$_unitName';
          propNameOffset = nameToken.offset + ast.name.length + '.'.length;
        } else {
          assert(!preserveUnitInName);
        }
      }
    } else {
      bound = ExpressionBoundType.twoWay;
    }

    final value = parsed.valueToken?.innerValue?.lexeme;
    if ((value == null || value.isEmpty) &&
        !prefixToken.errorSynthetic &&
        (suffixToken == null ? true : !suffixToken.errorSynthetic)) {
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

  StatementsBoundAttribute _convertStatementsBoundAttribute(EventAst eventAst) {
    final ast = eventAst as ParsedEventAst;
    final prefixToken = ast.prefixToken;
    final nameToken = ast.nameToken;
    final suffixToken = ast.suffixToken;

    final prefixComponent =
        (prefixToken.errorSynthetic ? '' : prefixToken.lexeme);
    final suffixComponent =
        ((suffixToken == null) || suffixToken.errorSynthetic)
            ? ''
            : suffixToken.lexeme;
    final origName = '$prefixComponent${ast.name}$suffixComponent';
    final origNameOffset = prefixToken.offset;

    final value = ast.value;
    if ((value == null || value.isEmpty) &&
        !prefixToken.errorSynthetic &&
        (suffixToken == null ? true : !suffixToken.errorSynthetic)) {
      errorListener.onError(new AnalysisError(templateSource, origNameOffset,
          origName.length, AngularWarningCode.EMPTY_BINDING, [ast.name]));
    }
    final valueOffset = ast.valueOffset;

    final propName = ast.name;
    final propNameOffset = nameToken.offset;

    return new StatementsBoundAttribute(
        propName,
        propNameOffset,
        value,
        valueOffset,
        origName,
        origNameOffset,
        ast.reductions,
        dartParser.parseDartStatements(valueOffset, value));
  }

  TemplateAttribute _convertTemplateAttribute(TemplateAst ast) {
    String name;
    String prefix;
    int nameOffset;

    String value;
    int valueOffset;

    String origName;
    int origNameOffset;

    var virtualAttributes = <AttributeInfo>[];

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

  ElementInfo _elementInfoFromNodeAndCloseComplement(
      StandaloneTemplateAst node,
      String tagName,
      List<AttributeInfo> attributes,
      CloseElementAst closeComplement,
      ElementInfo parent,
      {SourceRange openingNameSpanOverride}) {
    final isTemplate = tagName == 'template';
    SourceRange openingSpan;
    SourceRange openingNameSpan;
    SourceRange closingSpan;
    SourceRange closingNameSpan;

    openingNameSpan = openingNameSpanOverride;

    if (node.isSynthetic) {
      openingSpan = _toSourceRange(closeComplement.beginToken.offset, 0);
      openingNameSpan ??= openingSpan;
    } else {
      openingSpan = _toSourceRange(
          node.beginToken.offset, node.endToken.end - node.beginToken.offset);
      openingNameSpan ??=
          new SourceRange(node.beginToken.offset + '<'.length, tagName.length);
    }

    if (closeComplement != null) {
      if (!closeComplement.isSynthetic) {
        closingSpan = _toSourceRange(closeComplement.beginToken.offset,
            closeComplement.endToken.end - closeComplement.beginToken.offset);
        closingNameSpan =
            new SourceRange(closingSpan.offset + '</'.length, tagName.length);
      } else if (isTemplate) {
        // Close range for <template /> tags
        closingSpan = _toSourceRange(node.endToken.end, 0);
        closingNameSpan = closingSpan;
      }
    }

    final element = new ElementInfo(
      tagName,
      openingSpan,
      closingSpan,
      openingNameSpan,
      closingNameSpan,
      attributes,
      findTemplateAttribute(attributes),
      parent,
      isTemplate: isTemplate,
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

  SourceRange _toSourceRange(int offset, int length) =>
      new SourceRange(offset, length);
}

class IgnorableHtmlInternalException implements Exception {
  String msg;
  IgnorableHtmlInternalException(this.msg);

  @override
  String toString() => "IgnorableHtmlInternalException: $msg";
}
