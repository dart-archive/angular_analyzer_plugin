import 'dart:async';
import 'dart:collection';

import 'package:analyzer_plugin/protocol/protocol_common.dart'
    hide AnalysisError;
import 'package:analyzer_plugin/utilities/completion/completion_core.dart';
import 'package:analyzer_plugin/utilities/completion/relevance.dart';
import 'package:analyzer_plugin/utilities/completion/inherited_reference_contributor.dart';
import 'package:analyzer_plugin/utilities/completion/type_member_contributor.dart';
import 'package:analyzer_plugin/src/utilities/completion/optype.dart';
import 'package:analyzer_plugin/src/utilities/completion/completion_core.dart';
import 'package:analyzer_plugin/src/utilities/completion/completion_target.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/element.dart'
    show PropertyAccessorElement, FunctionElement, ClassElement, LibraryElement;
import 'package:analyzer/src/generated/resolver.dart' show TypeProvider;
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/session.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/completion_request.dart';
import 'package:angular_analyzer_plugin/ast.dart';

bool offsetContained(int offset, int start, int length) =>
    start <= offset && start + length >= offset;

class LocalVariablesExtractor implements AngularAstVisitor {
  Map<String, LocalVariable> variables;

  // don't recurse
  @override
  void visitDocumentInfo(DocumentInfo document) {}

  @override
  void visitElementInfo(ElementInfo element) {}

  @override
  void visitTextAttr(TextAttribute attr) {}

  @override
  void visitEmptyStarBinding(EmptyStarBinding binding) {}

  @override
  void visitTextInfo(TextInfo text) {}

  @override
  void visitExpressionBoundAttr(ExpressionBoundAttribute attr) {
    variables = attr.localVariables;
  }

  @override
  void visitStatementsBoundAttr(StatementsBoundAttribute attr) {
    variables = attr.localVariables;
  }

  @override
  void visitMustache(Mustache mustache) {
    variables = mustache.localVariables;
  }

  @override
  void visitTemplateAttr(TemplateAttribute attr) {
    variables = attr.localVariables;
  }
}

class ReplacementRangeCalculator implements AngularAstVisitor {
  int offset; // replacementOffset. Initially requestOffset.
  int length = 0; // replacementLength

  ReplacementRangeCalculator(CompletionRequest request) {
    offset = request.offset;
  }

  @override
  void visitDocumentInfo(DocumentInfo document) {}

  @override
  void visitElementInfo(ElementInfo element) {
    if (element.openingSpan == null) {
      return;
    }
    final nameSpanEnd =
        element.openingNameSpan.offset + element.openingNameSpan.length;
    if (offsetContained(offset, element.openingSpan.offset,
        nameSpanEnd - element.openingSpan.offset)) {
      offset = element.openingSpan.offset;
      length = element.localName.length + 1;
    }
  }

  @override
  void visitTextAttr(TextAttribute attr) {
    if (attr.parent is TemplateAttribute && attr.name.startsWith('let-')) {
      return;
    }
    final inValueScope = attr.isReference &&
        attr.value != null &&
        offsetContained(offset, attr.valueOffset, attr.valueLength);
    offset = inValueScope ? attr.valueOffset : attr.offset;
    length = inValueScope ? attr.valueLength : attr.length;
  }

  @override
  void visitTextInfo(TextInfo textInfo) {
    if (offset > textInfo.offset &&
        textInfo.text[offset - textInfo.offset - 1] == '<') {
      offset--;
      length = 1;
    }
  }

  @override
  void visitExpressionBoundAttr(ExpressionBoundAttribute attr) {
    if (offsetContained(
        offset, attr.originalNameOffset, attr.originalName.length)) {
      offset = attr.originalNameOffset;
      length = attr.originalName.length;
    }
  }

  @override
  void visitStatementsBoundAttr(StatementsBoundAttribute attr) {
    if (offsetContained(
        offset, attr.originalNameOffset, attr.originalName.length)) {
      offset = attr.originalNameOffset;
      length = attr.originalName.length;
    }
  }

  @override
  void visitMustache(Mustache mustache) {}

  @override
  void visitTemplateAttr(TemplateAttribute attr) {
    if (offsetContained(
        offset, attr.originalNameOffset, attr.originalName.length)) {
      offset = attr.originalNameOffset;
      length = attr.originalName.length;
    }
  }

  @override
  void visitEmptyStarBinding(EmptyStarBinding binding) =>
      visitTextAttr(binding);
}

/// Used to create a shell [ResolveResult] class for usage in
/// [TypeMemberContributor] and [InheritedReferenceContributor].
class _ResolveResultShell implements ResolveResult {
  @override
  String get content => null;

  @override
  LibraryElement libraryElement;

  @override
  TypeProvider typeProvider;

  @override
  CompilationUnit get unit => null;

  @override
  List<AnalysisError> get errors => const [];

  @override
  LineInfo get lineInfo => null;

  @override
  final String path;

  @override
  AnalysisSession get session => null;

  @override
  ResultState get state => null;

  @override
  Uri get uri => null;

  _ResolveResultShell(this.path, {this.libraryElement, this.typeProvider});
}

