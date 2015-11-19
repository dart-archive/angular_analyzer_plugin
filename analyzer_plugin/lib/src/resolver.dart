library angular2.src.analysis.analyzer_plugin.src.resolver;

import 'dart:collection';

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
import 'package:angular2_analyzer_plugin/src/strings.dart';
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
 * Information about an attribute.
 */
class AttributeInfo {
  final String name;
  final int nameOffset;

  final String inputName;
  final int inputNameOffset;
  final int inputNameLength;
  final bound;

  final String value;
  final int valueOffset;

  Expression expression;

  AttributeInfo(
      this.name,
      this.nameOffset,
      this.inputName,
      this.inputNameOffset,
      this.inputNameLength,
      this.bound,
      this.value,
      this.valueOffset);

  int get valueLength => value != null ? value.length : 0;

  @override
  String toString() {
    return '([$name, $nameOffset],'
        '[$inputName, $inputNameOffset, $inputNameLength, $bound],'
        '[$value, $valueOffset, $valueLength], [$expression])';
  }
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
 * An element in an HTML tree.
 */
class ElementInfo extends NodeInfo {
  final String localName;
  final SourceRange openingSpan;
  final SourceRange closingSpan;
  final SourceRange openingNameSpan;
  final SourceRange closingNameSpan;
  final bool isTemplate;
  final bool hasTemplateAttribute;
  final List<AttributeInfo> attributes;

  ElementInfo(
      this.localName,
      this.openingSpan,
      this.closingSpan,
      this.openingNameSpan,
      this.closingNameSpan,
      this.isTemplate,
      this.hasTemplateAttribute,
      this.attributes);

  bool get isOrHasTemplateAttribute => isTemplate || hasTemplateAttribute;
}

/**
 * The implementation of [ElementView] using [AttributeInfo]s.
 */
class ElementViewImpl implements ElementView {
  @override
  Map<String, SourceRange> attributeNameSpans = <String, SourceRange>{};

  @override
  Map<String, SourceRange> attributeValueSpans = <String, SourceRange>{};

  @override
  Map<String, String> attributes = <String, String>{};

  @override
  SourceRange closingSpan;

  @override
  SourceRange closingNameSpan;

  @override
  String localName;

  @override
  SourceRange openingSpan;

  @override
  SourceRange openingNameSpan;

  ElementViewImpl(List<AttributeInfo> attributeInfoList, ElementInfo element) {
    for (AttributeInfo attribute in attributeInfoList) {
      String name = attribute.inputName;
      attributeNameSpans[name] =
          new SourceRange(attribute.inputNameOffset, attribute.inputNameLength);
      if (attribute.value != null) {
        attributeValueSpans[name] =
            new SourceRange(attribute.valueOffset, attribute.valueLength);
      }
      attributes[name] = attribute.value;
    }
    if (element != null) {
      localName = element.localName;
      openingSpan = element.openingSpan;
      closingSpan = element.closingSpan;
      openingNameSpan = element.openingNameSpan;
      closingNameSpan = element.closingNameSpan;
    }
  }
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
        new HtmlTemplate(view, _firstElement(document), view.templateUriSource);
    view.template = template;
    new TemplateResolver(typeProvider, errorListener).resolve(template);
    return template;
  }
}

