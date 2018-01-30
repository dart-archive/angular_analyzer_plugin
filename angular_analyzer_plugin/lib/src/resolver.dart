library angular2.src.analysis.analyzer_plugin.src.resolver;

import 'dart:collection';
import 'package:meta/meta.dart';

import 'package:analyzer/dart/ast/ast.dart' hide Directive;
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
import 'package:angular_analyzer_plugin/src/facade/exports_library_element.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/options.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';
import 'package:angular_analyzer_plugin/errors.dart';
import 'package:angular_analyzer_plugin/ast.dart';

/// The implementation of [ElementView] using [AttributeInfo]s.
class ElementViewImpl implements ElementView {
  @override
  final attributeNameSpans = <String, SourceRange>{};

  @override
  final attributeValueSpans = <String, SourceRange>{};

  @override
  final attributes = <String, String>{};

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

  ElementViewImpl(List<AttributeInfo> attributeInfoList,
      {ElementInfo element, String elementName}) {
    for (final attribute in attributeInfoList) {
      if (attribute is TemplateAttribute) {
        continue;
      }
      final name = attribute.name;
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
    } else if (elementName != null) {
      localName = elementName;
    }
  }
}

/// A variable defined by a [AbstractDirective].
class InternalVariable {
  final String name;
  final AngularElement element;
  final DartType type;

  InternalVariable(this.name, this.element, this.type);
}

/// [TemplateResolver]s resolve [Template]s.
class TemplateResolver {
  final TypeProvider typeProvider;
  final List<Component> standardHtmlComponents;
  final Map<String, OutputElement> standardHtmlEvents;
  final Map<String, InputElement> standardHtmlAttributes;
  final AngularOptions options;
  final AnalysisErrorListener errorListener;
  final StandardAngular standardAngular;
  final StandardHtml standardHtml;

  Template template;
  View view;
  Source templateSource;
  ErrorReporter errorReporter;

  /// The full map of names to internal variables in the current template.
  var internalVariables = new HashMap<String, InternalVariable>();

  /// The full map of names to local variables in the current template.
  var localVariables = new HashMap<String, LocalVariable>();

  TemplateResolver(
      this.typeProvider,
      this.standardHtmlComponents,
      this.standardHtmlEvents,
      this.standardHtmlAttributes,
      this.standardAngular,
      this.standardHtml,
      this.errorListener,
      this.options);

  void resolve(Template template) {
    this.template = template;
    view = template.view;
    templateSource = view.templateSource;
    errorReporter = new ErrorReporter(errorListener, templateSource);

    final root = template.ast;

    final allDirectives = <AbstractDirective>[]
      ..addAll(standardHtmlComponents)
      ..addAll(view.directives);

    final directiveResolver = new DirectiveResolver(
        allDirectives,
        templateSource,
        template,
        standardAngular,
        standardHtml,
        errorReporter,
        errorListener,
        new Set<String>.from(options.customTagNames));
    root.accept(directiveResolver);
    final contentResolver =
        new ComponentContentResolver(templateSource, template, errorListener);
    root.accept(contentResolver);

    _resolveScope(root);
  }

  /// Resolve the given [element]. This will either be a template or the root of
  /// the template, meaning it has its own scope. We have to resolve the
  /// outermost scopes first so that ngFor variables have types.
  ///
  /// See the comment block for [PrepareScopeVisitor] for the most detailed
  /// breakdown of what we do and why.
  ///
  /// Requires that we've already resolved the directives down the tree.
  void _resolveScope(ElementInfo element) {
    if (element == null) {
      return;
    }
    // apply template attributes
    final oldLocalVariables = localVariables;
    final oldInternalVariables = internalVariables;
    internalVariables = new HashMap.from(internalVariables);
    localVariables = new HashMap.from(localVariables);
    try {
      final dartVarManager =
          new DartVariableManager(template, templateSource, errorListener);
      // Prepare the scopes
      element
        ..accept(new PrepareScopeVisitor(
            internalVariables,
            localVariables,
            template,
            templateSource,
            typeProvider,
            dartVarManager,
            errorListener,
            standardAngular))
        // Load $event into the scopes
        ..accept(new PrepareEventScopeVisitor(
            standardHtmlEvents,
            template,
            templateSource,
            localVariables,
            typeProvider,
            dartVarManager,
            errorListener))
        // Resolve the scopes
        ..accept(new SingleScopeResolver(standardHtmlAttributes, view, template,
            templateSource, typeProvider, errorListener, errorReporter));

      // Now the next scope is ready to be resolved
      final tplSearch = new NextTemplateElementsSearch();
      element.accept(tplSearch);
      for (final templateElement in tplSearch.results) {
        _resolveScope(templateElement);
      }
    } finally {
      internalVariables = oldInternalVariables;
      localVariables = oldLocalVariables;
    }
  }
}

/// An [AstVisitor] that records references to Dart [Element]s into
/// the given [template].
class _DartReferencesRecorder extends RecursiveAstVisitor {
  final Map<Element, AngularElement> dartToAngularMap;
  final Template template;

  _DartReferencesRecorder(this.template, this.dartToAngularMap);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    final dartElement = node.bestElement;
    if (dartElement != null) {
      final angularElement =
          dartToAngularMap[dartElement] ?? new DartElement(dartElement);
      final range = new SourceRange(node.offset, node.length);
      template.addRange(range, angularElement);
    }
  }
}

