library angular2.src.analysis.analyzer_plugin.src.resolver;

import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/error_verifier.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'package:angular_analyzer_plugin/ast.dart';

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
      String name = attribute.name;
      attributeNameSpans[name] =
          new SourceRange(attribute.nameOffset, attribute.name.length);
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
 * A variable defined by a [AbstractDirective].
 */
class InternalVariable {
  final String name;
  final AngularElement element;
  final DartType type;

  InternalVariable(this.name, this.element, this.type);
}

/**
 * [TemplateResolver]s resolve [Template]s.
 */
class TemplateResolver {
  final TypeProvider typeProvider;
  final List<Component> standardHtmlComponents;
  final Map<String, OutputElement> standardHtmlEvents;
  final Map<String, InputElement> standardHtmlAttributes;
  final AnalysisErrorListener errorListener;
  final StandardAngular standardAngular;

  Template template;
  View view;
  Source templateSource;
  ErrorReporter errorReporter;

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

  TemplateResolver(
      this.typeProvider,
      this.standardHtmlComponents,
      this.standardHtmlEvents,
      this.standardHtmlAttributes,
      this.standardAngular,
      this.errorListener);

  void resolve(Template template) {
    this.template = template;
    this.view = template.view;
    this.templateSource = view.templateSource;
    this.errorReporter = new ErrorReporter(errorListener, templateSource);

    ElementInfo root = template.ast;

    var allDirectives = <AbstractDirective>[]
      ..addAll(standardHtmlComponents)
      ..addAll(view.directives);

    DirectiveResolver directiveResolver = new DirectiveResolver(
        allDirectives,
        templateSource,
        template,
        standardAngular,
        errorReporter,
        errorListener);
    root.accept(directiveResolver);
    ComponentContentResolver contentResolver =
        new ComponentContentResolver(templateSource, template, errorListener);
    root.accept(contentResolver);

    _resolveScope(root);
  }

  /**
   * Resolve the given [element]. This will either be a template or the root of
   * the template, meaning it has its own scope. We have to resolve the
   * outermost scopes first so that ngFor variables have types.
   *
   * See the comment block for [PrepareScopeVisitor] for the most detailed
   * breakdown of what we do and why.
   *
   * Requires that we've already resolved the directives down the tree. 
   */
  void _resolveScope(ElementInfo element) {
    if (element == null) {
      return;
    }
    // apply template attributes
    Map<String, LocalVariable> oldLocalVariables = localVariables;
    Map<String, InternalVariable> oldInternalVariables = internalVariables;
    internalVariables = new HashMap.from(internalVariables);
    localVariables = new HashMap.from(localVariables);
    try {
      DartVariableManager dartVarManager =
          new DartVariableManager(template, templateSource, errorListener);
      // Prepare the scopes
      element.accept(new PrepareScopeVisitor(
          internalVariables,
          localVariables,
          template,
          templateSource,
          typeProvider,
          dartVarManager,
          errorListener));
      // Load $event into the scopes
      element.accept(new PrepareEventScopeVisitor(
          standardHtmlEvents,
          template,
          templateSource,
          localVariables,
          typeProvider,
          dartVarManager,
          errorListener));
      // Resolve the scopes
      element.accept(new SingleScopeResolver(
          standardHtmlAttributes,
          view,
          template,
          templateSource,
          typeProvider,
          errorListener,
          errorReporter));

      // Now the next scope is ready to be resolved
      var tplSearch = new NextTemplateElementsSearch();
      element.accept(tplSearch);
      for (ElementInfo templateElement in tplSearch.results) {
        _resolveScope(templateElement);
      }
    } finally {
      internalVariables = oldInternalVariables;
      localVariables = oldLocalVariables;
    }
  }
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

/**
 * Probably the most important visitor to understand in how we process angular
 * templates.
 *
 * First its important to note how angular scopes are determined by templates;
 * that's how ngFor adds a variable below. Its also important to note that
 * unlike in most languages, angular template semantics lets you use a variable
 * before its declared, ie `<a>{{b}}</a><p #b></p>` so long as they share a
 * scope. Also note that a template both ends a scope and begins it: all
 * the bindings in the template are from the old scope, and yet let-vars add to
 * the new new scope.
 *
 * This means we need to have a multiple-pass process, and that means we spend
 * a good chunk of time merely following the rules of scoping. This visitor
 * will enforce that for you.
 *
 * Just don't @override visitElementInfo (or do so carefully), and this visitor
 * naturally walk over all the attributes in scope by what you give it. You can
 * also hook into what happens when it hits the elements by overriding:
 *
 * * visitBorderScopeTemplateAttribute(templateAttribute)
 * * visitScopeRootElementWithTemplateAttribute(element)
 * * visitBorderScopeTemplateElement(element)
 * * visitScopeRootTemplateElement(element)
 * * visitElementInScope(element)
 *
 * Which should allow you to do specialty things, such as what the
 * [PrepareScopeVisitor] does by using out-of-scope properties to affect the
 * in-scope ones.
 */
class AngularScopeVisitor extends AngularAstVisitor {
  bool visitingRoot = true;

  void visitElementInfo(ElementInfo element) {
    var isRoot = visitingRoot;
    visitingRoot = false;
    if (element.templateAttribute != null) {
      if (!isRoot) {
        visitBorderScopeTemplateAttribute(element.templateAttribute);
        return;
      } else {
        visitScopeRootElementWithTemplateAttribute(element);
      }
    } else if (element.isTemplate) {
      if (isRoot) {
        visitScopeRootTemplateElement(element);
      } else {
        visitBorderScopeTemplateElement(element);
      }
    } else {
      visitElementInScope(element);
    }
  }

  void visitScopeRootTemplateElement(ElementInfo element) {
    // the children are in this scope, the template itself is borderlands
    for (NodeInfo child in element.childNodes) {
      child.accept(this);
    }
  }