class NgOffsetLengthContributor extends CompletionContributor {
  @override
  Future<Null> computeSuggestions(
      AngularCompletionRequest request, CompletionCollector collector) async {
    final replacementRangeCalculator = new ReplacementRangeCalculator(request);
    final dartSnippet = request.dartSnippet;
    request.angularTarget?.accept(replacementRangeCalculator);
    if (dartSnippet != null) {
      final range =
          request.completionTarget.computeReplacementRange(request.offset);
      collector
        ..offset = range.offset
        ..length = range.length;
    } else if (request.angularTarget != null) {
      collector
        ..offset = replacementRangeCalculator.offset
        ..length = replacementRangeCalculator.length;
    }
  }
}

/// Extension of [TypeMemberContributor] to allow for Dart-based
/// completion within Angular context. Triggered in [StatementsBoundAttribute],
/// [ExpressionsBoundAttribute], [Mustache], and [TemplateAttribute]
/// on member variable completion.
class NgTypeMemberContributor extends CompletionContributor {
  final TypeMemberContributor _typeMemberContributor =
      new TypeMemberContributor();

  @override
  Future<Null> computeSuggestions(
      AngularCompletionRequest request, CompletionCollector collector) async {
    final templates = request.templates;

    for (final template in templates) {
      final typeProvider = template.view.component.classElement.enclosingElement
          .enclosingElement.context.typeProvider;
      final dartSnippet = request.dartSnippet;

      if (dartSnippet != null) {
        final classElement = template.view.classElement;
        final libraryElement = classElement.library;

        final dartResolveResult = new _ResolveResultShell(request.path,
            libraryElement: libraryElement, typeProvider: typeProvider);
        final dartRequest = new DartCompletionRequestImpl(
            request.resourceProvider, request.offset, dartResolveResult);
        await _typeMemberContributor.computeSuggestionsWithEntryPoint(
            dartRequest, collector, dartSnippet);
      }
    }
  }
}

/// Extension of [InheritedReferenceContributor] to allow for Dart-based
/// completion within Angular context. Triggered in [StatementsBoundAttribute],
/// [ExpressionsBoundAttribute], [Mustache], and [TemplateAttribute]
/// on identifier completion.
class NgInheritedReferenceContributor extends CompletionContributor {
  final InheritedReferenceContributor _inheritedReferenceContributor =
      new InheritedReferenceContributor();

  @override
  Future<Null> computeSuggestions(
      AngularCompletionRequest request, CompletionCollector collector) async {
    final templates = request.templates;

    for (final template in templates) {
      final typeProvider = template.view.component.classElement.enclosingElement
          .enclosingElement.context.typeProvider;
      final dartSnippet = request.dartSnippet;

      if (dartSnippet != null) {
        final angularTarget = request.angularTarget;
        final completionTarget = request.completionTarget;

        final optype =
            defineOpType(completionTarget, request.offset, dartSnippet);
        final classElement = template.view.classElement;
        final libraryElement = classElement.library;

        final dartResolveResult = new _ResolveResultShell(request.path,
            libraryElement: libraryElement, typeProvider: typeProvider);
        final dartRequest = new DartCompletionRequestImpl(
            request.resourceProvider, request.offset, dartResolveResult);
        await _inheritedReferenceContributor.computeSuggestionsForClass(
            dartRequest, collector, classElement,
            entryPoint: dartSnippet,
            target: completionTarget,
            optype: optype,
            skipChildClass: false);

        if (optype.includeIdentifiers) {
          final varExtractor = new LocalVariablesExtractor();
          angularTarget.accept(varExtractor);
          if (varExtractor.variables != null) {
            addLocalVariables(
              collector,
              varExtractor.variables,
              optype,
            );
          }

          addExportedPrefixSuggestions(collector, template.view);
        }

        {
          final entity = completionTarget.entity;
          final containingNode = completionTarget.containingNode;
          if (entity is SimpleIdentifier &&
              containingNode is PrefixedIdentifier &&
              entity == containingNode?.identifier) {
            addExportSuggestions(collector, template.view, optype,
                prefix: containingNode.prefix.name);
          } else {
            addExportSuggestions(collector, template.view, optype);
          }
        }
      }
    }
  }

  OpType defineOpType(CompletionTarget target, int offset, AstNode entryPoint) {
    final optype = new OpType.forCompletion(target, offset);

    // if the containing node IS the AST, it means the context decides what's
    // completable. In that case, that's in our court only.
    if (target.containingNode == entryPoint) {
      optype
        ..includeReturnValueSuggestions = true
        ..includeTypeNameSuggestions = true
        // expressions always have nonvoid returns
        ..includeVoidReturnSuggestions = !(entryPoint is Expression);
    }

    // NG Expressions (not statements) always must return something. We have to
    // force that ourselves here.
    if (entryPoint is Expression) {
      optype.includeVoidReturnSuggestions = false;
    }
    return optype;
  }

  void addLocalVariables(CompletionCollector collector,
      Map<String, LocalVariable> localVars, OpType optype) {
    for (final eachVar in localVars.values) {
      collector.addSuggestion(_addLocalVariableSuggestion(eachVar,
          eachVar.dartVariable.type, ElementKind.LOCAL_VARIABLE, optype,
          relevance: DART_RELEVANCE_LOCAL_VARIABLE));
    }
  }