/// Probably the most important visitor to understand in how we process angular
/// templates.
///
/// First its important to note how angular scopes are determined by templates;
/// that's how ngFor adds a variable below. Its also important to note that
/// unlike in most languages, angular template semantics lets you use a variable
/// before its declared, ie `<a>{{b}}</a><p #b></p>` so long as they share a
/// scope. Also note that a template both ends a scope and begins it: all
/// the bindings in the template are from the old scope, and yet let-vars add to
/// the new new scope.
///
/// This means we need to have a multiple-pass process, and that means we spend
/// a good chunk of time merely following the rules of scoping. This visitor
/// will enforce that for you.
///
/// Just don't @override visitElementInfo (or do so carefully), and this visitor
/// naturally walk over all the attributes in scope by what you give it. You can
/// also hook into what happens when it hits the elements by overriding:
///
/// * visitBorderScopeTemplateAttribute(templateAttribute)
/// * visitScopeRootElementWithTemplateAttribute(element)
/// * visitBorderScopeTemplateElement(element)
/// * visitScopeRootTemplateElement(element)
/// * visitElementInScope(element)
///
/// Which should allow you to do specialty things, such as what the
/// [PrepareScopeVisitor] does by using out-of-scope properties to affect the
/// in-scope ones.
class AngularScopeVisitor extends AngularAstVisitor {
  bool visitingRoot = true;

  @override
  void visitDocumentInfo(DocumentInfo document) {
    visitingRoot = false;
    visitElementInScope(document);
  }

  @override
  void visitElementInfo(ElementInfo element) {
    final isRoot = visitingRoot;
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
    for (var child in element.childNodes) {
      child.accept(this);
    }
  }

  void visitBorderScopeTemplateElement(ElementInfo element) {
    // the attributes are in this scope, the children aren't
    for (final attr in element.attributes) {
      attr.accept(this);
    }
  }

  void visitScopeRootElementWithTemplateAttribute(ElementInfo element) {
    final children =
        element.children.where((child) => child is! TemplateAttribute);
    for (final child in children) {
      child.accept(this);
    }
  }

  void visitBorderScopeTemplateAttribute(TemplateAttribute attr) {
    // Border to the next scope. The virtual properties belong here, the real
    // element does not
    visitTemplateAttr(attr);
  }

  void visitElementInScope(ElementInfo element) {
    for (final child in element.children) {
      child.accept(this);
    }
  }
}

/// We have to collect all vars and their types before we can resolve the
/// bindings, since variables can be used before they are declared. This does
/// that.
///
/// It loads each node's [localVariables] property so that the resolver has
/// everything it needs, keeping those local variables around for autocomplete.
/// As the scope is built up it is attached to the nodes -- and thanks to
/// mutability + a shared reference, that works just fine.
///
/// However, `$event` vars require a copy of the scope, not a shared reference,
/// so that the `$event` can be added. Therefore this visitor does not handle
/// output bindings. That is [PrepareEventScopeVisitor]'s job, only to be
/// performed after this step has completed.
class PrepareScopeVisitor extends AngularScopeVisitor {
  /// The full map of names to internal variables in the current scope
  final Map<String, InternalVariable> internalVariables;

  /// The full map of names to local variables in the current scope
  final Map<String, LocalVariable> localVariables;

  final Template template;
  final Source templateSource;
  final TypeProvider typeProvider;
  final DartVariableManager dartVariableManager;
  final AnalysisErrorListener errorListener;
  final StandardAngular standardAngular;

  PrepareScopeVisitor(
      this.internalVariables,
      this.localVariables,
      this.template,
      this.templateSource,
      this.typeProvider,
      this.dartVariableManager,
      this.errorListener,
      this.standardAngular);

  @override
  void visitScopeRootTemplateElement(ElementInfo element) {
    final exportAsMap = _defineExportAsVariables(element.directives);
    for (final directive in element.directives) {
      // This must be here for <template> tags.
      _defineNgForVariables(element.attributes, directive);
    }

    _defineReferenceVariablesForAttributes(
        element.directives, element.attributes, exportAsMap);
    _defineLetVariablesForAttributes(element.attributes);

    super.visitScopeRootTemplateElement(element);
  }

  @override
  void visitBorderScopeTemplateElement(ElementInfo element) {
    final exportAsMap = _defineExportAsVariables(element.directives);
    _defineReferenceVariablesForAttributes(
        element.directives, element.attributes, exportAsMap);
    super.visitBorderScopeTemplateElement(element);
  }

  @override
  void visitScopeRootElementWithTemplateAttribute(ElementInfo element) {
    final templateAttr = element.templateAttribute;

    final exportAsMap = _defineExportAsVariables(element.directives);

    // If this is how our scope begins, like we're within an ngFor, then
    // let the ngFor alter the current scope.
    for (final directive in templateAttr.directives) {
      _defineNgForVariables(templateAttr.virtualAttributes, directive);
    }

    _defineLetVariablesForAttributes(templateAttr.virtualAttributes);

    // Make sure the regular element also alters the current scope
    for (final directive in element.directives) {
      // This must be here for <template> tags.
      _defineNgForVariables(element.attributes, directive);
    }

    _defineReferenceVariablesForAttributes(
        element.directives, element.attributes, exportAsMap);

    super.visitScopeRootElementWithTemplateAttribute(element);
  }

  @override
  void visitBorderScopeTemplateAttribute(TemplateAttribute attr) {
    // Border to the next scope. Make sure the virtual properties are bound
    // to the scope we're building now. But nothing else.
    visitTemplateAttr(attr);
  }

  @override
  void visitElementInScope(ElementInfo element) {
    final exportAsMap = _defineExportAsVariables(element.directives);
    // Regular element or component. Look for `#var`s.
    _defineReferenceVariablesForAttributes(
        element.directives, element.attributes, exportAsMap);
    super.visitElementInScope(element);
  }

  @override
  void visitMustache(Mustache mustache) {
    mustache.localVariables = localVariables;
  }

  @override
  void visitExpressionBoundAttr(ExpressionBoundAttribute attr) {
    attr.localVariables = localVariables;
  }

