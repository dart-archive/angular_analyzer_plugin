library angular2.src.analysis.analyzer_plugin.src.resolver;

import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/error/codes.dart';
import 'package:analyzer/src/generated/error_verifier.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/ast/token.dart' hide SimpleToken;
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/strings.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
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

enum AttributeBoundType { input, output, twoWay, attr, clazz, style }

/**
 * Information about an attribute.
 */
class AttributeInfo {
  final String name;
  final int nameOffset;

  final String propertyName;
  final int propertyNameOffset;
  final int propertyNameLength;
  final AttributeBoundType bound;

  final String value;
  final int valueOffset;

  Expression expression;

  AttributeInfo(
      this.name,
      this.nameOffset,
      this.propertyName,
      this.propertyNameOffset,
      this.propertyNameLength,
      this.bound,
      this.value,
      this.valueOffset);

  int get valueLength => value != null ? value.length : 0;

  @override
  String toString() {
    return '([$name, $nameOffset],'
        '[$propertyName, $propertyNameOffset, $propertyNameLength, $bound],'
        '[$value, $valueOffset, $valueLength], [$expression])';
  }
}

/**
 * [DartTemplateResolver]s resolve inline [View] templates.
 */
class DartTemplateResolver {
  final TypeProvider typeProvider;
  final List<Component> standardHtmlComponents;
  final Map<String, OutputElement> standardHtmlEvents;
  final AnalysisErrorListener errorListener;
  final View view;

  DartTemplateResolver(this.typeProvider, this.standardHtmlComponents,
      this.standardHtmlEvents, this.errorListener, this.view);

  Template resolve() {
    String templateText = view.templateText;
    if (templateText == null) {
      return null;
    }
    // Parse HTML.
    html.DocumentFragment document;
    {
      String fragmentText = ' ' * view.templateOffset + templateText;
      html.HtmlParser parser = new html.HtmlParser(fragmentText,
          generateSpans: true, lowercaseAttrName: false);
      parser.compatMode = 'quirks';

      // Don't parse as a fragment, but parse as a document. That way there
      // will be a single first element with all contents.
      document = parser.parse();
      _addParseErrors(parser);
    }
    // Create and resolve Template.
    Template template = new Template(view, _firstElement(document));
    view.template = template;
    new TemplateResolver(typeProvider, standardHtmlComponents,
            standardHtmlEvents, errorListener)
        .resolve(template);
    return template;
  }