  CompletionSuggestion _addLocalVariableSuggestion(LocalVariable variable,
      DartType typeName, ElementKind elemKind, OpType optype,
      {int relevance: DART_RELEVANCE_DEFAULT}) {
    // ignore: parameter_assignments
    relevance = optype.returnValueSuggestionsFilter(
            variable.dartVariable.type, relevance) ??
        DART_RELEVANCE_DEFAULT;
    return _createLocalSuggestion(variable, relevance, typeName,
        _createLocalElement(variable, elemKind, typeName));
  }

  CompletionSuggestion _createLocalSuggestion(LocalVariable localVar,
      int defaultRelevance, DartType type, Element element) {
    final completion = localVar.name;
    return new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
        defaultRelevance, completion, completion.length, 0, false, false,
        returnType: type.toString(), element: element);
  }

  Element _createLocalElement(
      LocalVariable localVar, ElementKind kind, DartType type) {
    final name = localVar.name;
    final location = new Location(localVar.source.fullName, localVar.nameOffset,
        localVar.nameLength, 0, 0);
    final flags = Element.makeFlags();
    return new Element(kind, name, flags,
        location: location, returnType: type.toString());
  }

  void addExportSuggestions(
      CompletionCollector collector, View view, OpType optype,
      {String prefix}) {
    if (prefix == null) {
      collector.addSuggestion(_addExportedClassSuggestion(
          new ExportedIdentifier(view.classElement.name, null,
              element: view.classElement),
          view.classElement.type,
          ElementKind.CLASS,
          optype,
          relevance: DART_RELEVANCE_DEFAULT));
    }

    final exports = view.exports;
    if (exports == null) {
      return;
    }

    for (final export in exports) {
      if (prefix != null && export.prefix != prefix) {
        continue;
      }

      final element = export.element;
      if (element is PropertyAccessorElement) {
        collector.addSuggestion(_addExportedGetterSuggestion(
            export, element.variable.type, ElementKind.GETTER, optype,
            relevance: DART_RELEVANCE_DEFAULT, withPrefix: prefix == null));
      }
      if (element is FunctionElement) {
        collector.addSuggestion(_addExportedFunctionSuggestion(
            export, element.returnType, ElementKind.FUNCTION, optype,
            relevance: DART_RELEVANCE_DEFAULT, withPrefix: prefix == null));
      }
      if (element is ClassElement) {
        collector.addSuggestion(_addExportedClassSuggestion(
            export,
            element.type,
            element.isEnum ? ElementKind.ENUM : ElementKind.CLASS,
            optype,
            relevance: DART_RELEVANCE_DEFAULT,
            withPrefix: prefix == null));
      }
    }
  }

  void addExportedPrefixSuggestions(CompletionCollector collector, View view) {
    if (view.exports == null) {
      return;
    }

    view.exports
        .map((export) => export.prefix)
        .where((prefix) => prefix != '')
        .toSet()
        .map((prefix) => _addExportedPrefixSuggestion(
            prefix, _getPrefixedImport(view.classElement.library, prefix)))
        .forEach(collector.addSuggestion);
  }

  LibraryElement _getPrefixedImport(LibraryElement library, String prefix) =>
      library.imports
          .where((import) => import.prefix != null)
          .where((import) => import.prefix.name == prefix)
          .first
          .library;

  CompletionSuggestion _addExportedGetterSuggestion(ExportedIdentifier export,
      DartType typeName, ElementKind elemKind, OpType optype,
      {int relevance: DART_RELEVANCE_DEFAULT, bool withPrefix: true}) {
    final element = export.element as PropertyAccessorElement;
    // ignore: parameter_assignments
    relevance =
        optype.returnValueSuggestionsFilter(element.variable.type, relevance) ??
            DART_RELEVANCE_DEFAULT;
    return _createExportSuggestion(
        export,
        relevance,
        typeName,
        _createExportElement(export, elemKind)
          ..returnType = typeName.toString(),
        withPrefix: withPrefix)
      ..returnType = element.returnType.toString();
  }

  CompletionSuggestion _addExportedFunctionSuggestion(ExportedIdentifier export,
      DartType typeName, ElementKind elemKind, OpType optype,
      {int relevance: DART_RELEVANCE_DEFAULT, bool withPrefix: true}) {
    final element = export.element as FunctionElement;
    // ignore: parameter_assignments
    relevance = optype.returnValueSuggestionsFilter(element.type, relevance) ??
        DART_RELEVANCE_DEFAULT;
    return _createExportSuggestion(
        export,
        relevance,
        typeName,
        _createExportFunctionElement(export.element, elemKind, typeName)
          ..returnType = typeName.toString(),
        withPrefix: withPrefix)
      ..returnType = element.returnType.toString()
      ..parameterNames = element.parameters.map((param) => param.name).toList()
      ..parameterTypes =
          element.parameters.map((param) => param.type.toString()).toList()
      ..requiredParameterCount =
          element.parameters.where((param) => param.isRequired).length
      ..hasNamedParameters =
          element.parameters.any((param) => param.name != null);
  }

  CompletionSuggestion _addExportedClassSuggestion(ExportedIdentifier export,
          DartType typeName, ElementKind elemKind, OpType optype,
          {int relevance: DART_RELEVANCE_DEFAULT, bool withPrefix: true}) =>
      _createExportSuggestion(
          export, relevance, typeName, _createExportElement(export, elemKind),
          withPrefix: withPrefix);

  CompletionSuggestion _addExportedPrefixSuggestion(
          String prefix, LibraryElement library) =>
      _createExportedPrefixSuggestion(prefix, DART_RELEVANCE_DEFAULT,
          _createExportedPrefixElement(prefix, library));

  CompletionSuggestion _createExportSuggestion(ExportedIdentifier export,
      int defaultRelevance, DartType type, Element element,
      {bool withPrefix: true}) {
    final completion = export.prefix.isEmpty || !withPrefix
        ? export.identifier
        : '${export.prefix}.${export.identifier}';
    return new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
        defaultRelevance, completion, completion.length, 0, false, false,
        element: element);
  }

  Element _createExportElement(ExportedIdentifier export, ElementKind kind) {
    final name = export.identifier;
    final location = new Location(export.element.source.fullName,
        export.element.nameOffset, export.element.nameLength, 0, 0);
    final flags = Element.makeFlags();
    return new Element(kind, name, flags, location: location);
  }

  Element _createExportFunctionElement(
      FunctionElement element, ElementKind kind, DartType type) {
    final name = element.name;
    final parameterString = element.parameters.join(', ');
    final location = new Location(
        element.source.fullName, element.nameOffset, element.nameLength, 0, 0);
    final flags = Element.makeFlags();
    return new Element(kind, name, flags,
        location: location,
        returnType: type.toString(),
        parameters: '($parameterString)');
  }

  CompletionSuggestion _createExportedPrefixSuggestion(
          String prefix, int defaultRelevance, Element element) =>
      new CompletionSuggestion(CompletionSuggestionKind.IDENTIFIER,
          defaultRelevance, prefix, prefix.length, 0, false, false,
          element: element);

  Element _createExportedPrefixElement(String prefix, LibraryElement library) {
    final flags = Element.makeFlags();
    final location = new Location(
        library.source.fullName, library.nameOffset, library.nameLength, 0, 0);
    return new Element(ElementKind.LIBRARY, prefix, flags, location: location);
  }
}