  void _defineNgForVariables(
      List<AttributeInfo> attributes, AbstractDirective directive) {
    // TODO(scheglov) Once Angular has a way to describe variables, reimplement
    // https://github.com/angular/angular/issues/4850
    if (directive.name == 'NgFor') {
      final dartElem =
          new DartElement((directive as AbstractClassDirective).classElement);
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
      for (final attribute in attributes) {
        if (attribute is ExpressionBoundAttribute &&
            attribute.name == 'ngForOf' &&
            attribute.expression != null) {
          final itemType = _getIterableItemType(attribute.expression);
          internalVariables[r'$implicit'] =
              new InternalVariable(r'$implicit', dartElem, itemType);
        }
      }
    }
  }

  /// Provides a map for 'exportAs' string to list ofclass element.
  /// Return type must be a class to later resolve conflicts should they exist.
  /// This is a shortlived variable existing only in the scope of
  /// element tag, therefore don't use [internalVariables].
  Map<String, List<InternalVariable>> _defineExportAsVariables(
      List<AbstractDirective> directives) {
    final exportAsMap = <String, List<InternalVariable>>{};
    for (final directive in directives) {
      final exportAs = directive.exportAs;
      if (exportAs != null && directive is AbstractClassDirective) {
        final name = exportAs.name;
        final type = directive.classElement.type;
        exportAsMap.putIfAbsent(name, () => <InternalVariable>[]);
        exportAsMap[name].add(new InternalVariable(name, exportAs, type));
      }
    }
    return exportAsMap;
  }

  /// Define reference variables [localVariables] for `#name` attributes.
  void _defineReferenceVariablesForAttributes(
      List<AbstractDirective> directives,
      List<AttributeInfo> attributes,
      Map<String, List<InternalVariable>> exportAsMap) {
    for (final attribute in attributes) {
      var offset = attribute.nameOffset;
      var name = attribute.name;

      // check if defines local variable
      final isRef = name.startsWith('ref-'); // not ng-for
      final isHash = name.startsWith('#'); // not ng-for
      final isVar =
          name.startsWith('var-'); // either (deprecated but still works)
      if (isHash || isVar || isRef) {
        final prefixLen = isHash ? 1 : 4;
        name = name.substring(prefixLen);
        offset += prefixLen;
        final refValue = attribute.value;

        // maybe an internal variable reference
        var type = typeProvider.dynamicType;
        AngularElement angularElement;

        if (refValue == null) {
          // Find the corresponding Component to assign reference to.
          for (final directive in directives) {
            if (directive is Component) {
              var classElement = directive.classElement;
              if (classElement.name == 'TemplateElement') {
                classElement = standardAngular.templateRef;
              }
              type = classElement.type;
              angularElement = new DartElement(classElement);
              break;
            }
          }
        } else {
          final internalVars = exportAsMap[refValue];
          if (internalVars == null || internalVars.isEmpty) {
            errorListener.onError(new AnalysisError(
              templateSource,
              attribute.valueOffset,
              attribute.value.length,
              AngularWarningCode.NO_DIRECTIVE_EXPORTED_BY_SPECIFIED_NAME,
              [attribute.value],
            ));
          } else if (internalVars.length > 1) {
            errorListener.onError(new AnalysisError(
              templateSource,
              attribute.valueOffset,
              attribute.value.length,
              AngularWarningCode.DIRECTIVE_EXPORTED_BY_AMBIGIOUS,
              [attribute.value],
            ));
          } else {
            final internalVar = internalVars[0];
            type = internalVar.type;
            angularElement = internalVar.element;
          }
        }

        if (attribute.value != null) {
          template.addRange(
            new SourceRange(attribute.valueOffset, attribute.valueLength),
            angularElement,
          );
        }

        final localVariableElement =
            dartVariableManager.newLocalVariableElement(offset, name, type);
        final localVariable = new LocalVariable(
            name, offset, name.length, templateSource, localVariableElement);
        localVariables[name] = localVariable;
        template.addRange(
          new SourceRange(localVariable.nameOffset, localVariable.name.length),
          localVariable,
        );
      }
    }
  }

  /// Define reference variables [localVariables] for `#name` attributes.
  ///
  /// Begin by defining the type as 'dynamic'.
  /// In cases of *ngFor, this dynamic type is overwritten only if
  /// the value is defined within [internalVariables]. If value is null,
  /// it defaults to '$implicit'. If value is provided but isn't one of
  /// known implicit variables of ngFor, we can't throw an error since
  /// the value could still be defined.
  /// if '$implicit' is not defined within [internalVariables], we again
  /// default it to dynamicType.
  void _defineLetVariablesForAttributes(List<AttributeInfo> attributes) {
    for (final attribute in attributes) {
      var offset = attribute.nameOffset;
      var name = attribute.name;
      final value = attribute.value;

      if (name.startsWith('let-')) {
        final prefixLength = 'let-'.length;
        name = name.substring(prefixLength);
        offset += prefixLength;
        var type = typeProvider.dynamicType;

        final internalVar = internalVariables[value ?? r'$implicit'];
        if (internalVar != null) {
          type = internalVar.type;
          if (value != null) {
            template.addRange(
              new SourceRange(attribute.valueOffset, attribute.valueLength),
              internalVar.element,
            );
          }
        }

        final localVariableElement =
            dartVariableManager.newLocalVariableElement(-1, name, type);
        final localVariable = new LocalVariable(
            name, offset, name.length, templateSource, localVariableElement);
        localVariables[name] = localVariable;
        template.addRange(
          new SourceRange(offset, name.length),
          localVariable,
        );
      }
    }
  }

  DartType _getIterableItemType(Expression expression) {
    final itemsType = expression.bestType;
    if (itemsType is InterfaceType) {
      final iteratorType = _lookupGetterReturnType(itemsType, 'iterator');
      if (iteratorType is InterfaceType) {
        final currentType = _lookupGetterReturnType(iteratorType, 'current');
        if (currentType != null) {
          return currentType;
        }
      }
    }
    return typeProvider.dynamicType;
  }