  /**
   * Report HTML errors as [AnalysisError]s.
   */
  void _addParseErrors(html.HtmlParser parser) {
    List<html.ParseError> parseErrors = parser.errors;
    for (html.ParseError parseError in parseErrors) {
      // We parse this as a full document rather than as a template so
      // that everything is in the first document element. But then we
      // get these errors which don't apply -- suppress them.
      if (parseError.errorCode == 'expected-doctype-but-got-start-tag' ||
          parseError.errorCode == 'expected-doctype-but-got-chars' ||
          parseError.errorCode == 'expected-doctype-but-got-eof') {
        continue;
      }
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
  List<AbstractDirective> directives = <AbstractDirective>[];

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
      String name = attribute.propertyName;
      attributeNameSpans[name] = new SourceRange(
          attribute.propertyNameOffset, attribute.propertyNameLength);
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

/**
 * [HtmlTemplateResolver]s resolve templates in separate Html files.
 */
class HtmlTemplateResolver {
  final TypeProvider typeProvider;
  final List<Component> standardHtmlComponents;
  final Map<String, OutputElement> standardHtmlEvents;
  final AnalysisErrorListener errorListener;
  final View view;
  final html.Document document;

  HtmlTemplateResolver(this.typeProvider, this.standardHtmlComponents,
      this.standardHtmlEvents, this.errorListener, this.view, this.document);

  HtmlTemplate resolve() {
    HtmlTemplate template =
        new HtmlTemplate(view, _firstElement(document), view.templateUriSource);
    view.template = template;
    new TemplateResolver(typeProvider, standardHtmlComponents,
            standardHtmlEvents, errorListener)
        .resolve(template);
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
    element.attributes.forEach((name, String value) {
      if (name is String) {
        String lowerName = name.toLowerCase();
        int nameOffset;
        try {
          nameOffset = element.attributeSpans[lowerName].start.offset;
        } catch (e) {
          // See https://github.com/dart-lang/html/issues/44, this creates
          // an error. Catch it so that analysis else where continues.
          return;
        }
        // name
        AttributeBoundType bound = null;
        String propName = name;
        int propNameOffset = nameOffset;
        if (propName.startsWith('[(') && propName.endsWith(')]')) {
          propNameOffset += 2;
          bound = AttributeBoundType.twoWay;
          propName = propName.substring(2, propName.length - 2);
        } else if (propName.startsWith('[') && propName.endsWith(']')) {
          propNameOffset += 1;
          propName = propName.substring(1, propName.length - 1);
          if (propName.startsWith('class.')) {
            bound = AttributeBoundType.clazz;
            propName = propName.substring('class.'.length);
            propNameOffset += 'class.'.length;
          } else if (propName.startsWith('attr.')) {
            bound = AttributeBoundType.attr;
            propName = propName.substring('attr.'.length);
            propNameOffset += 'attr.'.length;
          } else if (propName.startsWith('style.')) {
            propName = propName.substring('style.'.length);
            propNameOffset += 'style.'.length;
            bound = AttributeBoundType.style;
          } else {
            bound = AttributeBoundType.input;
          }
        } else if (propName.startsWith('bind-')) {
          int bindLength = 'bind-'.length;
          propNameOffset += bindLength;
          propName = propName.substring(bindLength);
          bound = AttributeBoundType.input;
        } else if (propName.startsWith('on-')) {
          int bindLength = 'on-'.length;
          propNameOffset += bindLength;
          propName = propName.substring(bindLength);
          bound = AttributeBoundType.output;
        } else if (propName.startsWith('(') && propName.endsWith(')')) {
          propNameOffset += 1;
          propName = propName.substring(1, propName.length - 1);
          bound = AttributeBoundType.output;
        }
        int propNameLength = propName != null ? propName.length : null;
        // value
        int valueOffset;
        {
          SourceSpan span = element.attributeValueSpans[lowerName];
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
 * A variable defined by a [AbstractDirective].
 */
class LocalVariable extends AngularElementImpl {
  final LocalVariableElementImpl dartVariable;

  LocalVariable(String name, int nameOffset, int nameLength, Source source,
      this.dartVariable)
      : super(name, nameOffset, nameLength, source);
}

/**
 * A node in an HTML tree.
 */
class NodeInfo {
  final List<NodeInfo> children = <NodeInfo>[];
}

/**
 * [TemplateResolver]s resolve [Template]s.
 */
class TemplateResolver {
  final TypeProvider typeProvider;
  final List<Component> standardHtmlComponents;
  final Map<String, OutputElement> standardHtmlEvents;
  final AnalysisErrorListener errorListener;

  Template template;
  View view;
  Source templateSource;
  ErrorReporter errorReporter;
  List<AbstractDirective> allDirectives;

  CompilationUnitElementImpl htmlCompilationUnitElement;
  ClassElementImpl htmlClassElement;
  MethodElementImpl htmlMethodElement;

  Map<String, OutputElement> nativeDomOutputs;

  /**
   * The map from names of bound attributes to resolve expressions.
   */
  Map<String, Expression> currentNodeAttributeExpressions =
      new HashMap<String, Expression>();

  /**
   * The full map of names to internal variables in the current template.
   */
  Map<String, InternalVariable> internalVariables =
      new HashMap<String, InternalVariable>();

  /**
   * The full map of names to local variables in the current template.
   */
  Map<String, LocalVariable> localVariables =
      new HashMap<String, LocalVariable>();

  /**
   * The full map of names to local variables in the current template.
   */
  Map<LocalVariableElement, LocalVariable> dartVariables =
      new HashMap<LocalVariableElement, LocalVariable>();

  TemplateResolver(this.typeProvider, this.standardHtmlComponents,
      this.standardHtmlEvents, this.errorListener);

  void resolve(Template template) {
    this.template = template;
    this.view = template.view;
    this.templateSource = view.templateSource;
    this.errorReporter = new ErrorReporter(errorListener, templateSource);
    this.allDirectives = <AbstractDirective>[]
      ..addAll(standardHtmlComponents)
      ..addAll(view.directives);
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
    if (directive is Component) {
      ClassElement classElement = directive.classElement;
      internalVariables[r'$implicit'] = new InternalVariable(
          r'$implicit', new DartElement(classElement), classElement.type);
    }
  }

  void _defineNgForVariables(
      List<AttributeInfo> attributes, AbstractDirective directive) {
    // TODO(scheglov) Once Angular has a way to describe variables, reimplement
    // https://github.com/angular/angular/issues/4850
    if (directive.classElement.displayName == 'NgFor') {
      internalVariables['index'] = new InternalVariable('index',
          new DartElement(directive.classElement), typeProvider.intType);
      for (AttributeInfo attribute in attributes) {
        if (attribute.propertyName == 'ngForOf' &&
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
  void _defineLocalVariablesForAttributes(List<AttributeInfo> attributes) {
    for (AttributeInfo attribute in attributes) {
      int offset = attribute.nameOffset;
      String name = attribute.name;

      // check if defines local variable
      var isLet = name.startsWith('let-'); // ng-for
      var isRef = name.startsWith('ref-'); // not ng-for
      var isHash = name.startsWith('#'); // not ng-for
      var isVar =
          name.startsWith('var-'); // either (deprecated but still works)
      if (isHash || isLet || isVar || isRef) {
        var prefixLen = isHash ? 1 : 4;
        name = name.substring(prefixLen);
        offset += prefixLen;

        // prepare internal variable name
        String internalName = attribute.value;
        if (internalName == null) {
          internalName = r'$implicit';
        }

        // maybe an internal variable reference
        DartType type;
        InternalVariable internalVar = internalVariables[internalName];
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
          LocalVariableElement dartVariable =
              _newLocalVariableElement(-1, name, type);
          LocalVariable localVariable = new LocalVariable(
              name, offset, name.length, templateSource, dartVariable);
          localVariables[name] = localVariable;
          dartVariables[dartVariable] = localVariable;
          // add local declaration
          template.addRange(
              new SourceRange(
                  localVariable.nameOffset, localVariable.nameLength),
              localVariable);
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

    // add the local variable to the enclosing element
    var localVariables = new List<LocalVariableElement>();
    localVariables.addAll(htmlMethodElement.localVariables);
    localVariables.add(localVariable);
    htmlMethodElement.localVariables = localVariables;
    return localVariable;
  }

  /**
   * Parse the given Dart [code] that starts at [offset].
   */
  Expression _parseDartExpression(int offset, String code) {
    Token token = _scanDartCode(offset, code);
    return _parseDartExpressionAtToken(token);
  }

  /**
   * Parse the given Dart [code] that starts ot [offset].
   */
  List<Statement> _parseDartStatements(int offset, String code) {
    Token token = _scanDartCode(offset, code);
    return _parseDartStatementsAtToken(token);
  }

  /**
   * Parse the Dart expression starting at the given [token].
   */
  Expression _parseDartExpressionAtToken(Token token) {
    Parser parser = new Parser(templateSource, errorListener);
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
   * Record [ResolvedRange]s for the given [AstNode].
   */
  void _recordAstNodeResolvedRanges(AstNode astNode) {
    if (astNode != null) {
      astNode.accept(new _DartReferencesRecorder(template, dartVariables));
    }
  }

  void _reportErrorForRange(SourceRange range, ErrorCode errorCode,
      [List<Object> arguments]) {
    errorListener.onError(new AnalysisError(
        templateSource, range.offset, range.length, errorCode, arguments));
  }

  /**
   * Resolve [attributes] names to inputs of [directive].
   */
  void _resolveAttributeNames(
      List<AttributeInfo> attributes, AbstractDirective directive) {
    for (AttributeInfo attribute in attributes) {
      for (InputElement input in directive.inputs) {
        if (attribute.propertyName == input.name) {
          SourceRange range = new SourceRange(
              attribute.propertyNameOffset, attribute.propertyNameLength);
          template.addRange(range, input);
        }
      }

      for (OutputElement output in directive.outputs) {
        if (attribute.propertyName == output.name) {
          SourceRange range = new SourceRange(
              attribute.propertyNameOffset, attribute.propertyNameLength);
          template.addRange(range, output);
        }
      }
    }
  }

  /**
   * Resolve values of [attributes].
   */
  void _resolveAttributeValues(
      List<AttributeInfo> attributes, List<AbstractDirective> directives) {
    for (AttributeInfo attribute in attributes) {
      int valueOffset = attribute.valueOffset;
      String value = attribute.value;
      dart.DartType eventType = null;
      // already handled
      if (attribute.name == 'template' || attribute.name.startsWith('*')) {
        continue;
      }
      // bound
      if (attribute.bound != null) {
        AngularWarningCode unboundErrorCode;
        var matched = false;
        if (attribute.bound == AttributeBoundType.output) {
          // Set the event type to dynamic, for if we don't match anything
          eventType = typeProvider.dynamicType;
          unboundErrorCode = AngularWarningCode.NONEXIST_OUTPUT_BOUND;
          for (AbstractDirective directive in directives) {
            for (OutputElement output in directive.outputs) {
              // TODO what if this matches two directives?
              if (output.name == attribute.propertyName) {
                eventType = output.eventType;
                // Parameterized directives, use the lower bound
                matched = true;
              }
            }
          }

          // standard HTML events bubble up, so everything supports them
          if (!matched) {
            var standardHtmlEvent = standardHtmlEvents[attribute.propertyName];
            if (standardHtmlEvent != null) {
              matched = true;
              eventType = standardHtmlEvent.eventType;
              SourceRange range = new SourceRange(
                  attribute.propertyNameOffset, attribute.propertyNameLength);
              template.addRange(range, standardHtmlEvent);
            }
          }

          //TODO: Refactor the following chunk of statement resolver
          List<Statement> statements =
              _resolveDartStatementsAt(valueOffset, value, eventType);
          for (Statement statement in statements) {
            _recordAstNodeResolvedRanges(statement);
          }

          if (!matched && unboundErrorCode != null) {
            errorListener.onError(new AnalysisError(
                templateSource,
                attribute.nameOffset,
                attribute.name.length,
                unboundErrorCode,
                [attribute.propertyName]));
          }

          continue;
        }

        Expression expression = attribute.expression;

        //Check if bound == OUTPUT:
        //  If so, branch off and deal as statement,
        //  otherwise, continue stack
        if (expression == null) {
          expression = _resolveDartExpressionAt(valueOffset, value, eventType);
          attribute.expression = expression;
        }
        if (expression != null) {
          _recordAstNodeResolvedRanges(expression);
        }

        if (attribute.bound == AttributeBoundType.twoWay) {
          if (!expression.isAssignable) {
            errorListener.onError(new AnalysisError(
                templateSource,
                attribute.valueOffset,
                attribute.value.length,
                AngularWarningCode.TWO_WAY_BINDING_NOT_ASSIGNABLE));
          }

          var outputMatched = false;
          for (AbstractDirective directive in directives) {
            for (OutputElement output in directive.outputs) {
              if (output.name == attribute.propertyName + "Change") {
                outputMatched = true;
                var eventType = output.eventType;

                if (!eventType.isAssignableTo(expression.bestType)) {
                  errorListener.onError(new AnalysisError(
                      templateSource,
                      attribute.valueOffset,
                      attribute.value.length,
                      AngularWarningCode.TWO_WAY_BINDING_OUTPUT_TYPE_ERROR,
                      [output.eventType, expression.bestType]));
                }
              }
            }
          }

          if (!outputMatched) {
            errorListener.onError(new AnalysisError(
                templateSource,
                attribute.nameOffset,
                attribute.name.length,
                AngularWarningCode.NONEXIST_TWO_WAY_OUTPUT_BOUND,
                [attribute.propertyName, attribute.propertyName + "Change"]));
          }
        }

        if (attribute.bound == AttributeBoundType.clazz) {
          _resolveClassAttribute(attribute, expression);
        } else if (attribute.bound == AttributeBoundType.style) {
          _resolveStyleAttribute(attribute, expression);
        } else if (attribute.bound == AttributeBoundType.attr) {
          _resolveAttributeBoundAttribute(attribute, expression);
        }

        if (attribute.bound == AttributeBoundType.input ||
            attribute.bound == AttributeBoundType.twoWay) {
          unboundErrorCode = AngularWarningCode.NONEXIST_INPUT_BOUND;
          for (AbstractDirective directive in directives) {
            for (InputElement input in directive.inputs) {
              if (input.name == attribute.propertyName) {
                var attrType = expression.bestType;
                var inputType = input.setterType;

                if (!attrType.isAssignableTo(inputType)) {
                  errorListener.onError(new AnalysisError(
                      templateSource,
                      attribute.valueOffset,
                      attribute.value.length,
                      AngularWarningCode.INPUT_BINDING_TYPE_ERROR,
                      [attrType, inputType]));
                }
                matched = true;
              }
            }
          }
        }

        if (!matched && unboundErrorCode != null) {
          errorListener.onError(new AnalysisError(
              templateSource,
              attribute.nameOffset,
              attribute.name.length,
              unboundErrorCode,
              [attribute.propertyName]));
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
   * Quick regex to match the spec, but doesn't handle unicode. They can start
   * with a dash, but if so must be followed by an alphabetic or underscore or
   * escaped character. Cannot start with a number.
   * https://www.w3.org/TR/CSS21/syndata.html#value-def-identifier
   */
  static final RegExp _cssIdentifierRegexp =
      new RegExp(r"^(-?[a-zA-Z_]|\\.)([a-zA-Z0-9\-_]|\\.)*$");

  bool _isCssIdentifier(String input) {
    return _cssIdentifierRegexp.hasMatch(input);
  }

  /**
   * Resolve attributes of type [class.some-class]="someBoolExpr", ensuring
   * the class is a valid css identifier and that the expression is of boolean
   * type
   */
  _resolveClassAttribute(AttributeInfo attribute, Expression expression) {
    if (!_isCssIdentifier(attribute.propertyName)) {
      errorListener.onError(new AnalysisError(
          templateSource,
          attribute.propertyNameOffset,
          attribute.propertyName.length,
          AngularWarningCode.INVALID_HTML_CLASSNAME,
          [attribute.propertyName]));
    }

    if (!expression.bestType.isAssignableTo(typeProvider.boolType)) {
      errorListener.onError(new AnalysisError(
        templateSource,
        attribute.valueOffset,
        attribute.value.length,
        AngularWarningCode.CLASS_BINDING_NOT_BOOLEAN,
      ));
    }
  }

  /**
   * Resolve attributes of type [style.color]="someExpr" and
   * [style.background-width.px]="someNumExpr" which bind a css style property
   * with optional units.
   */
  _resolveStyleAttribute(AttributeInfo attribute, Expression expression) {
    var cssPropertyName = attribute.propertyName;
    var dotpos = attribute.propertyName.indexOf('.');
    if (dotpos != -1) {
      cssPropertyName = attribute.propertyName.substring(0, dotpos);
      var cssUnitName = attribute.propertyName.substring(dotpos + '.'.length);
      if (!_isCssIdentifier(cssUnitName)) {
        errorListener.onError(new AnalysisError(
            templateSource,
            attribute.propertyNameOffset + dotpos + 1,
            cssUnitName.length,
            AngularWarningCode.INVALID_CSS_UNIT_NAME,
            [cssUnitName]));
      }
      if (!expression.bestType.isAssignableTo(typeProvider.numType)) {
        errorListener.onError(new AnalysisError(
            templateSource,
            attribute.valueOffset,
            attribute.value.length,
            AngularWarningCode.CSS_UNIT_BINDING_NOT_NUMBER));
      }
    }

    if (!_isCssIdentifier(cssPropertyName)) {
      errorListener.onError(new AnalysisError(
          templateSource,
          attribute.propertyNameOffset,
          cssPropertyName.length,
          AngularWarningCode.INVALID_CSS_PROPERTY_NAME,
          [cssPropertyName]));
    }
  }

  /**
   * Resolve attributes of type [attribute.some-attribute]="someExpr"
   */
  _resolveAttributeBoundAttribute(
      AttributeInfo attribute, Expression expression) {
    // TODO validate the type? Or against a dictionary?
    // note that the attribute name is valid by definition as it was discovered
    // within an attribute! (took me a while to realize why I couldn't make any
    // failing tests for this)
  }

  /**
   * Resolve the given [expression] and report errors.
   */
  void _resolveDartExpression(Expression expression, dart.DartType eventType) {
    ClassElement classElement = view.classElement;
    LibraryElement library = classElement.library;
    ResolverVisitor resolver = new ResolverVisitor(
        library, templateSource, typeProvider, errorListener);
    // fill the name scope
    ClassScope classScope = new ClassScope(resolver.nameScope, classElement);
    EnclosedScope localScope = new EnclosedScope(classScope);
    resolver.nameScope = localScope;
    resolver.enclosingClass = classElement;
    localVariables.values.forEach((LocalVariable local) {
      localScope.define(local.dartVariable);
    });
    if (eventType != null) {
      _defineBuiltInVariable(localScope, eventType, r'$event', -1);
    }
    // do resolve
    expression.accept(resolver);
    // verify
    ErrorVerifier verifier = new ErrorVerifier(errorReporter, library,
        typeProvider, new InheritanceManager(library), false, false);
    expression.accept(verifier);
  }

  /**
   * Resolve the given [AstNode] ([expression] or [statement]) and report errors.
   */
  void _resolveDartAstNode(AstNode astNode, dart.DartType eventType) {
    ClassElement classElement = view.classElement;
    LibraryElement library = classElement.library;
    ResolverVisitor resolver = new ResolverVisitor(
        library, templateSource, typeProvider, errorListener);
    // fill the name scope
    ClassScope classScope = new ClassScope(resolver.nameScope, classElement);
    EnclosedScope localScope = new EnclosedScope(classScope);
    resolver.nameScope = localScope;
    resolver.enclosingClass = classElement;
    localVariables.values.forEach((LocalVariable local) {
      localScope.define(local.dartVariable);
    });
    if (eventType != null) {
      _defineBuiltInVariable(localScope, eventType, r'$event', -1);
    }
    // do resolve
    astNode.accept(resolver);
    // verify
    ErrorVerifier verifier = new ErrorVerifier(errorReporter, library,
        typeProvider, new InheritanceManager(library), false, false);
    astNode.accept(verifier);
  }

  /**
   * Resolve the Dart expression with the given [code] at [offset].
   */
  Expression _resolveDartExpressionAt(
      int offset, String code, DartType eventType) {
    Expression expression = _parseDartExpression(offset, code);
    //TODO: Once resolveDartStatement is implemented, remove 1st condition
    if (eventType == null && expression.endToken.next.type != TokenType.EOF) {
      int trailingExpressionBegin = expression.endToken.next.offset;
      errorListener.onError(new AnalysisError(
          templateSource,
          trailingExpressionBegin,
          offset + code.length - trailingExpressionBegin,
          AngularWarningCode.TRAILING_EXPRESSION));
    }
    if (expression != null) {
      _resolveDartAstNode(expression, eventType);
    }
    return expression;
  }

  /**
   * Resolve the Dart statement with the given [code] at [offset].
   */
  List<Statement> _resolveDartStatementsAt(
      int offset, String code, DartType eventType) {
    code = code + ";";
    List<Statement> statements = _parseDartStatements(offset, code);
    if (statements != null) {
      for (Statement statement in statements) {
        _resolveDartAstNode(statement, eventType);
      }
    }
    return statements;
  }

  /**
   * Resolve the given [element].
   */
  void _resolveElement(ElementInfo element) {
    List<ElementInfo> templateElements = <ElementInfo>[];
    if (element == null) {
      return;
    }
    // apply template attributes
    Map<String, InternalVariable> oldInternalVariables = internalVariables;
    Map<String, LocalVariable> oldLocalVariables = localVariables;
    Map<LocalVariableElement, LocalVariable> oldDartVariables = dartVariables;
    internalVariables = new HashMap.from(internalVariables);
    localVariables = new HashMap.from(localVariables);
    dartVariables = new HashMap.from(dartVariables);
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
      _resolveNodeDirectives(element, true, templateElements);
      _resolveNodeExpressions(element, true);
      // process templates with their sub-trees
      for (ElementInfo templateElement in templateElements) {
        _resolveElement(templateElement);
      }
    } finally {
      internalVariables = oldInternalVariables;
      localVariables = oldLocalVariables;
      dartVariables = oldDartVariables;
    }
  }

  /**
   * Resolve the given Angular [code] at the given [offset].
   * Record [ResolvedRange]s.
   */
  Expression _resolveExpression(int offset, String code) {
    Expression expression = _resolveDartExpressionAt(offset, code, null);
    _recordAstNodeResolvedRanges(expression);
    return expression;
  }

  _resolveNodeExpressions(NodeInfo node, bool enterTemplate) {
    if (node is ElementInfo) {
      // Can't resolve attributes until the directives have been found.
      // Templates are sometimes skipped in resolving directives, so
      // we have to match that behavior here.
      if (!enterTemplate && node.isOrHasTemplateAttribute) {
        return;
      }

      _resolveAttributeValues(node.attributes, node.directives);

      // For the case of <template ngFor....> we have to check the
      // attributes to get a type. Now that that's done, load let-var
      if (node.isTemplate) {
        for (AbstractDirective directive in node.directives) {
          _defineNgForVariables(node.attributes, directive);
        }

        _defineLocalVariablesForAttributes(node.attributes);
      }
    }
    if (node is TextInfo) {
      _resolveTextExpressions(node.offset, node.text);
    }
    for (NodeInfo child in node.children) {
      _resolveNodeExpressions(child, false);
    }
  }

  _resolveNodeDirectives(
      NodeInfo node, bool enterTemplate, List<ElementInfo> templateElements) {
    if (node is ElementInfo) {
      // skip template
      if (!enterTemplate && node.isOrHasTemplateAttribute) {
        templateElements.add(node);
        return;
      }

      ElementView elementView = new ElementViewImpl(node.attributes, node);
      bool tagIsResolved = false;
      bool tagIsStandard = _isStandardTagName(node.localName);

      for (AbstractDirective directive in allDirectives) {
        Selector selector = directive.selector;
        if (selector.match(elementView, template)) {
          node.directives.add(directive);
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

      // In the case of <template ngFor...> we don't want to define variables
      // until we have resolved our attribute expressions types...and we can't
      // do that until all directives are resolved.
      if (!node.isTemplate) {
        // define local variables
        _defineLocalVariablesForAttributes(node.attributes);
      }
    }

    // process children
    for (NodeInfo child in node.children) {
      _resolveNodeDirectives(child, false, templateElements);
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
        if (!_tokenMatchesIdentifier(token)) {
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
          if (!_tokenMatchesIdentifier(token)) {
            errorReporter.reportErrorForToken(
                AngularWarningCode.EXPECTED_IDENTIFIER, token);
            return;
          }
          internalVarOffset = token.offset;
          internalVarName = token.lexeme;
          token = token.next;
        }
        // declare the local variable
        // Note the care that the varname's offset is preserved in place.
        attributes.add(new AttributeInfo(
            'let-$localVarName',
            localVarOffset - 'let-'.length,
            null,
            -1,
            -1,
            null,
            internalVarName,
            internalVarOffset));
        continue;
      }
      // key
      int keyOffset = token.offset;
      int keyLength;
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
        keyLength = key.length;
        if (prefix == null) {
          prefix = key;
        } else {
          key = prefix + capitalize(key);
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
        _resolveDartExpression(expression, null);
        token = expression.endToken.next;
      }
      // add the attribute to resolve to an input
      AttributeInfo attributeInfo = new AttributeInfo(
          key,
          keyOffset,
          key,
          keyOffset,
          keyLength,
          expression != null ? AttributeBoundType.input : null,
          'some-value',
          -1);
      attributeInfo.expression = expression;
      attributes.add(attributeInfo);
    }
    // match directives, requiring a match
    ElementView elementView = new ElementViewImpl(attributes, null);
    var directives = <AbstractDirective>[];
    for (AbstractDirective directive in allDirectives) {
      if (directive.selector.match(elementView, template)) {
        directives.add(directive);
        _defineDirectiveVariables(attributes, directive);
        _defineNgForVariables(attributes, directive);
        _defineLocalVariablesForAttributes(attributes);
        _resolveAttributeNames(attributes, directive);
      }
    }

    // TODO: report error if no directives matched here?
    _resolveAttributeValues(attributes, directives);
  }

  /**
   * Scan the given [text] staring at the given [offset] and resolve all of
   * its embedded expressions.
   */
  void _resolveTextExpressions(int fileOffset, String text) {
    int textOffset = 0;
    while (true) {
      // begin
      int begin = text.indexOf('{{', textOffset);
      int nextBegin = text.indexOf('{{', begin + 2);
      int end = text.indexOf('}}', textOffset);
      if (begin == -1 && end == -1) {
        break;
      }

      if (end == -1) {
        errorListener.onError(new AnalysisError(templateSource,
            fileOffset + begin, 2, AngularWarningCode.UNTERMINATED_MUSTACHE));
        // Move the cursor ahead and keep looking for more unmatched mustaches.
        textOffset = begin + 2;
        continue;
      }

      if (begin == -1) {
        errorListener.onError(new AnalysisError(templateSource,
            fileOffset + end, 2, AngularWarningCode.UNOPENED_MUSTACHE));
        // Move the cursor ahead and keep looking for more unmatched mustaches.
        textOffset = end + 2;
        continue;
      }

      if (nextBegin != -1 && nextBegin < end) {
        errorListener.onError(new AnalysisError(templateSource,
            fileOffset + begin, 2, AngularWarningCode.UNTERMINATED_MUSTACHE));
        // Skip this open mustache, check the next open we found
        textOffset = begin + 2;
        continue;
      }
      // resolve
      begin += 2;
      String code = text.substring(begin, end);
      _resolveExpression(fileOffset + begin, code);
      textOffset = end + 2;
    }
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
   * Check whether the given [name] is a standard HTML5 tag name.
   */
  static bool _isStandardTagName(String name) {
    name = name.toLowerCase();
    return !name.contains('-') || name == 'ng-content';
  }

  static bool _isTemplateVarBeginToken(Token token) {
    return token is KeywordToken && token.keyword == Keyword.VAR ||
        (token.type == TokenType.IDENTIFIER && token.lexeme == 'let');
  }

  static bool _tokenMatchesBuiltInIdentifier(Token token) =>
      token is KeywordToken && token.keyword.isPseudoKeyword;

  static bool _tokenMatchesIdentifier(Token token) =>
      token.type == TokenType.IDENTIFIER ||
      _tokenMatchesBuiltInIdentifier(token);
}

/**
 * A text node in an HTML tree.
 */
class TextInfo extends NodeInfo {
  final int offset;
  final String text;

  TextInfo(this.offset, this.text);
}

/**
 * An [AstVisitor] that records references to Dart [Element]s into
 * the given [template].
 */
class _DartReferencesRecorder extends RecursiveAstVisitor {
  final Map<Element, AngularElement> dartToAngularMap;
  final Template template;

  _DartReferencesRecorder(this.template, this.dartToAngularMap);

  @override
  visitSimpleIdentifier(SimpleIdentifier node) {
    Element dartElement = node.bestElement;
    if (dartElement != null) {
      AngularElement angularElement = dartToAngularMap[dartElement];
      if (angularElement == null) {
        angularElement = new DartElement(dartElement);
      }
      SourceRange range = new SourceRange(node.offset, node.length);
      template.addRange(range, angularElement);
    }
  }
}