/// Contributor to contribute angular entities.
class AngularCompletionContributor extends CompletionContributor {
  /// Initialize a newly created handler to handle requests for the given
  /// [server].
  AngularCompletionContributor();

  /// Return a [Future] that completes with a list of suggestions
  /// for the given completion [request].
  @override
  Future<Null> computeSuggestions(
      AngularCompletionRequest request, CompletionCollector collector) async {
    final templates = request.templates;
    final standardHtml = request.standardHtml;
    final events = standardHtml.events.values.toList();
    final attributes = standardHtml.uniqueAttributeElements;

    final templateCompleter = new TemplateCompleter();
    for (final template in templates) {
      await templateCompleter.computeSuggestions(
        request,
        collector,
        template,
        events,
        attributes,
      );
    }
  }
}

class TemplateCompleter {
  static const int RELEVANCE_TRANSCLUSION = DART_RELEVANCE_DEFAULT + 10;

  Future<Null> computeSuggestions(
    AngularCompletionRequest request,
    CompletionCollector collector,
    Template template,
    List<OutputElement> standardHtmlEvents,
    Set<InputElement> standardHtmlAttributes,
  ) async {
    final typeProvider = template.view.component.classElement.enclosingElement
        .enclosingElement.context.typeProvider;
    final dartSnippet = request.dartSnippet;
    final target = request.angularTarget;

    if (dartSnippet != null) {
      return;
    }

    if (target is ElementInfo) {
      if (target.closingSpan != null &&
          offsetContained(request.offset, target.closingSpan.offset,
              target.closingSpan.length)) {
        if (request.offset ==
            (target.closingSpan.offset + target.closingSpan.length)) {
          // In closing tag, but could be directly after it; ex: '</div>^'.
          suggestHtmlTags(template, collector);
          if (target.parent != null && target.parent is! DocumentInfo) {
            suggestTransclusions(target.parent, collector);
          }
        }
      } else if (!offsetContained(request.offset, target.openingNameSpan.offset,
          target.openingNameSpan.length)) {
        // If request is not in [openingNameSpan], suggest decorators.
        suggestInputs(
          target.boundDirectives,
          collector,
          standardHtmlAttributes,
          target.boundStandardInputs,
          typeProvider,
          includePlainAttributes: true,
        );
        suggestOutputs(
          target.boundDirectives,
          collector,
          standardHtmlEvents,
          target.boundStandardOutputs,
        );
        suggestBananas(
          target.boundDirectives,
          collector,
          target.boundStandardInputs,
          target.boundStandardOutputs,
        );
        suggestFromAvailableDirectives(
          target.availableDirectives,
          collector,
          suggestPlainAttributes: true,
          suggestInputs: true,
          suggestBananas: true,
        );
        if (!target.isOrHasTemplateAttribute) {
          suggestStarAttrs(template, collector);
        }
      } else {
        // Otherwise, suggest HTML tags and transclusions.
        suggestHtmlTags(template, collector);
        if (target.parent != null || target.parent is! DocumentInfo) {
          suggestTransclusions(target.parent, collector);
        }
      }
    } else if (target is AttributeInfo && target.parent is TemplateAttribute) {
      // `let foo`. Nothing to suggest.
      if (target is TextAttribute && target.name.startsWith("let-")) {
        return;
      }

      if (offsetContained(request.offset, target.originalNameOffset,
          target.originalName.length)) {
        suggestInputsInTemplate(target.parent, collector, currentAttr: target);
      } else {
        suggestInputsInTemplate(target.parent, collector);
      }
    } else if (target is ExpressionBoundAttribute &&
        offsetContained(request.offset, target.originalNameOffset,
            target.originalName.length)) {
      final _suggestInputs = target.bound == ExpressionBoundType.input;
      var _suggestBananas = target.bound == ExpressionBoundType.twoWay;

      if (_suggestInputs) {
        _suggestBananas = target.nameOffset == request.offset;
        suggestInputs(
            target.parent.boundDirectives,
            collector,
            standardHtmlAttributes,
            target.parent.boundStandardInputs,
            typeProvider,
            currentAttr: target);
      }
      if (_suggestBananas) {
        suggestBananas(
          target.parent.boundDirectives,
          collector,
          target.parent.boundStandardInputs,
          target.parent.boundStandardOutputs,
          currentAttr: target,
        );
      }
      suggestFromAvailableDirectives(
        target.parent.availableDirectives,
        collector,
        suggestBananas: _suggestBananas,
        suggestInputs: _suggestInputs,
      );
    } else if (target is StatementsBoundAttribute) {
      suggestOutputs(target.parent.boundDirectives, collector,
          standardHtmlEvents, target.parent.boundStandardOutputs,
          currentAttr: target);
    } else if (target is TemplateAttribute) {
      if (offsetContained(request.offset, target.originalNameOffset,
          target.originalName.length)) {
        suggestStarAttrs(template, collector);
      }
      suggestInputsInTemplate(target, collector);
    } else if (target is TextAttribute && target.nameOffset != null) {
      if (offsetContained(
          request.offset, target.nameOffset, target.name.length)) {
        suggestInputs(
            target.parent.boundDirectives,
            collector,
            standardHtmlAttributes,
            target.parent.boundStandardInputs,
            typeProvider,
            includePlainAttributes: true);
        suggestOutputs(target.parent.boundDirectives, collector,
            standardHtmlEvents, target.parent.boundStandardOutputs);
        suggestBananas(
          target.parent.boundDirectives,
          collector,
          target.parent.boundStandardInputs,
          target.parent.boundStandardOutputs,
        );
        suggestFromAvailableDirectives(
          target.parent.availableDirectives,
          collector,
          suggestPlainAttributes: true,
          suggestInputs: true,
          suggestBananas: true,
        );
      } else if (target.value != null &&
          target.isReference &&
          offsetContained(
              request.offset, target.valueOffset, target.value.length)) {
        suggestRefValues(target.parent.boundDirectives, collector);
      }
    } else if (target is TextInfo) {
      suggestHtmlTags(template, collector);
      suggestTransclusions(target.parent, collector);
    }
  }