  void visitBorderScopeTemplateElement(ElementInfo element) {
    // the attributes are in this scope, the children aren't
    for (AttributeInfo attr in element.attributes) {
      attr.accept(this);
    }
  }

  void visitScopeRootElementWithTemplateAttribute(ElementInfo element) {
    var children =
        element.children.where((child) => child is! TemplateAttribute);
    for (AngularAstNode child in children) {
      child.accept(this);
    }
  }

  void visitBorderScopeTemplateAttribute(TemplateAttribute attr) {
    // Border to the next scope. The virtual properties belong here, the real
    // element does not
    visitTemplateAttr(attr);
  }

  void visitElementInScope(ElementInfo element) {
    for (NodeInfo child in element.children) {
      child.accept(this);
    }
  }
}

/**
 * We have to collect all vars and their types before we can resolve the
 * bindings, since variables can be used before they are declared. This does
 * that. 
 *
 * It loads each node's [localVariables] property so that the resolver has
 * everything it needs, keeping those local variables around for autocomplete.
 * As the scope is built up it is attached to the nodes -- and thanks to
 * mutability + a shared reference, that works just fine.
 *
 * However, `$event` vars require a copy of the scope, not a shared reference,
 * so that the `$event` can be added. Therefore this visitor does not handle
 * output bindings. That is [PrepareEventScopeVisitor]'s job, only to be
 * performed after this step has completed.
 */
class PrepareScopeVisitor extends AngularScopeVisitor {
  /**
   * The full map of names to internal variables in the current scope
   */
  final Map<String, InternalVariable> internalVariables;

  /**
   * The full map of names to local variables in the current scope
   */
  final Map<String, LocalVariable> localVariables;

  final Template template;
  final Source templateSource;
  final TypeProvider typeProvider;
  final DartVariableManager dartVariableManager;
  final AnalysisErrorListener errorListener;

  List<AbstractDirective> directives;

  PrepareScopeVisitor(
      this.internalVariables,
      this.localVariables,
      this.template,
      this.templateSource,
      this.typeProvider,
      this.dartVariableManager,
      this.errorListener);

  @override
  void visitScopeRootTemplateElement(ElementInfo element) {
    for (AbstractDirective directive in element.directives) {
      _defineDirectiveVariables(element.attributes, directive);
      // This must be here for <template> tags.
      _defineNgForVariables(element.attributes, directive);
    }

    _defineLocalVariablesForAttributes(element.attributes);

    directives = element.directives;
    super.visitScopeRootTemplateElement(element);
  }

  @override
  void visitScopeRootElementWithTemplateAttribute(ElementInfo element) {
    TemplateAttribute templateAttr = element.templateAttribute;

    // If this is how our scope begins, like we're within an ngFor, then
    // let the ngFor alter the current scope.
    for (AbstractDirective directive in templateAttr.directives) {
      _defineDirectiveVariables(templateAttr.virtualAttributes, directive);
      _defineNgForVariables(templateAttr.virtualAttributes, directive);
    }

    _defineLocalVariablesForAttributes(templateAttr.virtualAttributes);

    // Make sure the regular element also alters the current scope
    for (AbstractDirective directive in element.directives) {
      _defineDirectiveVariables(element.attributes, directive);
      // This must be here for <template> tags.
      _defineNgForVariables(element.attributes, directive);
    }

    _defineLocalVariablesForAttributes(element.attributes);

    directives = element.directives;
    super.visitScopeRootElementWithTemplateAttribute(element);
  }

  @override
  void visitBorderScopeTemplateAttribute(TemplateAttribute attr) {
    // Border to the next scope. Make sure the virtual properties are bound
    // to the scope we're building now. But nothing else.
    directives = attr.directives;
    visitTemplateAttr(attr);
  }

  @override
  void visitElementInScope(ElementInfo element) {
    // Regular element or component. Look for `#var`s.
    for (AbstractDirective directive in element.directives) {
      _defineDirectiveVariables(element.attributes, directive);
      // This must be here for <template> tags.
      _defineNgForVariables(element.attributes, directive);
    }

    _defineLocalVariablesForAttributes(element.attributes);

    directives = element.directives;
    super.visitElementInScope(element);
  }

  @override
  visitMustache(Mustache mustache) {
    mustache.localVariables = localVariables;
  }

  @override
  visitExpressionBoundAttr(ExpressionBoundAttribute attr) {
    attr.localVariables = localVariables;
  }

  void _defineNgForVariables(
      List<AttributeInfo> attributes, AbstractDirective directive) {
    // TODO(scheglov) Once Angular has a way to describe variables, reimplement
    // https://github.com/angular/angular/issues/4850
    if (directive.classElement.displayName == 'NgFor') {
      final dartElem = new DartElement(directive.classElement);
      internalVariables['index'] =
          new InternalVariable('index', dartElem, typeProvider.intType);
      internalVariables['even'] =
          new InternalVariable('even', dartElem, typeProvider.boolType);
      internalVariables['odd'] =
          new InternalVariable('odd', dartElem, typeProvider.boolType);
      internalVariables['first'] =
          new InternalVariable('first', dartElem, typeProvider.boolType);
      internalVariables['last'] =
          new InternalVariable('last', dartElem, typeProvider.boolType);
      for (AttributeInfo attribute in attributes) {
        if (attribute is ExpressionBoundAttribute &&
            attribute.name == 'ngForOf' &&
            attribute.expression != null) {
          DartType itemType = _getIterableItemType(attribute.expression);
          internalVariables[r'$implicit'] =
              new InternalVariable(r'$implicit', dartElem, itemType);
        }
      }
    }
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
        } else if (attribute.value != null) {
          errorListener.onError(new AnalysisError(
              templateSource,
              attribute.valueOffset,
              attribute.value.length,
              AngularWarningCode.NO_DIRECTIVE_EXPORTED_BY_SPECIFIED_NAME,
              [attribute.value]));
        }