class HtmlTreeConverter {
  NodeInfo convert(html.Node node) {
    if (node is html.Element) {
      String localName = node.localName;
      List<AttributeInfo> attributes = _convertAttributes(node);
      bool isTemplate = localName == 'template';
      bool hasTemplateAttribute = _hasTemplateAttribute(attributes);
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
          hasTemplateAttribute,
          attributes);
      List<NodeInfo> children = _convertChildren(node);
      element.children.addAll(children);
      return element;
    }
    if (node is html.Text) {
      int offset = node.sourceSpan.start.offset;
      String text = node.text;
      return new TextInfo(offset, text);
    }
    return null;
  }

  List<AttributeInfo> _convertAttributes(html.Element element) {
    List<AttributeInfo> attributes = <AttributeInfo>[];
    element.attributes.forEach((key, String value) {
      if (key is String) {
        String name = key.toLowerCase();
        int nameOffset = element.attributeSpans[name].start.offset;
        // name
        bool bound = false;
        String propName = name;
        int propNameOffset = nameOffset;
        if (propName.startsWith('[') && propName.endsWith(']')) {
          propNameOffset += 1;
          propName = propName.substring(1, propName.length - 1);
          bound = true;
        } else if (propName.startsWith('bind-')) {
          int bindLength = 'bind-'.length;
          propNameOffset += bindLength;
          propName = propName.substring(bindLength);
          bound = true;
        } else if (propName.startsWith('on-')) {
          int bindLength = 'on-'.length;
          propNameOffset += bindLength;
          propName = propName.substring(bindLength);
          bound = true;
        } else if (propName.startsWith('(') && propName.endsWith(')')) {
          propNameOffset += 1;
          propName = propName.substring(1, propName.length - 1);
          bound = true;
        }
        int propNameLength = propName != null ? propName.length : null;
        // value
        int valueOffset;
        {
          SourceSpan span = element.attributeValueSpans[name];
          if (span != null) {
            valueOffset = span.start.offset;
          } else {
            value = null;
          }
        }
        // add
        attributes.add(new AttributeInfo(name, nameOffset, propName,
            propNameOffset, propNameLength, bound, value, valueOffset));
      }
    });
    return attributes;
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

  bool _hasTemplateAttribute(List<AttributeInfo> attributes) {
    for (AttributeInfo attribute in attributes) {
      if (attribute.name == 'template' || attribute.name.startsWith('*')) {
        return true;
      }
    }
    return false;
  }

  SourceRange _toSourceRange(SourceSpan span) {
    if (span != null) {
      return new SourceRange(span.start.offset, span.length);
    }
    return null;
  }
}

/**
 * A variable defined by a [AbstractDirective].
 */
class InternalVariable {
  final String name;
  final AngularElement element;
  final DartType type;

  InternalVariable(this.name, this.element, this.type);
}

/**
 * A node in an HTML tree.
 */
class NodeInfo {
  final List<NodeInfo> children = <NodeInfo>[];
}

/// [TemplateResolver]s resolve [Template]s.
class TemplateResolver {
  final TypeProvider typeProvider;
  final AnalysisErrorListener errorListener;

  Template template;
  View view;
  Source templateSource;
  ErrorReporter errorReporter;

  CompilationUnitElementImpl htmlCompilationUnitElement;
  ClassElementImpl htmlClassElement;
  MethodElementImpl htmlMethodElement;

  /**
   * The map from names of bound attributes to resolve expressions.
   */
  Map<String, Expression> currentNodeAttributeExpressions =
      new HashMap<String, Expression>();

  /**
   * The full map of names to internal variables in the current node.
   */
  Map<String, InternalVariable> internalVariables =
      new HashMap<String, InternalVariable>();

  /**
   * The full map of names to local variables in the current node.
   */
  Map<String, LocalVariableElement> localVariables =
      new HashMap<String, LocalVariableElement>();

  TemplateResolver(this.typeProvider, this.errorListener);

  void resolve(Template template) {
    this.template = template;
    this.view = template.view;
    this.templateSource = view.templateSource;
    this.errorReporter = new ErrorReporter(errorListener, templateSource);
    ElementInfo root = new HtmlTreeConverter().convert(template.element);
    _resolveElement(root);
  }

  void _defineBuiltInVariable(
      Scope nameScope, DartType type, String name, int offset) {
    // TODO(scheglov) remove this
    LocalVariableElement localVariable =
        _newLocalVariableElement(offset, name, type);
    nameScope.define(localVariable);
  }

  /**
   * Defines type of variables defined by the given [directive].
   */
  void _defineDirectiveVariables(
      List<AttributeInfo> attributes, AbstractDirective directive) {
    // add "exportAs"
    {
      AngularElement exportAs = directive.exportAs;
      if (exportAs != null) {
        String name = exportAs.name;
        InterfaceType type = directive.classElement.type;
        internalVariables[name] = new InternalVariable(name, exportAs, type);
      }
    }
    // add "$implicit
    {
      ClassElement classElement = directive.classElement;
      internalVariables[r'$implicit'] = new InternalVariable(
          r'$implicit', new DartElement(classElement), classElement.type);
    }
    // TODO(scheglov) Once Angular has a way to describe variables, reimplement
    // https://github.com/angular/angular/issues/4850
    if (directive.classElement.displayName == 'NgFor') {
      internalVariables['index'] = new InternalVariable('index',
          new DartElement(directive.classElement), typeProvider.intType);
      for (AttributeInfo attribute in attributes) {
        if (attribute.inputName == 'ng-for-of' &&
            attribute.expression != null) {
          DartType itemType = _getIterableItemType(attribute.expression);
          internalVariables[r'$implicit'] = new InternalVariable(
              r'$implicit', new DartElement(directive.classElement), itemType);
        }
      }
    }
  }