  /// Return the return type of the executable element with the given [name].
  /// May return `null` if the [type] does not define one.
  DartType _lookupGetterReturnType(InterfaceType type, String name) =>
      type.lookUpInheritedGetter(name)?.returnType;
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
          new CompilationUnitElementImpl(templateSource.fullName)
            ..source = templateSource;
      htmlClassElement = new ClassElementImpl('AngularTemplateClass', -1);
      htmlCompilationUnitElement.types = <ClassElement>[htmlClassElement];
      htmlMethodElement = new MethodElementImpl('angularTemplateMethod', -1);
      htmlClassElement.methods = <MethodElement>[htmlMethodElement];
    }
    // add a new local variable
    final localVariable = new LocalVariableElementImpl(name, offset);
    localVariable.name.length;
    localVariable.type = type;

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
  void visitElementInfo(ElementInfo elem) {
    directives = elem.directives;
    super.visitElementInfo(elem);
  }

  @override
  void visitTemplateAttr(TemplateAttribute templateAttr) {
    directives = templateAttr.directives;
    super.visitTemplateAttr(templateAttr);
  }

  @override
  void visitStatementsBoundAttr(StatementsBoundAttribute attr) {
    if (attr.reductions.isNotEmpty &&
        attr.name != 'keyup' &&
        attr.name != 'keydown') {
      errorListener.onError(new AnalysisError(
          templateSource,
          attr.reductionsOffset,
          attr.reductionsLength,
          AngularWarningCode.EVENT_REDUCTION_NOT_ALLOWED));
    }

    var eventType = typeProvider.dynamicType;
    var matched = false;

    for (final directiveBinding in attr.parent.boundDirectives) {
      for (final output in directiveBinding.boundDirective.outputs) {
        //TODO what if this matches two directives?
        if (output.name == attr.name) {
          eventType = output.eventType;
          matched = true;
          final range = new SourceRange(attr.nameOffset, attr.name.length);
          template.addRange(range, output);
          directiveBinding.outputBindings.add(new OutputBinding(output, attr));
        }
      }
    }

    //standard HTML events bubble up, so everything supports them
    if (!matched) {
      final standardHtmlEvent = standardHtmlEvents[attr.name];
      if (standardHtmlEvent != null) {
        matched = true;
        eventType = standardHtmlEvent.eventType;
        final range = new SourceRange(attr.nameOffset, attr.name.length);
        template.addRange(range, standardHtmlEvent);
        attr.parent.boundStandardOutputs
            .add(new OutputBinding(standardHtmlEvent, attr));
      }
    }

    if (!matched && !isOnCustomTag(attr)) {
      errorListener.onError(new AnalysisError(
          templateSource,
          attr.nameOffset,
          attr.name.length,
          AngularWarningCode.NONEXIST_OUTPUT_BOUND,
          [attr.name]));
    }

    attr.localVariables = new HashMap.from(localVariables);
    final localVariableElement =
        dartVariableManager.newLocalVariableElement(-1, r'$event', eventType);
    final localVariable = new LocalVariable(
        r'$event', -1, 6, templateSource, localVariableElement);
    attr.localVariables[r'$event'] = localVariable;
  }
}

/// Use this visitor to find the nested scopes within the [ElementInfo]
/// you visit.
class NextTemplateElementsSearch extends AngularAstVisitor {
  bool visitingRoot = true;

  final results = <ElementInfo>[];

  @override
  void visitDocumentInfo(DocumentInfo document) {
    visitingRoot = false;
    for (final child in document.childNodes) {
      child.accept(this);
    }
  }