  void suggestTransclusions(
      ElementInfo container, CompletionCollector collector) {
    for (final directive in container.directives) {
      if (directive is! Component) {
        continue;
      }

      final Component component = directive;
      final view = component?.view;
      if (view == null) {
        continue;
      }

      for (final ngContent in component.ngContents) {
        if (ngContent.selector == null) {
          continue;
        }

        final tags = ngContent.selector.suggestTags();
        for (final tag in tags) {
          final location = new Location(view.templateSource.fullName,
              ngContent.offset, ngContent.length, 0, 0);
          collector.addSuggestion(_createHtmlTagSuggestion(
              tag.toString(),
              RELEVANCE_TRANSCLUSION,
              _createHtmlTagTransclusionElement(
                  tag.toString(), ElementKind.CLASS_TYPE_ALIAS, location)));
        }
      }
    }
  }

  void suggestHtmlTags(Template template, CompletionCollector collector) {
    final elementTagMap = template.view.elementTagsInfo;
    for (final elementTagName in elementTagMap.keys) {
      final currentSuggestion = _createHtmlTagSuggestion(
          '<$elementTagName',
          DART_RELEVANCE_DEFAULT,
          _createHtmlTagElement(
              elementTagName,
              elementTagMap[elementTagName].first,
              ElementKind.CLASS_TYPE_ALIAS));
      if (currentSuggestion != null) {
        collector.addSuggestion(currentSuggestion);
      }
    }
  }