  /**
   * Define new local variables into [localVariables] for `#name` attributes.
   */
  void _defineVariablesForAttributes(List<AttributeInfo> attributes) {
    for (AttributeInfo attribute in attributes) {
      int offset = attribute.nameOffset;
      // prepare name
      String attributeName = attribute.name;
      if (attributeName.startsWith('#')) {
        attributeName = attributeName.substring(1);
        String localVariableName = _getDartNameForAttribute(attributeName);
        // prepare internal variable name
        String internalVarName = attribute.value;
        if (internalVarName == null) {
          internalVarName = r'$implicit';
        }
        // maybe an internal variable reference
        DartType type;
        InternalVariable internalVar = internalVariables[internalVarName];
        if (internalVar != null) {
          type = internalVar.type;
          // add internal variable reference
          if (attribute.value != null) {
            template.addRange(
                new SourceRange(attribute.valueOffset, attribute.valueLength),
                internalVar.element);
          }
        }
        // must be the element reference
        if (attribute.value == null && type == null) {
          type = typeProvider.dynamicType;
        }
        // add a new local variable with type
        if (type != null) {
          LocalVariableElement localVariable =
              _newLocalVariableElement(offset + 1, localVariableName, type);
          localVariables[localVariableName] = localVariable;
          // add local declaration
          template.addRange(
              new SourceRange(
                  localVariable.nameOffset, localVariable.nameLength),
              new DartElement(localVariable));
        }
      }
    }
  }

  DartType _getIterableItemType(Expression expression) {
    DartType itemsType = expression.bestType;
    if (itemsType is InterfaceType) {
      DartType iteratorType = _lookupGetterReturnType(itemsType, 'iterator');
      if (iteratorType is InterfaceType) {
        DartType currentType = _lookupGetterReturnType(iteratorType, 'current');
        if (currentType != null) {
          return currentType;
        }
      }
    }
    return typeProvider.dynamicType;
  }

  /**
   * Return the return type of the executable element with the given [name].
   * May return `null` if the [type] does not define one.
   */
  DartType _lookupGetterReturnType(InterfaceType type, String name) {
    return type.lookUpInheritedGetter(name)?.returnType;
  }