        // any unmatched values should be dynamic to prevent secondary errors
        if (type == null) {
          type = typeProvider.dynamicType;
        }

        // add a new local variable with type
        LocalVariableElement dartVariable =
            dartVariableManager.newLocalVariableElement(-1, name, type);
        LocalVariable localVariable = new LocalVariable(
            name, offset, name.length, templateSource, dartVariable);
        localVariables[name] = localVariable;
        // add local declaration
        template.addRange(
            new SourceRange(
                localVariable.nameOffset, localVariable.name.length),
            localVariable);
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
}

class DartVariableManager {
  Template template;
  Source templateSource;
  AnalysisErrorListener errorListener;

  DartVariableManager(this.template, this.templateSource, this.errorListener);

  CompilationUnitElementImpl htmlCompilationUnitElement;
  ClassElementImpl htmlClassElement;
  MethodElementImpl htmlMethodElement;

  LocalVariableElement newLocalVariableElement(
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
    localVariable.name.length;
    localVariable.type = type;

    // add the local variable to the enclosing element
    var localVariables = new List<LocalVariableElement>();
    localVariables.addAll(htmlMethodElement.localVariables);
    localVariables.add(localVariable);
    htmlMethodElement.localVariables = localVariables;
    return localVariable;
  }
}

class PrepareEventScopeVisitor extends AngularScopeVisitor {
  List<AbstractDirective> directives;
  final Template template;
  final Source templateSource;
  final Map<String, LocalVariable> localVariables;
  final Map<String, OutputElement> standardHtmlEvents;
  final TypeProvider typeProvider;
  final DartVariableManager dartVariableManager;
  final AnalysisErrorListener errorListener;

  PrepareEventScopeVisitor(
      this.standardHtmlEvents,
      this.template,
      this.templateSource,
      this.localVariables,
      this.typeProvider,
      this.dartVariableManager,
      this.errorListener);

  @override
  visitElementInfo(ElementInfo elem) {
    directives = elem.directives;
    super.visitElementInfo(elem);
  }

  @override
  visitTemplateAttr(TemplateAttribute templateAttr) {
    directives = templateAttr.directives;
    super.visitTemplateAttr(templateAttr);
  }

  @override
  visitStatementsBoundAttr(StatementsBoundAttribute attr) {
    DartType eventType = typeProvider.dynamicType;
    var matched = false;

    for (DirectiveBinding directiveBinding in attr.parent.boundDirectives) {
      for (OutputElement output in directiveBinding.boundDirective.outputs) {
        //TODO what if this matches two directives?
        if (output.name == attr.name) {
          eventType = output.eventType;
          matched = true;
          SourceRange range =
              new SourceRange(attr.nameOffset, attr.name.length);
          template.addRange(range, output);
          directiveBinding.outputBindings.add(new OutputBinding(output, attr));
        }
      }
    }

    //standard HTML events bubble up, so everything supports them
    if (!matched) {
      var standardHtmlEvent = standardHtmlEvents[attr.name];
      if (standardHtmlEvent != null) {
        matched = true;
        eventType = standardHtmlEvent.eventType;
        SourceRange range = new SourceRange(attr.nameOffset, attr.name.length);
        template.addRange(range, standardHtmlEvent);
        attr.parent.boundStandardOutputs
            .add(new OutputBinding(standardHtmlEvent, attr));
      }
    }

    if (!matched) {
      errorListener.onError(new AnalysisError(
          templateSource,
          attr.nameOffset,
          attr.name.length,
          AngularWarningCode.NONEXIST_OUTPUT_BOUND,
          [attr.name]));
    }

    attr.localVariables = new HashMap.from(localVariables);
    LocalVariableElement dartVariable =
        dartVariableManager.newLocalVariableElement(-1, r'$event', eventType);
    LocalVariable localVariable =
        new LocalVariable(r'$event', -1, 6, templateSource, dartVariable);
    attr.localVariables[r'$event'] = localVariable;
  }
}

/**
 * Use this visitor to find the nested scopes within the [ElementInfo]
 * you visit.
 */
class NextTemplateElementsSearch extends AngularAstVisitor {
  bool visitingRoot = true;

  List<ElementInfo> results = [];

  @override
  void visitElementInfo(ElementInfo element) {
    if (element.isOrHasTemplateAttribute && !visitingRoot) {
      results.add(element);
      return;
    }

    visitingRoot = false;
    for (NodeInfo child in element.childNodes) {
      child.accept(this);
    }
  }
}

class DirectiveResolver extends AngularAstVisitor {
  final List<AbstractDirective> allDirectives;
  final Source templateSource;
  final Template template;
  final AnalysisErrorListener errorListener;
  final ErrorReporter _errorReporter;
  final StandardAngular _standardAngular;
  final List<DirectiveBinding> outerBindings = [];
  final List<ElementInfo> outerElements = [];

  DirectiveResolver(this.allDirectives, this.templateSource, this.template,
      this._standardAngular, this._errorReporter, this.errorListener);

  @override
  void visitElementInfo(ElementInfo element) {
    outerElements.add(element);
    if (element.templateAttribute != null) {
      visitTemplateAttr(element.templateAttribute);
    }

    ElementView elementView = new ElementViewImpl(element.attributes, element);

    int containingDirectivesCount = outerBindings.length;
    for (AbstractDirective directive in allDirectives) {
      SelectorMatch match = directive.selector.match(elementView, template);
      if (match != SelectorMatch.NoMatch) {
        var binding = new DirectiveBinding(directive);
        element.boundDirectives.add(binding);
        if (match == SelectorMatch.TagMatch) {
          element.tagMatchedAsDirective = true;
        }

        // optimization: only add the bindings that care about content child
        if (directive.contentChilds.isNotEmpty ||
            directive.contentChildren.isNotEmpty) {
          outerBindings.add(binding);
        }
      }
    }

    if (!element.isOrHasTemplateAttribute) {
      _checkNoStructuralDirectives(element.attributes);
    }

    recordContentChildren(element);

    for (NodeInfo child in element.childNodes) {
      child.accept(this);
    }

    outerBindings.removeRange(containingDirectivesCount, outerBindings.length);
    outerElements.removeLast();
  }