  void suggestInputs(
    List<DirectiveBinding> directives,
    CompletionCollector collector,
    Set<InputElement> standardHtmlAttributes,
    List<InputBinding> boundStandardAttributes,
    TypeProvider typeProvider, {
    ExpressionBoundAttribute currentAttr,
    bool includePlainAttributes: false,
  }) {
    for (final directive in directives) {
      final usedInputs = new HashSet.from(directive.inputBindings
          .where((b) => b.attribute != currentAttr)
          .map((b) => b.boundInput)).toSet();

      for (final input in directive.boundDirective.inputs) {
        // don't recommend [name] [name] [name]
        if (usedInputs.contains(input)) {
          continue;
        }

        if (includePlainAttributes && typeProvider != null) {
          if (typeProvider.stringType.isAssignableTo(input.setterType)) {
            final relevance = input.setterType.displayName == 'String'
                ? DART_RELEVANCE_DEFAULT
                : DART_RELEVANCE_DEFAULT - 1;
            collector.addSuggestion(_createPlainAttributeSuggestions(
                input.name,
                relevance,
                _createPlainAttributeElement(
                  input.name,
                  input.nameOffset,
                  input.source.fullName,
                  ElementKind.SETTER,
                )));
          }
        }
        collector.addSuggestion(_createInputSuggestion(
            input,
            DART_RELEVANCE_DEFAULT,
            _createInputElement(input, ElementKind.SETTER)));
      }
    }

    final usedStdInputs = new HashSet.from(boundStandardAttributes
        .where((b) => b.attribute != currentAttr)
        .map((b) => b.boundInput)).toSet();

    for (final input in standardHtmlAttributes) {
      // TODO don't recommend [hidden] [hidden] [hidden]
      if (usedStdInputs.contains(input)) {
        continue;
      }
      if (includePlainAttributes && typeProvider != null) {
        if (typeProvider.stringType.isAssignableTo(input.setterType)) {
          final relevance = input.setterType.displayName == 'String'
              ? DART_RELEVANCE_DEFAULT - 2
              : DART_RELEVANCE_DEFAULT - 3;
          collector.addSuggestion(_createPlainAttributeSuggestions(
              input.name,
              relevance,
              _createPlainAttributeElement(
                input.name,
                input.nameOffset,
                input.source.fullName,
                ElementKind.SETTER,
              )));
        }
      }
      collector.addSuggestion(_createInputSuggestion(
          input,
          DART_RELEVANCE_DEFAULT - 2,
          _createInputElement(input, ElementKind.SETTER)));
    }
  }

  void suggestInputsInTemplate(
      TemplateAttribute templateAttr, CompletionCollector collector,
      {AttributeInfo currentAttr}) {
    final directives = templateAttr.boundDirectives;
    for (final binding in directives) {
      final usedInputs = new HashSet.from(binding.inputBindings
          .where((b) => b.attribute != currentAttr)
          .map((b) => b.boundInput)).toSet();

      for (final input in binding.boundDirective.inputs) {
        // don't recommend trackBy: x trackBy: x trackBy: x
        if (usedInputs.contains(input)) {
          continue;
        }

        // edge case. Don't think this comes up in standard.
        if (!input.name.startsWith(templateAttr.prefix)) {
          continue;
        }

        // Unlike ngForTrackBy becoming trackBy, ngFor can't become anything.
        if (input.name == templateAttr.prefix) {
          continue;
        }

        collector.addSuggestion(_createInputInTemplateSuggestion(
            templateAttr.prefix,
            input,
            DART_RELEVANCE_DEFAULT,
            _createInputElement(input, ElementKind.SETTER)));
      }
    }
  }

  void suggestOutputs(
      List<DirectiveBinding> directives,
      CompletionCollector collector,
      List<OutputElement> standardHtmlEvents,
      List<OutputBinding> boundStandardOutputs,
      {BoundAttributeInfo currentAttr}) {
    for (final directive in directives) {
      final usedOutputs = new HashSet.from(directive.outputBindings
          .where((b) => b.attribute != currentAttr)
          .map((b) => b.boundOutput)).toSet();
      for (final output in directive.boundDirective.outputs) {
        // don't recommend (close) (close) (close)
        if (usedOutputs.contains(output)) {
          continue;
        }
        collector.addSuggestion(_createOutputSuggestion(
            output,
            DART_RELEVANCE_DEFAULT,
            _createOutputElement(output, ElementKind.GETTER)));
      }
    }

    final usedStdOutputs = new HashSet.from(boundStandardOutputs
        .where((b) => b.attribute != currentAttr)
        .map((b) => b.boundOutput)).toSet();

    for (final output in standardHtmlEvents) {
      // don't recommend (click) (click) (click)
      if (usedStdOutputs.contains(output)) {
        continue;
      }
      collector.addSuggestion(_createOutputSuggestion(
          output,
          DART_RELEVANCE_DEFAULT - 1, // just below regular relevance
          _createOutputElement(output, ElementKind.GETTER)));
    }
  }

  void suggestBananas(
      List<DirectiveBinding> directives,
      CompletionCollector collector,
      List<InputBinding> boundStandardAttributes,
      List<OutputBinding> boundStandardOutputs,
      {BoundAttributeInfo currentAttr}) {
    // Handle potential two-way found in bound directives
    // There are no standard event/attribute that fall under two-way binding.
    for (final directive in directives) {
      final usedInputs = new HashSet.from(directive.inputBindings
          .where((b) => b.attribute != currentAttr)
          .map((b) => b.boundInput)).toSet();
      final usedOutputs = new HashSet.from(directive.outputBindings
          .where((b) => b.attribute != currentAttr)
          .map((b) => b.boundOutput)).toSet();

      final availableInputs = new HashSet.from(directive.boundDirective.inputs)
          .difference(usedInputs);
      final availableOutputs =
          new HashSet.from(directive.boundDirective.outputs)
              .difference(usedOutputs);
      for (final input in availableInputs) {
        final inputName = input.name;
        final complementName = '${inputName}Change';
        final output = availableOutputs
            .firstWhere((o) => o.name == complementName, orElse: () => null);
        if (output != null) {
          collector.addSuggestion(_createBananaSuggestion(
              input,
              DART_RELEVANCE_DEFAULT,
              _createBananaElement(input, ElementKind.SETTER)));
        }
      }
    }
  }