  LocalVariableElement _newLocalVariableElement(
      int offset, String name, DartType type) {
    // ensure artificial Dart elements in the template source
    if (htmlMethodElement == null) {
      htmlCompilationUnitElement =
          new CompilationUnitElementImpl(templateSource.fullName);
      htmlCompilationUnitElement.source = templateSource;
      htmlClassElement = new ClassElementImpl('AngularTemplateClass', -1);
      htmlCompilationUnitElement.types = <ClassElement>[htmlClassElement];
      htmlMethodElement = new MethodElementImpl('angularTemplateMethod', -1);
      htmlClassElement.methods = <MethodElement>[htmlMethodElement];
    }
    // add a new local variable
    LocalVariableElementImpl localVariable =
        new LocalVariableElementImpl(name, offset);
    localVariable.nameLength;
    localVariable.type = type;
    htmlMethodElement.encloseElement(localVariable);
    return localVariable;
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
    Parser parser = new Parser(templateSource, errorListener);
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

  void _reportErrorForRange(SourceRange range, ErrorCode errorCode,
      [List<Object> arguments]) {
    errorListener.onError(new AnalysisError(
        templateSource, range.offset, range.length, errorCode, arguments));
  }

  /// Resolve [attributes] names to inputs of [directive].
  void _resolveAttributeNames(
      List<AttributeInfo> attributes, AbstractDirective directive) {
    for (AttributeInfo attribute in attributes) {
      for (InputElement input in directive.inputs) {
        if (attribute.inputName == input.name) {
          SourceRange range = new SourceRange(
              attribute.inputNameOffset, attribute.inputNameLength);
          template.addRange(range, input);
        }
      }
    }
  }

  /**
   * Resolve values of [attributes].
   */
  void _resolveAttributeValues(List<AttributeInfo> attributes) {
    for (AttributeInfo attribute in attributes) {
      int valueOffset = attribute.valueOffset;
      String value = attribute.value;
      // already handled
      if (attribute.name == 'template' || attribute.name.startsWith('*')) {
        continue;
      }
      // bound
      if (attribute.bound) {
        Expression expression = attribute.expression;
        if (expression == null) {
          expression = _resolveDartExpressionAt(valueOffset, value);
          attribute.expression = expression;
        }
        if (expression != null) {
          _recordExpressionResolvedRanges(expression);
        }
        continue;
      }
      // text interpolations
      if (value != null) {
        _resolveTextExpressions(valueOffset, value);
      }
    }
  }

  /**
   * Resolve the given [expression] and report errors.
   */
  void _resolveDartExpression(Expression expression) {
    ClassElement classElement = view.classElement;
    LibraryElement library = classElement.library;
    ResolverVisitor resolver = new ResolverVisitor(
        library, templateSource, typeProvider, errorListener);
    // fill the name scope
    ClassScope classScope = new ClassScope(resolver.nameScope, classElement);
    EnclosedScope localScope = new EnclosedScope(classScope);
    resolver.nameScope = localScope;
    resolver.enclosingClass = classElement;
    localVariables.values.forEach(localScope.define);
    // TODO(scheglov) hack, use actual variables
    _defineBuiltInVariable(localScope, typeProvider.dynamicType, r'$event', -1);
    // do resolve
    expression.accept(resolver);
    // verify
    ErrorVerifier verifier = new ErrorVerifier(errorReporter, library,
        typeProvider, new InheritanceManager(library), false);
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

  /// Resolve the given [element].
  void _resolveElement(ElementInfo element) {
    List<ElementInfo> templateElements = <ElementInfo>[];
    if (element == null) {
      return;
    }
    // apply template attributes
    Map<String, InternalVariable> oldInternalVariables = internalVariables;
    Map<String, LocalVariableElement> oldLocalVariables = localVariables;
    internalVariables = new HashMap.from(internalVariables);
    localVariables = new HashMap.from(localVariables);
    try {
      // process template attributes
      for (AttributeInfo attribute in element.attributes) {
        if (attribute.name == 'template') {
          _resolveTemplateAttribute(attribute.valueOffset, attribute.value);
        }
        if (attribute.name.startsWith('*')) {
          int nameOffset = attribute.nameOffset + '*'.length;
          int nameEnd = attribute.nameOffset + attribute.name.length;
          int valueOffset = attribute.valueOffset;
          String key = attribute.name.substring(1);
          String code = valueOffset != null
              ? key + ' ' * (valueOffset - nameEnd) + attribute.value
              : key;
          _resolveTemplateAttribute(nameOffset, code);
        }
      }
      // process all non-template nodes
      _resolveNodeNames(element, true, templateElements);
      _resolveNodeExpressions(element, true);
      // process templates with their sub-trees
      for (ElementInfo templateElement in templateElements) {
        _resolveElement(templateElement);
      }
    } finally {
      internalVariables = oldInternalVariables;
      localVariables = oldLocalVariables;
    }
  }

  /// Resolve the given Angular [code] at the given [offset].
  /// Record [ResolvedRange]s.
  Expression _resolveExpression(int offset, String code) {
    Expression expression = _resolveDartExpressionAt(offset, code);
    _recordExpressionResolvedRanges(expression);
    return expression;
  }

  _resolveNodeExpressions(NodeInfo node, bool enterTemplate) {
    if (node is ElementInfo) {
      if (node.isTemplate) {
        _resolveAttributeValues(node.attributes);
      }
      if (!enterTemplate && node.isOrHasTemplateAttribute) {
        return;
      }
      if (!node.isTemplate) {
        _resolveAttributeValues(node.attributes);
      }
    }
    if (node is TextInfo) {
      _resolveTextExpressions(node.offset, node.text);
    }
    for (NodeInfo child in node.children) {
      _resolveNodeExpressions(child, false);
    }
  }

  _resolveNodeNames(
      NodeInfo node, bool enterTemplate, List<ElementInfo> templateElements) {
    if (node is ElementInfo) {
      // skip template
      if (!enterTemplate && node.isOrHasTemplateAttribute) {
        templateElements.add(node);
        return;
      }
      // apply directives
      bool tagIsStandard = _isStandardTagName(node.localName);
      bool tagIsResolved = false;
      ElementView elementView = new ElementViewImpl(node.attributes, node);
      for (AbstractDirective directive in view.directives) {
        Selector selector = directive.selector;
        if (selector.match(elementView, template)) {
          if (selector is ElementNameSelector) {
            tagIsResolved = true;
          }
          _resolveAttributeNames(node.attributes, directive);
          _defineDirectiveVariables(node.attributes, directive);
        }
      }
      if (!tagIsStandard && !tagIsResolved) {
        _reportErrorForRange(node.openingNameSpan,
            AngularWarningCode.UNRESOLVED_TAG, [node.localName]);
      }
      // define local variables
      _defineVariablesForAttributes(node.attributes);
    }
    // process children
    for (NodeInfo child in node.children) {
      _resolveNodeNames(child, false, templateElements);
    }
  }

  /**
   * Resolve the given `template` attribute [code] at [offset].
   */
  void _resolveTemplateAttribute(int offset, String code) {
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
        token = token.next;
        // get the local variable name
        if (token.type != TokenType.IDENTIFIER) {
          errorReporter.reportErrorForToken(
              AngularWarningCode.EXPECTED_IDENTIFIER, token);
          return;
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
          if (token.type != TokenType.IDENTIFIER) {
            errorReporter.reportErrorForToken(
                AngularWarningCode.EXPECTED_IDENTIFIER, token);
            return;
          }
          internalVarOffset = token.offset;
          internalVarName = token.lexeme;
          token = token.next;
        }
        // declare the local variable
        attributes.add(new AttributeInfo('#$localVarName', localVarOffset - 1,
            null, -1, -1, false, internalVarName, internalVarOffset));
        continue;
      }
      // key
      int keyOffset = token.offset;
      int keyLength;
      String key = null;
      if (token.type == TokenType.KEYWORD ||
          token.type == TokenType.IDENTIFIER) {
        // scan for a full attribute name
        key = '';
        int lastEnd = token.offset;
        while (token.offset == lastEnd &&
            (token.type == TokenType.KEYWORD ||
                token.type == TokenType.IDENTIFIER ||
                token.type == TokenType.MINUS)) {
          key += token.lexeme;
          lastEnd = token.end;
          token = token.next;
        }
        // add the prefix
        keyLength = key.length;
        if (prefix == null) {
          prefix = key;
        } else {
          key = '$prefix-$key';
        }
      } else {
        errorReporter.reportErrorForToken(
            AngularWarningCode.EXPECTED_IDENTIFIER, token);
        return;
      }
      // skip optional ':' or '='
      if (token.type == TokenType.COLON || token.type == TokenType.EQ) {
        token = token.next;
      }
      // expression
      Expression expression;
      if (token.type != TokenType.EOF && !_isTemplateVarBeginToken(token)) {
        expression = _parseDartExpressionAtToken(token);
        _resolveDartExpression(expression);
        token = expression.endToken.next;
      }
      // add the attribute to resolve to an input
      AttributeInfo attributeInfo = new AttributeInfo(key, keyOffset, key,
          keyOffset, keyLength, expression != null, 'some-value', -1);
      attributeInfo.expression = expression;
      attributes.add(attributeInfo);
    }
    // match directives
    ElementView elementView = new ElementViewImpl(attributes, null);
    for (AbstractDirective directive in view.directives) {
      if (directive.selector.match(elementView, template)) {
        _defineDirectiveVariables(attributes, directive);
        _defineVariablesForAttributes(attributes);
        _resolveAttributeNames(attributes, directive);
        break;
      }
    }
    _resolveAttributeValues(attributes);
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
        errorListener.onError(new AnalysisError(templateSource, offset + begin,
            2, AngularWarningCode.UNTERMINATED_MUSTACHE));
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
    Scanner scanner = new Scanner(templateSource, reader, errorListener);
    return scanner.tokenize();
  }

  static String _getDartNameForAttribute(String attributeName) {
    List<String> parts = attributeName.split('-');
    StringBuffer sb = new StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      String part = parts[i];
      if (i != 0) {
        part = capitalize(part);
      }
      sb.write(part);
    }
    return sb.toString();
  }

  /// Check whether the given [name] is a standard HTML5 tag name.
  static bool _isStandardTagName(String name) {
    name = name.toLowerCase();
    return !name.contains('-') || name == 'ng-content';
  }

  static bool _isTemplateVarBeginToken(Token token) {
    return token.type == TokenType.HASH ||
        token is KeywordToken && token.keyword == Keyword.VAR;
  }
}

/**
 * A text node in an HTML tree.
 */
class TextInfo extends NodeInfo {
  final int offset;
  final String text;

  TextInfo(this.offset, this.text);
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