  @override
  void visitTemplateAttr(TemplateAttribute attr) {
    // TODO: report error if no directives matched here?
    ElementView elementView = new ElementViewImpl(attr.virtualAttributes, null);
    for (AbstractDirective directive in allDirectives) {
      if (directive.selector.match(elementView, template) !=
          SelectorMatch.NoMatch) {
        attr.boundDirectives.add(new DirectiveBinding(directive));
      }
    }
  }

  _checkNoStructuralDirectives(List<AttributeInfo> attributes) {
    for (AttributeInfo attribute in attributes) {
      if (attribute.name == 'ngFor' || attribute.name == 'ngIf') {
        _reportErrorForRange(
            new SourceRange(attribute.nameOffset, attribute.name.length),
            AngularWarningCode.STRUCTURAL_DIRECTIVES_REQUIRE_TEMPLATE,
            [attribute.name]);
      }
    }
  }

  recordContentChildren(ElementInfo element) {
    for (final binding in outerBindings) {
      for (var contentChild in binding.boundDirective.contentChilds) {
        // an already matched ContentChild shouldn't look inside that match
        if (binding.contentChildBindings[contentChild]?.boundElements
                ?.any((element) => outerElements.contains(element)) ==
            true) {
          continue;
        }

        if (contentChild.query
            .match(element, _standardAngular, _errorReporter)) {
          binding.contentChildBindings.putIfAbsent(
              contentChild,
              () => new ContentChildBinding(
                  binding.boundDirective, contentChild));

          if (!binding
              .contentChildBindings[contentChild].boundElements.isEmpty) {
            _errorReporter.reportErrorForOffset(
                AngularWarningCode.SINGULAR_CHILD_QUERY_MATCHED_MULTIPLE_TIMES,
                element.offset,
                element.length, [
              binding.boundDirective.classElement.name,
              contentChild.field.fieldName
            ]);
          }
          binding.contentChildBindings[contentChild].boundElements.add(element);

          if (element.parent.boundDirectives.contains(binding)) {
            element.tagMatchedAsImmediateContentChild = true;
          }
        }
      }

      for (var contentChildren in binding.boundDirective.contentChildren) {
        if (contentChildren.query
            .match(element, _standardAngular, _errorReporter)) {
          binding.contentChildrenBindings.putIfAbsent(
              contentChildren,
              () => new ContentChildBinding(
                  binding.boundDirective, contentChildren));
          binding.contentChildrenBindings[contentChildren].boundElements
              .add(element);

          if (element.parent.boundDirectives.contains(binding)) {
            element.tagMatchedAsImmediateContentChild = true;
          }
        }
      }
    }
  }

  void _reportErrorForRange(SourceRange range, ErrorCode errorCode,
      [List<Object> arguments]) {
    errorListener.onError(new AnalysisError(
        templateSource, range.offset, range.length, errorCode, arguments));
  }
}

class ComponentContentResolver extends AngularAstVisitor {
  final Source templateSource;
  final Template template;
  final AnalysisErrorListener errorListener;

  ComponentContentResolver(
      this.templateSource, this.template, this.errorListener);

  @override
  void visitElementInfo(ElementInfo element) {
    // TODO should we visitTemplateAttr(element.templateAttribute) ??
    bool tagIsStandard = _isStandardTagName(element.localName);
    Component component;

    for (AbstractDirective directive in element.directives) {
      if (directive is Component) {
        component = directive;
        // TODO better html tag detection, see #248
        tagIsStandard = component.isHtml;
      }
    }

    if (!tagIsStandard &&
        !element.tagMatchedAsTransclusion &&
        !element.tagMatchedAsDirective) {
      _reportErrorForRange(element.openingNameSpan,
          AngularWarningCode.UNRESOLVED_TAG, [element.localName]);
    }

    if (!tagIsStandard) {
      checkTransclusionsContentChildren(
          component, element.childNodes, tagIsStandard);
    }

    for (NodeInfo child in element.childNodes) {
      child.accept(this);
    }
  }

  void checkTransclusionsContentChildren(
      Component component, List<NodeInfo> children, bool tagIsStandard) {
    if (component?.ngContents == null) {
      return;
    }

    bool acceptAll = component.ngContents.any((s) => s.matchesAll);
    for (NodeInfo child in children) {
      if (child is TextInfo && !acceptAll && child.text.trim() != "") {
        _reportErrorForRange(new SourceRange(child.offset, child.length),
            AngularWarningCode.CONTENT_NOT_TRANSCLUDED);
      } else if (child is ElementInfo) {
        ElementView view = new ElementViewImpl(child.attributes, child);
        bool matched = acceptAll;
        bool matchedTag = false;
        for (NgContent ngContent in component.ngContents) {
          SelectorMatch match = ngContent.matchesAll
              ? SelectorMatch.NonTagMatch
              : ngContent.selector.match(view, template);
          if (match != SelectorMatch.NoMatch) {
            matched = true;
            matchedTag = matchedTag || match == SelectorMatch.TagMatch;
          }
        }

        matched = matched || child.tagMatchedAsImmediateContentChild;

        if (!matched) {
          _reportErrorForRange(new SourceRange(child.offset, child.length),
              AngularWarningCode.CONTENT_NOT_TRANSCLUDED);
        } else if (matchedTag) {
          child.tagMatchedAsTransclusion = true;
        }
      }
    }
  }

  void _reportErrorForRange(SourceRange range, ErrorCode errorCode,
      [List<Object> arguments]) {
    errorListener.onError(new AnalysisError(
        templateSource, range.offset, range.length, errorCode, arguments));
  }