  void suggestStarAttrs(Template template, CompletionCollector collector) {
    template.view.directives.where((d) => d.looksLikeTemplate).forEach(
        (directive) =>
            suggestStarAttrsForSelector(directive.selector, collector));
  }

  void suggestStarAttrsForSelector(
      Selector selector, CompletionCollector collector) {
    if (selector is OrSelector) {
      for (final subselector in selector.selectors) {
        suggestStarAttrsForSelector(subselector, collector);
      }
    } else if (selector is AndSelector) {
      for (final subselector in selector.selectors) {
        suggestStarAttrsForSelector(subselector, collector);
      }
    } else if (selector is AttributeSelector) {
      if (selector.nameElement.name == "ngForOf") {
        // `ngFor`'s selector includes `[ngForOf]`, but `*ngForOf=..` won't ever
        // work, because it then becomes impossible to satisfy the other half,
        // `[ngFor]`. Hardcode to filter this out, rather than using some kind
        // of complex heuristic.
        return;
      }

      collector.addSuggestion(_createStarAttrSuggestion(
          selector,
          DART_RELEVANCE_DEFAULT,
          _createStarAttrElement(selector, ElementKind.CLASS)));
    }
  }

  void suggestRefValues(
      List<DirectiveBinding> directives, CompletionCollector collector) {
    // Keep map of all 'exportAs' name seen. Don't suggest same name twice.
    // If two directives share same exportAs, still suggest one of them
    // and if they use this, and error will flag - let user resolve
    // rather than not suggesting at all.
    final seen = new HashSet<String>();
    for (final directive in directives) {
      final exportAs = directive.boundDirective.exportAs;
      if (exportAs != null && exportAs.name.isNotEmpty) {
        final exportAsName = exportAs.name;
        if (!seen.contains(exportAsName)) {
          seen.add(exportAsName);
          collector.addSuggestion(_createRefValueSuggestion(
              exportAs,
              DART_RELEVANCE_DEFAULT,
              _createRefValueElement(exportAs, ElementKind.LABEL)));
        }
      }
    }
  }

  /// Goes through all the available, but not yet-bound directives
  /// and extracts non-violating plain-text attribute-directives
  /// and inputs (if name overlaps with attribute-directive).
  void suggestFromAvailableDirectives(
    Map<AbstractDirective, List<AttributeSelector>> availableDirectives,
    CompletionCollector collector, {
    bool suggestInputs: false,
    bool suggestBananas: false,
    bool suggestPlainAttributes: false,
  }) {
    availableDirectives.forEach((directive, selectors) {
      final attributeSelectors = <String, AttributeSelector>{};
      final validInputs = <InputElement>[];

      for (final aSelector in selectors) {
        attributeSelectors[aSelector.nameElement.name] = aSelector;
      }

      for (final input in directive.inputs) {
        if (attributeSelectors.keys.contains(input.name)) {
          attributeSelectors.remove(input.name);
          validInputs.add(input);
        }
      }

      for (final input in validInputs) {
        final outputComplement = '${input.name}Change';
        final output = directive.outputs.firstWhere(
            (output) => output.name == outputComplement,
            orElse: () => null);
        if (output != null && suggestBananas) {
          collector.addSuggestion(_createBananaSuggestion(
              input,
              DART_RELEVANCE_DEFAULT,
              _createBananaElement(input, ElementKind.SETTER)));
        }
        if (suggestInputs) {
          collector.addSuggestion(_createInputSuggestion(
              input,
              DART_RELEVANCE_DEFAULT,
              _createInputElement(input, ElementKind.SETTER)));
        }
      }

      if (suggestPlainAttributes) {
        attributeSelectors.forEach((name, selector) {
          final nameOffset = selector.nameElement.nameOffset;
          final locationSource = selector.nameElement.source.fullName;
          collector.addSuggestion(_createPlainAttributeSuggestions(
              name,
              DART_RELEVANCE_DEFAULT,
              _createPlainAttributeElement(
                  name, nameOffset, locationSource, ElementKind.SETTER)));
        });
      }
    });
  }