  @override
  void visitElementInfo(ElementInfo element) {
    if (element.isOrHasTemplateAttribute && !visitingRoot) {
      results.add(element);
      return;
    }

    visitingRoot = false;
    for (final child in element.childNodes) {
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
  final StandardHtml _standardHtml;
  final outerBindings = <DirectiveBinding>[];
  final outerElements = <ElementInfo>[];
  final Set<String> customTagNames;

  DirectiveResolver(
      this.allDirectives,
      this.templateSource,
      this.template,
      this._standardAngular,
      this._standardHtml,
      this._errorReporter,
      this.errorListener,
      this.customTagNames);

  @override
  void visitElementInfo(ElementInfo element) {
    outerElements.add(element);
    if (element.templateAttribute != null) {
      visitTemplateAttr(element.templateAttribute);
    }

    final elementView =
        new ElementViewImpl(element.attributes, element: element);
    final unmatchedDirectives = <AbstractDirective>[];

    final containingDirectivesCount = outerBindings.length;
    for (final directive in allDirectives) {
      final match = directive.selector.match(elementView, template);
      if (match != SelectorMatch.NoMatch) {
        final binding = new DirectiveBinding(directive);
        element.boundDirectives.add(binding);
        if (match == SelectorMatch.TagMatch) {
          element.tagMatchedAsDirective = true;
        }

        // optimization: only add the bindings that care about content child
        if (directive.contentChilds.isNotEmpty ||
            directive.contentChildren.isNotEmpty) {
          outerBindings.add(binding);
        }

        // Specifically exclude NgIf and NgFor, they have their own error since
        // we *know* they require a template.
        if (directive.looksLikeTemplate &&
            !element.isTemplate &&
            directive.name != "NgIf" &&
            directive.name != "NgFor") {
          _reportErrorForRange(
              element.openingSpan,
              AngularWarningCode.CUSTOM_DIRECTIVE_MAY_REQUIRE_TEMPLATE,
              [directive.name]);
        }
      } else {
        unmatchedDirectives.add(directive);
      }
    }

    for (final directive in unmatchedDirectives) {
      if (directive is AbstractDirective &&
          directive.selector.availableTo(elementView) &&
          !directive.looksLikeTemplate) {
        element.availableDirectives[directive] =
            directive.selector.getAttributeSelectors(elementView);
      }
    }

    element.tagMatchedAsCustomTag = customTagNames.contains(element.localName);

    if (!element.isTemplate) {
      _checkNoStructuralDirectives(element.attributes);
    }

    recordContentChildren(element);

    for (final child in element.childNodes) {
      child.accept(this);
    }

    outerBindings.removeRange(containingDirectivesCount, outerBindings.length);
    outerElements.removeLast();
  }

  @override
  void visitTemplateAttr(TemplateAttribute attr) {
    final elementView =
        new ElementViewImpl(attr.virtualAttributes, elementName: 'template');
    for (final directive in allDirectives) {
      if (directive.selector.match(elementView, template) !=
          SelectorMatch.NoMatch) {
        attr.boundDirectives.add(new DirectiveBinding(directive));
      }
    }

    final templateAttrIsUsed =
        attr.directives.any((directive) => directive.looksLikeTemplate);

    if (!templateAttrIsUsed) {
      _reportErrorForRange(
          new SourceRange(attr.originalNameOffset, attr.originalName.length),
          AngularWarningCode.TEMPLATE_ATTR_NOT_USED);
    }
  }

  void _checkNoStructuralDirectives(List<AttributeInfo> attributes) {
    for (final attribute in attributes) {
      if (attribute is! TextAttribute) {
        continue;
      }

      if (attribute.name == 'ngFor' || attribute.name == 'ngIf') {
        _reportErrorForRange(
            new SourceRange(attribute.nameOffset, attribute.name.length),
            AngularWarningCode.STRUCTURAL_DIRECTIVES_REQUIRE_TEMPLATE,
            [attribute.name]);
      }
    }
  }

  void recordContentChildren(ElementInfo element) {
    for (final binding in outerBindings) {
      for (var contentChild in binding.boundDirective.contentChilds) {
        // an already matched ContentChild shouldn't look inside that match
        if (binding.contentChildBindings[contentChild]?.boundElements
                ?.any(outerElements.contains) ==
            true) {
          continue;
        }

        if (contentChild.query
            .match(element, _standardAngular, _standardHtml, _errorReporter)) {
          binding.contentChildBindings.putIfAbsent(
              contentChild,
              () => new ContentChildBinding(
                  binding.boundDirective, contentChild));

          if (binding
              .contentChildBindings[contentChild].boundElements.isNotEmpty) {
            _errorReporter.reportErrorForOffset(
                AngularWarningCode.SINGULAR_CHILD_QUERY_MATCHED_MULTIPLE_TIMES,
                element.offset,
                element.length,
                [binding.boundDirective.name, contentChild.field.fieldName]);
          }
          binding.contentChildBindings[contentChild].boundElements.add(element);

          if (element.parent.boundDirectives.contains(binding)) {
            element.tagMatchedAsImmediateContentChild = true;
          }
        }
      }

      for (var contentChildren in binding.boundDirective.contentChildren) {
        if (contentChildren.query
            .match(element, _standardAngular, _standardHtml, _errorReporter)) {
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
    var tagIsStandard = _isStandardTagName(element.localName);
    Component component;

    for (final directive in element.directives) {
      if (directive is Component) {
        component = directive;
        // TODO better html tag detection, see #248
        tagIsStandard = component.isHtml;
      }
    }

    if (!tagIsStandard &&
        !element.tagMatchedAsTransclusion &&
        !element.tagMatchedAsDirective &&
        !element.tagMatchedAsCustomTag) {
      _reportErrorForRange(element.openingNameSpan,
          AngularWarningCode.UNRESOLVED_TAG, [element.localName]);
    }

    if (!tagIsStandard) {
      checkTransclusionsContentChildren(component, element.childNodes,
          tagIsStandard: tagIsStandard);
    }

    for (final child in element.childNodes) {
      child.accept(this);
    }
  }

  void checkTransclusionsContentChildren(
      Component component, List<NodeInfo> children,
      {@required bool tagIsStandard}) {
    if (component?.ngContents == null) {
      return;
    }

    final acceptAll = component.ngContents.any((s) => s.matchesAll);
    for (final child in children) {
      if (child is TextInfo && !acceptAll && child.text.trim() != "") {
        _reportErrorForRange(new SourceRange(child.offset, child.length),
            AngularWarningCode.CONTENT_NOT_TRANSCLUDED);
      } else if (child is ElementInfo) {
        final view = new ElementViewImpl(child.attributes, element: child);

        var matched = acceptAll;
        var matchedTag = false;

        for (final ngContent in component.ngContents) {
          final match = ngContent.matchesAll
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

  /// Check whether the given [name] is a standard HTML5 tag name.
  bool _isStandardTagName(String name) {
    // ignore: parameter_assignments
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
      for (final child in element.childNodes) {
        child.accept(this);
      }

      return;
    }

    final selectorAttrs = element.attributes.where((a) => a.name == 'select');

    for (final child in element.childNodes) {
      if (!child.isSynthetic) {
        errorReporter.reportErrorForOffset(
            AngularWarningCode.NG_CONTENT_MUST_BE_EMPTY,
            element.openingSpan.offset,
            element.openingSpan.length);
      }
    }

    if (selectorAttrs.isEmpty) {
      ngContents.add(new NgContent(element.offset, element.length));
      return;
    }

    // We don't actually check if selectors.length > 2, because the parser
    // reports that.
    try {
      final selectorAttr = selectorAttrs.first;
      if (selectorAttr.value == null) {
        // TODO(mfairhust) report different error for a missing selector
        errorReporter.reportErrorForOffset(
            AngularWarningCode.CANNOT_PARSE_SELECTOR,
            selectorAttr.nameOffset,
            selectorAttr.name.length,
            ['missing']);
      } else if (selectorAttr.value == "") {
        // TODO(mfairhust) report different error for a missing selector
        errorReporter.reportErrorForOffset(
            AngularWarningCode.CANNOT_PARSE_SELECTOR,
            selectorAttr.valueOffset - 1,
            2,
            ['missing']);
      } else {
        final selector = new SelectorParser(
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

/// Once all the scopes for all the expressions & statements are prepared, we're
/// ready to resolve all the expressions inside and typecheck everything.
///
/// This will typecheck the contents of mustaches and attribute bindings against
/// their scopes, and ensure that all attribute bindings exist on a directive and
/// match the type of the binding where there is one. Then records references.
class SingleScopeResolver extends AngularScopeVisitor {
  final Map<String, InputElement> standardHtmlAttributes;
  List<AbstractDirective> directives;
  View view;
  Template template;
  Source templateSource;
  TypeProvider typeProvider;
  AnalysisErrorListener errorListener;
  ErrorReporter errorReporter;

  static var styleWithPercent = new Set<String>.from(<String>[
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

  /// The full map of names to local variables in the current context
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

  /// Resolve output-bound values of [attributes] as statements.
  @override
  void visitStatementsBoundAttr(StatementsBoundAttribute attribute) {
    localVariables = attribute.localVariables;
    _resolveDartExpressionStatements(attribute.statements);
    for (final statement in attribute.statements) {
      _recordAstNodeResolvedRanges(statement);
    }
  }

  /// Resolve TwoWay-bound values of [attributes] as expressions.
  void _resolveTwoWayBoundAttributeValues(ExpressionBoundAttribute attribute) {
    var outputMatched = false;

    // empty attribute error registered in converter. Just don't crash.
    if (attribute.expression != null && !attribute.expression.isAssignable) {
      errorListener.onError(new AnalysisError(
          templateSource,
          attribute.valueOffset,
          attribute.value.length,
          AngularWarningCode.TWO_WAY_BINDING_NOT_ASSIGNABLE));
    }

    for (final directiveBinding in attribute.parent.boundDirectives) {
      for (final output in directiveBinding.boundDirective.outputs) {
        if (output.name == "${attribute.name}Change") {
          outputMatched = true;
          final eventType = output.eventType;
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

    if (!outputMatched && !isOnCustomTag(attribute)) {
      errorListener.onError(new AnalysisError(
          templateSource,
          attribute.nameOffset,
          attribute.name.length,
          AngularWarningCode.NONEXIST_TWO_WAY_OUTPUT_BOUND,
          [attribute.name, "${attribute.name}Change"]));
    }

    _resolveInputBoundAttributeValues(attribute);
  }

  /// Resolve input-bound values of [attributes] as expressions.
  /// Also used by _resolveTwoWwayBoundAttributeValues.
  void _resolveInputBoundAttributeValues(ExpressionBoundAttribute attribute) {
    var inputMatched = false;

    // Check if input exists on bound directives.
    for (final directiveBinding in attribute.parent.boundDirectives) {
      for (final input in directiveBinding.boundDirective.inputs) {
        if (input.name == attribute.name) {
          _typecheckMatchingInput(attribute, input);

          final range =
              new SourceRange(attribute.nameOffset, attribute.name.length);
          template.addRange(range, input);
          directiveBinding.inputBindings
              .add(new InputBinding(input, attribute));

          inputMatched = true;
        }
      }
    }

    // Check if input exists from standard html attributes.
    if (!inputMatched) {
      final standardHtmlAttribute = standardHtmlAttributes[attribute.name];
      if (standardHtmlAttribute != null) {
        _typecheckMatchingInput(attribute, standardHtmlAttribute);
        final range =
            new SourceRange(attribute.nameOffset, attribute.name.length);
        template.addRange(range, standardHtmlAttribute);
        attribute.parent.boundStandardInputs
            .add(new InputBinding(standardHtmlAttribute, attribute));

        inputMatched = true;
      }
    }

    if (!inputMatched && !isOnCustomTag(attribute)) {
      errorListener.onError(new AnalysisError(
          templateSource,
          attribute.nameOffset,
          attribute.name.length,
          AngularWarningCode.NONEXIST_INPUT_BOUND,
          [attribute.name]));
    }
  }

  @override
  void visitEmptyStarBinding(EmptyStarBinding binding) {
    // When the first virtual attribute matches a binding (like `ngIf`), flag it
    // if its empty. Only for the first. All others (like `trackBy`) are checked
    // in [EmbeddedDartParser.parseTemplateVirtualAttributes]
    if (!binding.isPrefix) {
      return;
    }

    // catch *ngIf without a value
    if (binding.parent.boundDirectives
        .map((binding) => binding.boundDirective)
        // TODO enable this again for all directives, not just NgIf
        .where((directive) => directive.name == "NgIf")
        .any((directive) =>
            directive.inputs.any((input) => input.name == binding.name))) {
      errorListener.onError(new AnalysisError(
          templateSource,
          binding.nameOffset,
          binding.name.length,
          AngularWarningCode.EMPTY_BINDING,
          [binding.name]));
    }
  }

  /// Resolve input-bound values of [attributes] as strings, if they match. Note,
  /// this does not report an error un unmatched attributes, but it will report
  /// the range, and ensure that input bindings are string-assingable.
  @override
  void visitTextAttr(TextAttribute attribute) {
    for (final directiveBinding in attribute.parent.boundDirectives) {
      for (final input in directiveBinding.boundDirective.inputs) {
        if (input.name == attribute.name) {
          if (!_checkTextAttrSecurity(attribute, input.securityContext)) {
            continue;
          }

          // Typecheck all but HTML inputs. For those, `width="10"` becomes
          // `setAttribute("width", "10")`, which is ok. But for directives and
          // components, this becomes `.someIntProp = "10"` which doesn't work.
          final inputType = input.setterType;

          // Some attr `foo` by itself, no brackets, as such, and no value, will
          // be bound "true" when its a boolean, which requires no typecheck.
          final booleanException =
              input.setterType.isSubtypeOf(typeProvider.boolType) &&
                  attribute.value == null;

          if (!directiveBinding.boundDirective.isHtml &&
              !booleanException &&
              !typeProvider.stringType.isAssignableTo(inputType)) {
            errorListener.onError(new AnalysisError(
                templateSource,
                attribute.nameOffset,
                attribute.name.length,
                AngularWarningCode.STRING_STYLE_INPUT_BINDING_INVALID,
                [input.name]));
          }

          final range =
              new SourceRange(attribute.nameOffset, attribute.name.length);
          template.addRange(range, input);
          directiveBinding.inputBindings
              .add(new InputBinding(input, attribute));
        }
      }

      for (final elem in directiveBinding.boundDirective.attributes) {
        if (elem.name == attribute.name) {
          final range =
              new SourceRange(attribute.nameOffset, attribute.name.length);
          template.addRange(range, elem);
        }
      }
    }

    final standardHtmlAttribute = standardHtmlAttributes[attribute.name];
    if (standardHtmlAttribute != null) {
      _checkTextAttrSecurity(attribute, standardHtmlAttribute.securityContext);
      // Don't typecheck html inputs. Those become attributes, not properties,
      // which means strings values are OK.
      final range =
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
      final attrType = attr.expression.bestType;
      final inputType = input.setterType;
      final securityContext = input.securityContext;

      if (securityContext != null) {
        if (attrType.isAssignableTo(securityContext.safeType)) {
          return;
        } else if (!securityContext.sanitizationAvailable) {
          errorListener.onError(new AnalysisError(
              templateSource,
              attr.valueOffset,
              attr.value.length,
              AngularWarningCode.UNSAFE_BINDING,
              [securityContext.safeType.toString()]));
          return;
        }
      }

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

  bool _checkTextAttrSecurity(
      TextAttribute attribute, SecurityContext securityContext) {
    if (securityContext == null) {
      return true;
    }
    if (securityContext.sanitizationAvailable) {
      return true;
    }
    if (attribute.mustaches.isEmpty) {
      return true;
    }

    errorListener.onError(new AnalysisError(
        templateSource,
        attribute.valueOffset,
        attribute.value.length,
        AngularWarningCode.UNSAFE_BINDING,
        [securityContext.safeType.toString()]));
    return false;
  }

  /// Quick regex to match the spec, but doesn't handle unicode. They can start
  /// with a dash, but if so must be followed by an alphabetic or underscore or
  /// escaped character. Cannot start with a number.
  /// https://www.w3.org/TR/CSS21/syndata.html#value-def-identifier
  static final RegExp _cssIdentifierRegexp =
      new RegExp(r"^(-?[a-zA-Z_]|\\.)([a-zA-Z0-9\-_]|\\.)*$");

  bool _isCssIdentifier(String input) => _cssIdentifierRegexp.hasMatch(input);

  /// Resolve attributes of type [class.some-class]="someBoolExpr", ensuring
  /// the class is a valid css identifier and that the expression is of boolean
  /// type
  void _resolveClassAttribute(ExpressionBoundAttribute attribute) {
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

  /// Resolve attributes of type [style.color]="someExpr" and
  /// [style.background-width.px]="someNumExpr" which bind a css style property
  /// with optional units.
  void _resolveStyleAttribute(ExpressionBoundAttribute attribute) {
    var cssPropertyName = attribute.name;
    final dotpos = attribute.name.indexOf('.');
    if (dotpos != -1) {
      cssPropertyName = attribute.name.substring(0, dotpos);
      final cssUnitName = attribute.name.substring(dotpos + '.'.length);
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

  /// Resolve attributes of type [attribute.some-attribute]="someExpr"
  void _resolveAttributeBoundAttribute(ExpressionBoundAttribute attribute) {
    // TODO validate the type? Or against a dictionary?
    // note that the attribute name is valid by definition as it was discovered
    // within an attribute! (took me a while to realize why I couldn't make any
    // failing tests for this)
  }

  /// Resolve the given [AstNode] ([expression] or [statement]) and report errors.
  void _resolveDartAstNode(AstNode astNode, bool acceptAssignment) {
    final classElement = view.classElement;
    final library =
        new ExportsLibraryFacade(classElement.library, view.component);
    {
      final visitor = new TypeResolverVisitor(
          library, view.source, typeProvider, errorListener);
      astNode.accept(visitor);
    }
    final resolver = new AngularResolverVisitor(
        library, templateSource, typeProvider, errorListener,
        acceptAssignment: acceptAssignment);
    // fill the name scope
    final classScope = new ClassScope(resolver.nameScope, classElement);
    final localScope = new EnclosedScope(classScope);
    resolver
      ..nameScope = localScope
      ..enclosingClass = classElement;
    localVariables.values
        .forEach((local) => localScope.define(local.dartVariable));
    // do resolve
    astNode.accept(resolver);
    // verify
    final verifier = new AngularErrorVerifier(
        errorReporter, library, typeProvider, new InheritanceManager(library),
        acceptAssignment: acceptAssignment);
    astNode.accept(verifier);
  }

  /// Resolve the Dart expression with the given [code] at [offset].
  void _resolveDartExpression(Expression expression) {
    if (expression != null) {
      _resolveDartAstNode(expression, false);
    }
  }

  /// Resolve the Dart ExpressionStatement with the given [code] at [offset].
  void _resolveDartExpressionStatements(List<Statement> statements) {
    for (final statement in statements) {
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

  /// Get helpful description based on statement type to report in
  /// OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT
  String _getOutputStatementErrorDescription(Statement stmt) {
    final potentialToken = stmt.beginToken.keyword.toString().toLowerCase();
    if (potentialToken != "null") {
      return "token '$potentialToken'";
    } else {
      return stmt.runtimeType.toString().replaceFirst("Impl", "");
    }
  }

  /// Record [ResolvedRange]s for the given [AstNode].
  void _recordAstNodeResolvedRanges(AstNode astNode) {
    final dartVariables = new HashMap<LocalVariableElement, LocalVariable>();

    for (final localVariable in localVariables.values) {
      dartVariables[localVariable.dartVariable] = localVariable;
    }

    if (astNode != null) {
      astNode.accept(new _DartReferencesRecorder(template, dartVariables));
    }
  }
}

/// Custom tags shouldn't report things like unbound inputs/outputs
bool isOnCustomTag(AttributeInfo node) {
  if (node.parent == null) {
    return false;
  }

  final parent = node.parent;

  return parent is ElementInfo && parent.tagMatchedAsCustomTag;
}

/// Workaround for "This mixin application is invalid because all of the
/// constructors in the base class 'ResolverVisitor' have optional parameters."
/// in the definition of [AngularResolverVisitor].
///
/// See https://github.com/dart-lang/sdk/issues/15101 for details
class _IntermediateResolverVisitor extends ResolverVisitor {
  _IntermediateResolverVisitor(LibraryElement library, Source source,
      TypeProvider typeProvider, AnalysisErrorListener errorListener)
      : super(library, source, typeProvider, errorListener);
}

/// Override the standard [ResolverVisitor] class to report unacceptable nodes,
/// while suppressing secondary errors that would have been raised by
/// [ResolverVisitor] if we let it see the bogus definitions.
class AngularResolverVisitor extends _IntermediateResolverVisitor
    with ReportUnacceptableNodesMixin {
  final bool acceptAssignment;

  AngularResolverVisitor(LibraryElement library, Source source,
      TypeProvider typeProvider, AnalysisErrorListener errorListener,
      {@required this.acceptAssignment})
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
  void visitIsExpression(IsExpression exp) =>
      _reportUnacceptableNode(exp, "Is expression");

  @override
  void visitThrowExpression(ThrowExpression exp) =>
      _reportUnacceptableNode(exp, "Throw");

  @override
  void visitSuperExpression(SuperExpression exp) =>
      _reportUnacceptableNode(exp, "Super references");

  @override
  void visitAssignmentExpression(AssignmentExpression exp) {
    // Only block reassignment of locals, not poperties. Resolve elements to
    // check that.
    exp.leftHandSide.accept(elementResolver);
    final variableElement = getOverridableStaticElement(exp.leftHandSide) ??
        getOverridablePropagatedElement(exp.leftHandSide);
    if ((variableElement == null ||
            variableElement is PropertyInducingElement) &&
        acceptAssignment) {
      super.visitAssignmentExpression(exp);
    } else {
      _reportUnacceptableNode(exp, "Assignment of locals");
    }
  }

  @override
  void visitCascadeExpression(CascadeExpression exp) {
    _reportUnacceptableNode(exp, "Cascades", false);
    // Only resolve the target, not the cascade sections.
    exp.target.accept(this);
  }

  @override
  void visitAwaitExpression(AwaitExpression exp) =>
      _reportUnacceptableNode(exp, "Await");

  @override
  void visitFunctionExpression(FunctionExpression exp) =>
      _reportUnacceptableNode(exp, "Anonymous functions", false);

  @override
  void visitSymbolLiteral(SymbolLiteral exp) =>
      _reportUnacceptableNode(exp, "Symbol literal");

  @override
  void visitNamedExpression(NamedExpression exp) =>
      _reportUnacceptableNode(exp, "Named arguments");
}

/// Override the standard [ErrorVerifier] class to report unacceptable nodes,
/// while suppressing secondary errors that would have been raised by
/// [ErrorVerifier] if we let it see the bogus definitions.
class AngularErrorVerifier extends ErrorVerifier
    with ReportUnacceptableNodesMixin {
  final bool acceptAssignment;

  @override
  ErrorReporter errorReporter;
  @override
  TypeProvider typeProvider;

  AngularErrorVerifier(ErrorReporter errorReporter, LibraryElement library,
      TypeProvider typeProvider, InheritanceManager inheritanceManager,
      {@required this.acceptAssignment})
      : errorReporter = errorReporter,
        typeProvider = typeProvider,
        super(errorReporter, library, typeProvider, inheritanceManager, false);

  @override
  void visitFunctionExpression(FunctionExpression exp) {
    // error reported in [AngularResolverVisitor] but [ErrorVerifier] crashes
    // because it isn't resolved
  }

  @override
  void visitRethrowExpression(RethrowExpression exp) =>
      _reportUnacceptableNode(exp, "Rethrow");

  @override
  void visitThisExpression(ThisExpression exp) =>
      _reportUnacceptableNode(exp, "This references");

  @override
  void visitListLiteral(ListLiteral list) {
    if (list.typeArguments != null) {
      _reportUnacceptableNode(list, "Typed list literals");
    } else {
      super.visitListLiteral(list);
    }
  }

  @override
  void visitMapLiteral(MapLiteral map) {
    if (map.typeArguments != null) {
      _reportUnacceptableNode(map, "Typed map literals");
    } else {
      super.visitMapLiteral(map);
    }
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression exp) =>
      _reportUnacceptableNode(exp, "Usage of new");

  @override
  void visitAssignmentExpression(AssignmentExpression exp) {
    // match ResolverVisitor to prevent fallout errors
    final variableElement = getOverridableStaticElement(exp.leftHandSide) ??
        getOverridablePropagatedElement(exp.leftHandSide);
    if ((variableElement == null ||
            variableElement is PropertyInducingElement) &&
        acceptAssignment) {
      super.visitAssignmentExpression(exp);
    } else {
      exp.visitChildren(this);
    }
  }

  /// Copied from ResolverVisitor
  VariableElement getOverridablePropagatedElement(Expression expression) {
    Element element;
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

  /// Copied from ResolverVisitor
  VariableElement getOverridableStaticElement(Expression expression) {
    Element element;
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