  /**
   * Check whether the given [name] is a standard HTML5 tag name.
   */
  static bool _isStandardTagName(String name) {
    name = name.toLowerCase();
    return !name.contains('-') || name == 'ng-content';
  }
}

class NgContentRecorder extends AngularScopeVisitor {
  final List<NgContent> ngContents;
  final Source source;
  final ErrorReporter errorReporter;

  NgContentRecorder(Component component, this.errorReporter)
      : ngContents = component.ngContents,
        source = component.view.templateSource;

  NgContentRecorder.forFile(this.ngContents, this.source, this.errorReporter);

  @override
  void visitElementInfo(ElementInfo element) {
    if (element.localName != 'ng-content') {
      for (NodeInfo child in element.childNodes) {
        child.accept(this);
      }

      return;
    }

    List<AttributeInfo> selectorAttrs =
        element.attributes.where((a) => a.name == 'select');

    for (NodeInfo child in element.childNodes) {
      if (!child.isSynthetic) {
        errorReporter.reportErrorForOffset(
            AngularWarningCode.NG_CONTENT_MUST_BE_EMPTY,
            element.openingSpan.offset,
            element.openingSpan.length);
      }
    }

    if (selectorAttrs.length == 0) {
      ngContents.add(new NgContent(element.offset, element.length));
      return;
    }

    // We don't actually check if selectors.length > 2, because the html parser
    // reports that.
    try {
      AttributeInfo selectorAttr = selectorAttrs.first;
      if (selectorAttr.value == null) {
        errorReporter.reportErrorForOffset(
            AngularWarningCode.CANNOT_PARSE_SELECTOR,
            selectorAttr.nameOffset,
            selectorAttr.name.length);
      } else if (selectorAttr.value == "") {
        errorReporter.reportErrorForOffset(
            AngularWarningCode.CANNOT_PARSE_SELECTOR,
            selectorAttr.valueOffset - 1,
            2);
      } else {
        Selector selector = new SelectorParser(
                source, selectorAttr.valueOffset, selectorAttr.value)
            .parse();
        ngContents.add(new NgContent.withSelector(
            element.offset,
            element.length,
            selector,
            selectorAttr.valueOffset,
            selectorAttr.value.length));
      }
    } on SelectorParseError catch (e) {
      errorReporter.reportErrorForOffset(
          AngularWarningCode.CANNOT_PARSE_SELECTOR,
          e.offset,
          e.length,
          [e.message]);
    }
  }
}

/**
 * Once all the scopes for all the expressions & statements are prepared, we're
 * ready to resolve all the expressions inside and typecheck everything.
 *
 * This will typecheck the contents of mustaches and attribute bindings against
 * their scopes, and ensure that all attribute bindings exist on a directive and
 * match the type of the binding where there is one. Then records references.
 */
class SingleScopeResolver extends AngularScopeVisitor {
  final Map<String, InputElement> standardHtmlAttributes;
  List<AbstractDirective> directives;
  View view;
  Template template;
  Source templateSource;
  TypeProvider typeProvider;
  AnalysisErrorListener errorListener;
  ErrorReporter errorReporter;

  static var styleWithPercent = new Set<String>.from([
    'border-bottom-left-radius',
    'border-bottom-right-radius',
    'border-image-slice',
    'border-image-width',
    'border-radius',
    'border-top-left-radius',
    'border-top-right-radius',
    'bottom',
    'font-size',
    'height',
    'left',
    'line-height',
    'margin',
    'margin-bottom',
    'margin-left',
    'margin-right',
    'margin-top',
    'max-height',
    'max-width',
    'min-height',
    'min-width',
    'padding',
    'padding-bottom',
    'padding-left',
    'padding-right',
    'padding-top',
    'right',
    'text-indent',
    'top',
    'width',
  ]);

  /**
   * The full map of names to local variables in the current context
   */
  Map<String, LocalVariable> localVariables;

  SingleScopeResolver(
      this.standardHtmlAttributes,
      this.view,
      this.template,
      this.templateSource,
      this.typeProvider,
      this.errorListener,
      this.errorReporter);

  @override
  void visitElementInfo(ElementInfo element) {
    directives = element.directives;
    super.visitElementInfo(element);
  }

  @override
  void visitTemplateAttr(TemplateAttribute templateAttr) {
    directives = templateAttr.directives;
    super.visitTemplateAttr(templateAttr);
  }

  @override
  void visitMustache(Mustache mustache) {
    localVariables = mustache.localVariables;
    _resolveDartExpression(mustache.expression);
    _recordAstNodeResolvedRanges(mustache.expression);
  }

  @override
  void visitExpressionBoundAttr(ExpressionBoundAttribute attribute) {
    localVariables = attribute.localVariables;
    _resolveDartExpression(attribute.expression);
    if (attribute.expression != null) {
      _recordAstNodeResolvedRanges(attribute.expression);
    }

    if (attribute.bound == ExpressionBoundType.twoWay) {
      _resolveTwoWayBoundAttributeValues(attribute);
    } else if (attribute.bound == ExpressionBoundType.input) {
      _resolveInputBoundAttributeValues(attribute);
    } else if (attribute.bound == ExpressionBoundType.clazz) {
      _resolveClassAttribute(attribute);
    } else if (attribute.bound == ExpressionBoundType.style) {
      _resolveStyleAttribute(attribute);
    } else if (attribute.bound == ExpressionBoundType.attr) {
      _resolveAttributeBoundAttribute(attribute);
    }
  }

  /**
   * Resolve output-bound values of [attributes] as statements.
   */
  @override
  void visitStatementsBoundAttr(StatementsBoundAttribute attribute) {
    localVariables = attribute.localVariables;
    _resolveDartExpressionStatements(attribute.statements);
    for (Statement statement in attribute.statements) {
      _recordAstNodeResolvedRanges(statement);
    }
  }