  CompletionSuggestion _createRefValueSuggestion(
      AngularElement exportAs, int defaultRelevance, Element element) {
    final completion = exportAs.name;
    return new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
        defaultRelevance, completion, completion.length, 0, false, false,
        element: element);
  }

  Element _createRefValueElement(AngularElement exportAs, ElementKind kind) {
    final name = exportAs.name;
    final location = new Location(exportAs.source.fullName, exportAs.nameOffset,
        exportAs.nameLength, 0, 0);
    final flags = Element.makeFlags();
    return new Element(kind, name, flags, location: location);
  }

  CompletionSuggestion _createHtmlTagSuggestion(
          String elementTagName, int defaultRelevance, Element element) =>
      new CompletionSuggestion(
          CompletionSuggestionKind.INVOCATION,
          defaultRelevance,
          elementTagName,
          elementTagName.length,
          0,
          false,
          false,
          element: element);

  Element _createHtmlTagElement(
      String elementTagName, AbstractDirective directive, ElementKind kind) {
    final selector = directive.elementTags.firstWhere(
        (currSelector) => currSelector.toString() == elementTagName);
    final offset = selector.nameElement.nameOffset;
    final length = selector.nameElement.nameLength;

    final location =
        new Location(directive.source.fullName, offset, length, 0, 0);
    final flags = Element.makeFlags(
        isAbstract: false, isDeprecated: false, isPrivate: false);
    return new Element(kind, '<$elementTagName', flags, location: location);
  }

  Element _createHtmlTagTransclusionElement(
      String elementTagName, ElementKind kind, Location location) {
    final flags = Element.makeFlags(
        isAbstract: false, isDeprecated: false, isPrivate: false);
    return new Element(kind, elementTagName, flags, location: location);
  }

  CompletionSuggestion _createInputSuggestion(
      InputElement inputElement, int defaultRelevance, Element element) {
    final completion = '[${inputElement.name}]';
    return new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
        defaultRelevance, completion, completion.length, 0, false, false,
        element: element);
  }

  CompletionSuggestion _createInputInTemplateSuggestion(String prefix,
      InputElement inputElement, int defaultRelevance, Element element) {
    final capitalized = inputElement.name.substring(prefix.length);
    final firstLetter = capitalized.substring(0, 1).toLowerCase();
    final remaining = capitalized.substring(1);
    final completion = '$firstLetter$remaining:';
    return new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
        defaultRelevance, completion, completion.length, 0, false, false,
        element: element);
  }

  Element _createInputElement(InputElement inputElement, ElementKind kind) {
    final name = '[${inputElement.name}]';
    final location = new Location(inputElement.source.fullName,
        inputElement.nameOffset, inputElement.nameLength, 0, 0);
    final flags = Element.makeFlags(
        isAbstract: false, isDeprecated: false, isPrivate: false);
    return new Element(kind, name, flags, location: location);
  }

  CompletionSuggestion _createPlainAttributeSuggestions(
          String completion, int defaultRelevance, Element element) =>
      new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
          defaultRelevance, completion, completion.length, 0, false, false,
          element: element);

  Element _createPlainAttributeElement(
      String name, int nameOffset, String locationSource, ElementKind kind) {
    final location =
        new Location(locationSource, nameOffset, name.length, 0, 0);
    final flags = Element.makeFlags(
        isAbstract: false, isDeprecated: false, isPrivate: false);
    return new Element(kind, name, flags, location: location);
  }

  CompletionSuggestion _createOutputSuggestion(
      OutputElement outputElement, int defaultRelevance, Element element) {
    final completion = '(${outputElement.name})';
    return new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
        defaultRelevance, completion, completion.length, 0, false, false,
        element: element, returnType: outputElement.eventType.toString());
  }

  Element _createOutputElement(OutputElement outputElement, ElementKind kind) {
    final name = '(${ outputElement.name})';
    // Note: We use `?? 0` below because focusin/out don't have ranges but we
    // still want to suggest them.
    final location = new Location(outputElement.source.fullName,
        outputElement.nameOffset ?? 0, outputElement.nameLength ?? 0, 0, 0);
    final flags = Element.makeFlags();
    return new Element(kind, name, flags,
        location: location, returnType: outputElement.eventType.toString());
  }

  CompletionSuggestion _createBananaSuggestion(
      InputElement inputElement, int defaultRelevance, Element element) {
    final completion = '[(${inputElement.name})]';
    return new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
        defaultRelevance, completion, completion.length, 0, false, false,
        element: element, returnType: inputElement.setterType.toString());
  }

  Element _createBananaElement(InputElement inputElement, ElementKind kind) {
    final name = '[(${inputElement.name})]';
    final location = new Location(inputElement.source.fullName,
        inputElement.nameOffset, inputElement.nameLength, 0, 0);
    final flags = Element.makeFlags();
    return new Element(kind, name, flags,
        location: location, returnType: inputElement.setterType.toString());
  }

  CompletionSuggestion _createStarAttrSuggestion(
      AttributeSelector selector, int defaultRelevance, Element element) {
    final completion = '*${selector.nameElement.name}';
    return new CompletionSuggestion(CompletionSuggestionKind.IDENTIFIER,
        defaultRelevance, completion, completion.length, 0, false, false,
        element: element);
  }

  Element _createStarAttrElement(AttributeSelector selector, ElementKind kind) {
    final name = '*${selector.nameElement.name}';
    final location = new Location(
        selector.nameElement.source.fullName,
        selector.nameElement.nameOffset,
        selector.nameElement.name.length,
        0,
        0);
    final flags = Element.makeFlags();
    return new Element(kind, name, flags, location: location);
  }
}