  /**
   * Resolve TwoWay-bound values of [attributes] as expressions.
   */
  void _resolveTwoWayBoundAttributeValues(ExpressionBoundAttribute attribute) {
    bool outputMatched = false;

    // empty attribute error registered in converter. Just don't crash.
    if (attribute.expression != null && !attribute.expression.isAssignable) {
      errorListener.onError(new AnalysisError(
          templateSource,
          attribute.valueOffset,
          attribute.value.length,
          AngularWarningCode.TWO_WAY_BINDING_NOT_ASSIGNABLE));
    }

    for (DirectiveBinding directiveBinding
        in attribute.parent.boundDirectives) {
      for (OutputElement output in directiveBinding.boundDirective.outputs) {
        if (output.name == attribute.name + "Change") {
          outputMatched = true;
          var eventType = output.eventType;
          directiveBinding.outputBindings
              .add(new OutputBinding(output, attribute));

          // half-complete-code case: ensure the expression is actually there
          if (attribute.expression != null &&
              !eventType.isAssignableTo(attribute.expression.bestType)) {
            errorListener.onError(new AnalysisError(
                templateSource,
                attribute.valueOffset,
                attribute.value.length,
                AngularWarningCode.TWO_WAY_BINDING_OUTPUT_TYPE_ERROR,
                [output.eventType, attribute.expression.bestType]));
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
          [attribute.name, attribute.name + "Change"]));
    }

    _resolveInputBoundAttributeValues(attribute);
  }

  /**
   * Resolve input-bound values of [attributes] as expressions.
   * Also used by _resolveTwoWwayBoundAttributeValues.
   */
  void _resolveInputBoundAttributeValues(ExpressionBoundAttribute attribute) {
    bool inputMatched = false;

    for (DirectiveBinding directiveBinding
        in attribute.parent.boundDirectives) {
      for (InputElement input in directiveBinding.boundDirective.inputs) {
        if (input.name == attribute.name) {
          _typecheckMatchingInput(attribute, input);

          SourceRange range =
              new SourceRange(attribute.nameOffset, attribute.name.length);
          template.addRange(range, input);
          directiveBinding.inputBindings
              .add(new InputBinding(input, attribute));

          inputMatched = true;
        }
      }
    }

    if (!inputMatched) {
      InputElement standardHtmlAttribute =
          standardHtmlAttributes[attribute.name];
      if (standardHtmlAttribute != null) {
        _typecheckMatchingInput(attribute, standardHtmlAttribute);

        SourceRange range =
            new SourceRange(attribute.nameOffset, attribute.name.length);
        template.addRange(range, standardHtmlAttribute);
        attribute.parent.boundStandardInputs
            .add(new InputBinding(standardHtmlAttribute, attribute));

        inputMatched = true;
      }
    }

    if (!inputMatched) {
      errorListener.onError(new AnalysisError(
          templateSource,
          attribute.nameOffset,
          attribute.name.length,
          AngularWarningCode.NONEXIST_INPUT_BOUND,
          [attribute.name]));
    }
  }

  /**
   * Resolve input-bound values of [attributes] as strings, if they match. Note,
   * this does not report an error un unmatched attributes, but it will report
   * the range, and ensure that input bindings are string-assingable.
   */
  void visitTextAttr(TextAttribute attribute) {
    for (DirectiveBinding directiveBinding
        in attribute.parent.boundDirectives) {
      for (InputElement input in directiveBinding.boundDirective.inputs) {
        if (input.name == attribute.name) {
          var inputType = input.setterType;

          // Typecheck all but HTML inputs. For those, `width="10"` becomes
          // `setAttribute("width", "10")`, which is ok. But for directives and
          // components, this becomes `.someIntProp = "10"` which doesn't work.
          if (!directiveBinding.boundDirective.isHtml &&
              !typeProvider.stringType.isAssignableTo(inputType)) {
            errorListener.onError(new AnalysisError(
                templateSource,
                attribute.nameOffset,
                attribute.name.length,
                AngularWarningCode.STRING_STYLE_INPUT_BINDING_INVALID,
                [input.name]));
          }

          SourceRange range =
              new SourceRange(attribute.nameOffset, attribute.name.length);
          template.addRange(range, input);
          directiveBinding.inputBindings
              .add(new InputBinding(input, attribute));
        }
      }

      for (AngularElement elem in directiveBinding.boundDirective.attributes) {
        if (elem.name == attribute.name) {
          SourceRange range =
              new SourceRange(attribute.nameOffset, attribute.name.length);
          template.addRange(range, elem);
        }
      }
    }

    InputElement standardHtmlAttribute = standardHtmlAttributes[attribute.name];
    if (standardHtmlAttribute != null) {
      // Don't typecheck html inputs. Those become attributes, not properties,
      // which means strings values are OK.
      SourceRange range =
          new SourceRange(attribute.nameOffset, attribute.name.length);
      template.addRange(range, standardHtmlAttribute);
      attribute.parent.boundStandardInputs
          .add(new InputBinding(standardHtmlAttribute, attribute));
    }

    // visit mustaches inside
    super.visitTextAttr(attribute);
  }

  void _typecheckMatchingInput(
      ExpressionBoundAttribute attr, InputElement input) {
    // half-complete-code case: ensure the expression is actually there
    if (attr.expression != null) {
      var attrType = attr.expression.bestType;
      var inputType = input.setterType;

      if (!attrType.isAssignableTo(inputType)) {
        errorListener.onError(new AnalysisError(
            templateSource,
            attr.valueOffset,
            attr.value.length,
            AngularWarningCode.INPUT_BINDING_TYPE_ERROR,
            [attrType, inputType]));
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
  _resolveClassAttribute(ExpressionBoundAttribute attribute) {
    if (!_isCssIdentifier(attribute.name)) {
      errorListener.onError(new AnalysisError(
          templateSource,
          attribute.nameOffset,
          attribute.name.length,
          AngularWarningCode.INVALID_HTML_CLASSNAME,
          [attribute.name]));
    }

    // half-complete-code case: ensure the expression is actually there
    if (attribute.expression != null &&
        !attribute.expression.bestType.isAssignableTo(typeProvider.boolType)) {
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
  _resolveStyleAttribute(ExpressionBoundAttribute attribute) {
    var cssPropertyName = attribute.name;
    var dotpos = attribute.name.indexOf('.');
    if (dotpos != -1) {
      cssPropertyName = attribute.name.substring(0, dotpos);
      var cssUnitName = attribute.name.substring(dotpos + '.'.length);
      var validUnitName =
          styleWithPercent.contains(cssPropertyName) && cssUnitName == '%';
      validUnitName = validUnitName || _isCssIdentifier(cssUnitName);
      if (!validUnitName) {
        errorListener.onError(new AnalysisError(
            templateSource,
            attribute.nameOffset + dotpos + 1,
            cssUnitName.length,
            AngularWarningCode.INVALID_CSS_UNIT_NAME,
            [cssUnitName]));
      }
      // half-complete-code case: ensure the expression is actually there
      if (attribute.expression != null &&
          !attribute.expression.bestType.isAssignableTo(typeProvider.numType)) {
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
          attribute.nameOffset,
          cssPropertyName.length,
          AngularWarningCode.INVALID_CSS_PROPERTY_NAME,
          [cssPropertyName]));
    }
  }

  /**
   * Resolve attributes of type [attribute.some-attribute]="someExpr"
   */
  _resolveAttributeBoundAttribute(ExpressionBoundAttribute attribute) {
    // TODO validate the type? Or against a dictionary?
    // note that the attribute name is valid by definition as it was discovered
    // within an attribute! (took me a while to realize why I couldn't make any
    // failing tests for this)
  }

  /**
   * Resolve the given [AstNode] ([expression] or [statement]) and report errors.
   */
  void _resolveDartAstNode(AstNode astNode, bool acceptAssignment) {
    ClassElement classElement = view.classElement;
    LibraryElement library = classElement.library;
    {
      TypeResolverVisitor visitor = new TypeResolverVisitor(
          library, view.source, typeProvider, errorListener);
      astNode.accept(visitor);
    }
    ResolverVisitor resolver = new AngularResolverVisitor(
        library, templateSource, typeProvider, errorListener, acceptAssignment);
    // fill the name scope
    ClassScope classScope = new ClassScope(resolver.nameScope, classElement);
    EnclosedScope localScope = new EnclosedScope(classScope);
    resolver.nameScope = localScope;
    resolver.enclosingClass = classElement;
    localVariables.values.forEach((LocalVariable local) {
      localScope.define(local.dartVariable);
    });
    // do resolve
    astNode.accept(resolver);
    // verify
    ErrorVerifier verifier = new AngularErrorVerifier(errorReporter, library,
        typeProvider, new InheritanceManager(library), acceptAssignment);
    astNode.accept(verifier);
  }

  /**
   * Resolve the Dart expression with the given [code] at [offset].
   */
  _resolveDartExpression(Expression expression) {
    if (expression != null) {
      _resolveDartAstNode(expression, false);
    }
  }

  /**
   * Resolve the Dart ExpressionStatement with the given [code] at [offset].
   */
  void _resolveDartExpressionStatements(List<Statement> statements) {
    for (Statement statement in statements) {
      if (statement is! ExpressionStatement && statement is! EmptyStatement) {
        errorListener.onError(new AnalysisError(
            templateSource,
            statement.offset,
            (statement.endToken.type == TokenType.SEMICOLON)
                ? statement.length - 1
                : statement.length,
            AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
            [_getOutputStatementErrorDescription(statement)]));
      } else {
        _resolveDartAstNode(statement, true);
      }
    }
  }

  /**
   * Get helpful description based on statement type to report in
   * OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT
   */
  String _getOutputStatementErrorDescription(Statement stmt) {
    String potentialToken = stmt.beginToken.keyword.toString().toLowerCase();
    if (potentialToken != "null") {
      return "token '" + potentialToken + "'";
    } else {
      return stmt.runtimeType.toString().replaceFirst("Impl", "");
    }
  }

  /**
   * Record [ResolvedRange]s for the given [AstNode].
   */
  void _recordAstNodeResolvedRanges(AstNode astNode) {
    Map<LocalVariableElement, LocalVariable> dartVariables =
        new HashMap<LocalVariableElement, LocalVariable>();

    for (LocalVariable localVariable in localVariables.values) {
      dartVariables[localVariable.dartVariable] = localVariable;
    }

    if (astNode != null) {
      astNode.accept(new _DartReferencesRecorder(template, dartVariables));
    }
  }
}

/**
 * Workaround for "This mixin application is invalid because all of the
 * constructors in the base class 'ResolverVisitor' have optional parameters."
 * in the definition of [AngularResolverVisitor].
 *
 * See https://github.com/dart-lang/sdk/issues/15101 for details
 */
class _IntermediateResolverVisitor extends ResolverVisitor {
  _IntermediateResolverVisitor(LibraryElement library, Source source,
      TypeProvider typeProvider, AnalysisErrorListener errorListener)
      : super(library, source, typeProvider, errorListener);
}

/**
 * Override the standard [ResolverVisitor] class to report unacceptable nodes,
 * while suppressing secondary errors that would have been raised by
 * [ResolverVisitor] if we let it see the bogus definitions.
 */
class AngularResolverVisitor extends _IntermediateResolverVisitor
    with ReportUnacceptableNodesMixin {
  final bool acceptAssignment;

  AngularResolverVisitor(
      LibraryElement library,
      Source source,
      TypeProvider typeProvider,
      AnalysisErrorListener errorListener,
      this.acceptAssignment)
      : super(library, source, typeProvider, errorListener);

  @override
  Object visitAsExpression(AsExpression exp) {
    // This means we generated this in a pipe, and its OK.
    if (exp.asOperator.offset == 0) {
      return super.visitAsExpression(exp);
    } else {
      return _reportUnacceptableNode(exp, "As expression");
    }
  }

  @override
  Object visitIsExpression(IsExpression exp) =>
      _reportUnacceptableNode(exp, "Is expression");

  @override
  Object visitThrowExpression(ThrowExpression exp) =>
      _reportUnacceptableNode(exp, "Throw");

  @override
  Object visitSuperExpression(SuperExpression exp) =>
      _reportUnacceptableNode(exp, "Super references");

  @override
  Object visitAssignmentExpression(AssignmentExpression exp) {
    // Only block reassignment of locals, not poperties. Resolve elements to
    // check that.
    exp.leftHandSide.accept(elementResolver);
    VariableElement element = getOverridableStaticElement(exp.leftHandSide) ??
        getOverridablePropagatedElement(exp.leftHandSide);
    if ((element == null || element is PropertyInducingElement) &&
        acceptAssignment) {
      return super.visitAssignmentExpression(exp);
    } else {
      _reportUnacceptableNode(exp, "Assignment of locals");
      return null;
    }
  }

  @override
  Object visitCascadeExpression(CascadeExpression exp) {
    _reportUnacceptableNode(exp, "Cascades", false);
    // Only resolve the target, not the cascade sections.
    return exp.target.accept(this);
  }

  @override
  Object visitAwaitExpression(AwaitExpression exp) =>
      _reportUnacceptableNode(exp, "Await");

  @override
  Object visitFunctionExpression(FunctionExpression exp) =>
      _reportUnacceptableNode(exp, "Anonymous functions", false);

  @override
  Object visitSymbolLiteral(SymbolLiteral exp) =>
      _reportUnacceptableNode(exp, "Symbol literal");

  @override
  Object visitNamedExpression(NamedExpression exp) =>
      _reportUnacceptableNode(exp, "Named arguments");
}

/**
 * Override the standard [ErrorVerifier] class to report unacceptable nodes,
 * while suppressing secondary errors that would have been raised by
 * [ErrorVerifier] if we let it see the bogus definitions.
 */
class AngularErrorVerifier extends ErrorVerifier
    with ReportUnacceptableNodesMixin {
  final bool acceptAssignment;
  ErrorReporter errorReporter;
  TypeProvider typeProvider;
  AngularErrorVerifier(
      ErrorReporter errorReporter,
      LibraryElement library,
      TypeProvider typeProvider,
      InheritanceManager inheritanceManager,
      this.acceptAssignment)
      : errorReporter = errorReporter,
        typeProvider = typeProvider,
        super(errorReporter, library, typeProvider, inheritanceManager, false);

  @override
  Object visitFunctionExpression(FunctionExpression exp) {
    // error reported in [AngularResolverVisitor] but [ErrorVerifier] crashes
    // because it isn't resolved
    return null;
  }

  @override
  Object visitRethrowExpression(RethrowExpression exp) =>
      _reportUnacceptableNode(exp, "Rethrow");

  @override
  Object visitThisExpression(ThisExpression exp) =>
      _reportUnacceptableNode(exp, "This references");

  @override
  Object visitListLiteral(ListLiteral list) {
    if (list.typeArguments != null) {
      _reportUnacceptableNode(list, "Typed list literals");
      return null;
    } else {
      return super.visitListLiteral(list);
    }
  }

  @override
  Object visitMapLiteral(MapLiteral map) {
    if (map.typeArguments != null) {
      _reportUnacceptableNode(map, "Typed map literals");
      return null;
    } else {
      return super.visitMapLiteral(map);
    }
  }

  @override
  Object visitInstanceCreationExpression(InstanceCreationExpression exp) =>
      _reportUnacceptableNode(exp, "Usage of new");

  @override
  Object visitAssignmentExpression(AssignmentExpression exp) {
    // match ResolverVisitor to prevent fallout errors
    VariableElement element = getOverridableStaticElement(exp.leftHandSide) ??
        getOverridablePropagatedElement(exp.leftHandSide);
    if ((element == null || element is PropertyInducingElement) &&
        acceptAssignment) {
      return super.visitAssignmentExpression(exp);
    } else {
      exp.visitChildren(this);
      return null;
    }
  }

  /**
   * Copied from ResolverVisitor
   */
  VariableElement getOverridablePropagatedElement(Expression expression) {
    Element element = null;
    if (expression is SimpleIdentifier) {
      element = expression.propagatedElement;
    } else if (expression is PrefixedIdentifier) {
      element = expression.propagatedElement;
    } else if (expression is PropertyAccess) {
      element = expression.propertyName.propagatedElement;
    }
    if (element is VariableElement) {
      return element;
    }
    return null;
  }

  /**
   * Copied from ResolverVisitor
   */
  VariableElement getOverridableStaticElement(Expression expression) {
    Element element = null;
    if (expression is SimpleIdentifier) {
      element = expression.staticElement;
    } else if (expression is PrefixedIdentifier) {
      element = expression.staticElement;
    } else if (expression is PropertyAccess) {
      element = expression.propertyName.staticElement;
    }
    if (element is VariableElement) {
      return element;
    }
    return null;
  }
}

abstract class ReportUnacceptableNodesMixin
    implements RecursiveAstVisitor<Object> {
  ErrorReporter get errorReporter;
  TypeProvider get typeProvider;
  void _reportUnacceptableNode(Expression node, String description,
      [bool visitChildren = true]) {
    errorReporter.reportErrorForNode(
        AngularWarningCode.DISALLOWED_EXPRESSION, node, [description]);

    // "resolve" the node, a null type causes later errors.
    node.propagatedType = node.staticType = typeProvider.dynamicType;
    if (visitChildren) {
      node.visitChildren(this);
    }
  }
}
