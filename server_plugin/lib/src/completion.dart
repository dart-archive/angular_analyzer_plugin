import 'dart:async';
import 'dart:collection';

import 'package:analysis_server/protocol/protocol_generated.dart' as protocol
    show Element, ElementKind;
import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_dart.dart';
import 'package:analysis_server/src/services/completion/completion_core.dart';
import 'package:analysis_server/src/services/completion/dart/completion_manager.dart';
import 'package:analysis_server/src/services/completion/dart/optype.dart';
import 'package:analysis_server/src/services/completion/dart/type_member_contributor.dart';
import 'package:analysis_server/src/services/completion/dart/inherited_reference_contributor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/src/generated/resolver.dart' show TypeProvider;
import 'package:angular_analyzer_plugin/src/converter.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/src/angular_driver.dart';

import 'package:analysis_server/src/protocol_server.dart'
    show CompletionSuggestion, CompletionSuggestionKind, Location;

import 'package:analysis_server/src/protocol_server.dart'
    show CompletionSuggestion;

import 'embedded_dart_completion_request.dart';

bool offsetContained(int offset, int start, int length) {
  return start <= offset && start + length >= offset;
}

AngularAstNode findTarget(int offset, AngularAstNode root) {
  for (AngularAstNode child in root.children) {
    if (child is ElementInfo) {
      if (child.isSynthetic) {
        var target = findTarget(offset, child);
        if (!(target is ElementInfo && target.openingSpan == null)) {
          return target;
        }
      } else {
        if (offsetContained(offset, child.openingNameSpan.offset,
            child.openingNameSpan.length)) {
          return child;
        } else if (offsetContained(offset, child.offset, child.length)) {
          return findTarget(offset, child);
        }
      }
    } else if (offsetContained(offset, child.offset, child.length)) {
      return findTarget(offset, child);
    }
  }
  return root;
}

class DartSnippetExtractor extends AngularAstVisitor {
  AstNode dartSnippet = null;
  int offset;

  // don't recurse, findTarget already did that
  @override
  visitElementInfo(ElementInfo element) {}

  @override
  visitTextAttr(TextAttribute attr) {}

  @override
  visitExpressionBoundAttr(ExpressionBoundAttribute attr) {
    if (attr.expression != null &&
        offsetContained(
            offset, attr.expression.offset, attr.expression.length)) {
      dartSnippet = attr.expression;
    }
  }

  @override
  visitStatementsBoundAttr(StatementsBoundAttribute attr) {
    for (Statement statement in attr.statements) {
      if (offsetContained(offset, statement.offset, statement.length)) {
        dartSnippet = statement;
      }
    }
  }

  @override
  visitMustache(Mustache mustache) {
    if (offsetContained(
        offset, mustache.expression.offset, mustache.expression.length)) {
      dartSnippet = mustache.expression;
    }
  }

  @override
  visitTemplateAttr(TemplateAttribute attr) {
    // if we visit this, we're in a template but after one of its attributes.
    AttributeInfo attributeToAppendTo;
    for (AttributeInfo subAttribute in attr.virtualAttributes) {
      if (subAttribute.valueOffset == null && subAttribute.offset < offset) {
        attributeToAppendTo = subAttribute;
      }
    }

    if (attributeToAppendTo != null &&
        attributeToAppendTo is TextAttribute &&
        !attributeToAppendTo.name.startsWith("let")) {
      AnalysisErrorListener analysisErrorListener =
          new IgnoringAnalysisErrorListener();
      EmbeddedDartParser dartParser =
          new EmbeddedDartParser(null, analysisErrorListener, null);
      dartSnippet = dartParser.parseDartExpression(offset, '', false);
    }
  }
}

class IgnoringAnalysisErrorListener implements AnalysisErrorListener {
  @override
  void onError(AnalysisError error) {}
}

class LocalVariablesExtractor extends AngularAstVisitor {
  Map<String, LocalVariable> variables = null;

  // don't recurse, findTarget already did that
  @override
  visitElementInfo(ElementInfo element) {}
  @override
  visitTextAttr(TextAttribute attr) {}

  @override
  visitExpressionBoundAttr(ExpressionBoundAttribute attr) {
    variables = attr.localVariables;
  }

  @override
  visitStatementsBoundAttr(StatementsBoundAttribute attr) {
    variables = attr.localVariables;
  }

  @override
  visitMustache(Mustache mustache) {
    variables = mustache.localVariables;
  }
}

class ReplacementRangeCalculator extends AngularAstVisitor {
  CompletionRequestImpl request;

  ReplacementRangeCalculator(this.request);

  // don't recurse, findTarget already did that
  @override
  visitElementInfo(ElementInfo element) {
    if (element.openingSpan == null) {
      return;
    }
    int nameSpanEnd =
        element.openingNameSpan.offset + element.openingNameSpan.length;
    if (offsetContained(request.offset, element.openingSpan.offset,
        nameSpanEnd - element.openingSpan.offset)) {
      request.replacementOffset = element.openingSpan.offset;
      request.replacementLength = element.localName.length + 1;
    }
  }

  @override
  visitTextAttr(TextAttribute attr) {
    if (!attr.fromTemplate &&
        offsetContained(request.offset, attr.originalNameOffset,
            attr.originalName.length)) {
      request.replacementOffset = attr.originalNameOffset;
      request.replacementLength = attr.originalName.length;
    }
  }

  @override
  visitTextInfo(TextInfo textInfo) {
    if (request.offset > textInfo.offset &&
        textInfo.text[request.offset - textInfo.offset - 1] == '<') {
      request.replacementOffset--;
      request.replacementLength = 1;
    }
  }

  @override
  visitExpressionBoundAttr(ExpressionBoundAttribute attr) {
    if (offsetContained(
        request.offset, attr.originalNameOffset, attr.originalName.length)) {
      request.replacementOffset = attr.originalNameOffset;
      request.replacementLength = attr.originalName.length;
    }
  }

  @override
  visitStatementsBoundAttr(StatementsBoundAttribute attr) {
    if (offsetContained(
        request.offset, attr.originalNameOffset, attr.originalName.length)) {
      request.replacementOffset = attr.originalNameOffset;
      request.replacementLength = attr.originalName.length;
    }
  }

  @override
  visitMustache(Mustache mustache) {}
}

/**
 * Contributor to contribute angular entities.
 */
class AngularCompletionContributor extends CompletionContributor {
  final AngularDriver driver;

  /// Initialize a newly created handler to handle requests for the given
  /// [server].
  AngularCompletionContributor(this.driver);

  /**
   * Return a [Future] that completes with a list of suggestions
   * for the given completion [request].
   */
  Future<List<CompletionSuggestion>> computeSuggestions(
      CompletionRequest request) async {
    var suggestions = <CompletionSuggestion>[];
    var filePath = request.source.toString();

    await driver.getStandardHtml();
    assert(driver.standardHtml != null);

    var events = driver.standardHtml.events.values;
    var attributes = driver.standardHtml.attributes.values;
    var templates = await driver.getTemplatesForFile(filePath);

    if (templates.isEmpty) {
      return <CompletionSuggestion>[];
    }
    var templateCompleter = new TemplateCompleter();
    for (var template in templates) {
      suggestions.addAll(await templateCompleter.computeSuggestions(
        request,
        template,
        events,
        attributes,
      ));
    }
    return suggestions;
  }
}

class TemplateCompleter {
  static const int RELEVANCE_TRANSCLUSION = DART_RELEVANCE_DEFAULT + 10;

  Future<List<CompletionSuggestion>> computeSuggestions(
    CompletionRequest request,
    Template template,
    List<OutputElement> standardHtmlEvents,
    List<InputElement> standardHtmlAttributes,
  ) async {
    List<CompletionSuggestion> suggestions = <CompletionSuggestion>[];
    var typeProvider = template.view.component.classElement.enclosingElement
        .enclosingElement.context.typeProvider;
    AngularAstNode target = findTarget(request.offset, template.ast);
    target.accept(new ReplacementRangeCalculator(request));
    DartSnippetExtractor extractor = new DartSnippetExtractor();
    extractor.offset = request.offset;
    target.accept(extractor);
    if (extractor.dartSnippet != null) {
      EmbeddedDartCompletionRequest dartRequest =
          new EmbeddedDartCompletionRequest.from(
              request, extractor.dartSnippet);

      ReplacementRange range =
          new ReplacementRange.compute(dartRequest.offset, dartRequest.target);
      (request as CompletionRequestImpl)
        ..replacementOffset = range.offset
        ..replacementLength = range.length;

      dartRequest.libraryElement = template.view.classElement.library;
      TypeMemberContributor memberContributor = new TypeMemberContributor();
      InheritedReferenceContributor inheritedContributor =
          new InheritedReferenceContributor();
      suggestions.addAll(inheritedContributor.computeSuggestionsForClass(
          template.view.classElement, dartRequest,
          skipChildClass: false));
      suggestions
          .addAll(await memberContributor.computeSuggestions(dartRequest));

      if (dartRequest.opType.includeIdentifiers) {
        LocalVariablesExtractor varExtractor = new LocalVariablesExtractor();
        target.accept(varExtractor);
        if (varExtractor.variables != null) {
          addLocalVariables(
              suggestions, varExtractor.variables, dartRequest.opType);
        }
      }
    } else if (target is ElementInfo &&
        target.openingSpan == null &&
        target.localName == 'html' &&
        target.childNodes.isNotEmpty &&
        target.childNodes.length == 2 &&
        target.childNodes[1] is ElementInfo &&
        (target.childNodes[1] as ElementInfo).localName == 'body' &&
        (target.childNodes[1] as ElementInfo).childNodes.isEmpty) {
      //On an empty document
      suggestHtmlTags(template, suggestions);
    } else if (target is ElementInfo &&
        target.openingSpan != null &&
        target.openingNameSpan != null &&
        (offsetContained(request.offset, target.openingSpan.offset,
            target.openingSpan.length))) {
      if (!offsetContained(request.offset, target.openingNameSpan.offset,
          target.openingNameSpan.length)) {
        // TODO suggest these things if the target is ExpressionBoundInput with
        // boundType of input
        suggestInputs(target.boundDirectives, suggestions,
            standardHtmlAttributes, target.boundStandardInputs, typeProvider,
            includePlainAttributes: true);
        suggestOutputs(target.boundDirectives, suggestions, standardHtmlEvents,
            target.boundStandardOutputs);
      } else {
        suggestHtmlTags(template, suggestions);
        if (target.parent != null) {
          suggestTransclusions(target.parent, suggestions);
        }
      }
    } else if (target is ElementInfo &&
        target.openingSpan != null &&
        target.openingNameSpan != null &&
        target.closingSpan != null &&
        target.closingNameSpan != null &&
        request.offset ==
            (target.closingSpan.offset + target.closingSpan.length)) {
      suggestHtmlTags(template, suggestions);
      suggestTransclusions(target.parent, suggestions);
    } else if (target is ElementInfo &&
        target.openingSpan != null &&
        request.offset == target.childNodesMaxEnd) {
      suggestHtmlTags(template, suggestions);
      suggestTransclusions(target, suggestions);
    } else if (target is ElementInfo) {
      suggestHtmlTags(template, suggestions);
      suggestTransclusions(target, suggestions);
    } else if (target is ExpressionBoundAttribute &&
        target.bound == ExpressionBoundType.input &&
        offsetContained(request.offset, target.originalNameOffset,
            target.originalName.length)) {
      suggestInputs(
          target.parent.boundDirectives,
          suggestions,
          standardHtmlAttributes,
          target.parent.boundStandardInputs,
          typeProvider,
          currentAttr: target);
    } else if (target is StatementsBoundAttribute) {
      suggestOutputs(target.parent.boundDirectives, suggestions,
          standardHtmlEvents, target.parent.boundStandardOutputs,
          currentAttr: target);
    } else if (target is TemplateAttribute) {
      suggestInputs(
          target.parent.boundDirectives,
          suggestions,
          standardHtmlAttributes,
          target.parent.boundStandardInputs,
          typeProvider,
          includePlainAttributes: true);
      suggestOutputs(target.parent.boundDirectives, suggestions,
          standardHtmlEvents, target.parent.boundStandardOutputs);
    } else if (target is TextAttribute) {
      suggestInputs(
          target.parent.boundDirectives,
          suggestions,
          standardHtmlAttributes,
          target.parent.boundStandardInputs,
          typeProvider,
          includePlainAttributes: true);
      suggestOutputs(target.parent.boundDirectives, suggestions,
          standardHtmlEvents, target.parent.boundStandardOutputs);
    } else if (target is TextInfo) {
      suggestHtmlTags(template, suggestions);
      suggestTransclusions(target.parent, suggestions);
    }
    return suggestions;
  }

  suggestTransclusions(
      ElementInfo container, List<CompletionSuggestion> suggestions) {
    for (AbstractDirective directive in container.directives) {
      if (directive is! Component) {
        continue;
      }

      Component component = directive;
      var view = component?.view;
      if (view == null) {
        continue;
      }

      for (NgContent ngContent in component.ngContents) {
        if (ngContent.selector == null) {
          continue;
        }

        List<HtmlTagForSelector> tags = ngContent.selector.suggestTags();
        for (HtmlTagForSelector tag in tags) {
          Location location = new Location(view.templateSource.fullName,
              ngContent.offset, ngContent.length, 0, 0);
          suggestions.add(_createHtmlTagSuggestion(
              tag.toString(),
              RELEVANCE_TRANSCLUSION,
              _createHtmlTagTransclusionElement(tag.toString(),
                  protocol.ElementKind.CLASS_TYPE_ALIAS, location)));
        }
      }
    }
  }

  suggestHtmlTags(Template template, List<CompletionSuggestion> suggestions) {
    Map<String, List<AbstractDirective>> elementTagMap =
        template.view.elementTagsInfo;
    for (String elementTagName in elementTagMap.keys) {
      CompletionSuggestion currentSuggestion = _createHtmlTagSuggestion(
          '<' + elementTagName,
          DART_RELEVANCE_DEFAULT,
          _createHtmlTagElement(
              elementTagName,
              elementTagMap[elementTagName].first,
              protocol.ElementKind.CLASS_TYPE_ALIAS));
      if (currentSuggestion != null) {
        suggestions.add(currentSuggestion);
      }
    }
  }

  suggestInputs(
    List<DirectiveBinding> directives,
    List<CompletionSuggestion> suggestions,
    List<InputElement> standardHtmlAttributes,
    List<InputBinding> boundStandardAttributes,
    TypeProvider typeProvider, {
    ExpressionBoundAttribute currentAttr,
    bool includePlainAttributes: false,
  }) {
    for (DirectiveBinding directive in directives) {
      Set<InputElement> usedInputs = new HashSet.from(directive.inputBindings
          .where((b) => b.attribute != currentAttr)
          .map((b) => b.boundInput));

      for (InputElement input in directive.boundDirective.inputs) {
        // don't recommend [name] [name] [name]
        if (usedInputs.contains(input)) {
          continue;
        }

        if (includePlainAttributes && typeProvider != null) {
          if (typeProvider.stringType.isAssignableTo(input.setterType)) {
            var relevance = input.setterType.displayName == 'String'
                ? DART_RELEVANCE_DEFAULT
                : DART_RELEVANCE_DEFAULT - 1;
            suggestions.add(_createPlainAttributeSuggestions(
                input,
                relevance,
                _createPlainAttributeElement(
                    input, protocol.ElementKind.SETTER)));
          }
        }
        suggestions.add(_createInputSuggestion(input, DART_RELEVANCE_DEFAULT,
            _createInputElement(input, protocol.ElementKind.SETTER)));
      }
    }

    Set<InputElement> usedStdInputs = new HashSet.from(boundStandardAttributes
        .where((b) => b.attribute != currentAttr)
        .map((b) => b.boundInput));

    for (InputElement input in standardHtmlAttributes) {
      // TODO don't recommend [hidden] [hidden] [hidden]
      if (usedStdInputs.contains(input)) {
        continue;
      }
      if (includePlainAttributes && typeProvider != null) {
        if (typeProvider.stringType.isAssignableTo(input.setterType)) {
          var relevance = input.setterType.displayName == 'String'
              ? DART_RELEVANCE_DEFAULT - 2
              : DART_RELEVANCE_DEFAULT - 3;
          suggestions.add(_createPlainAttributeSuggestions(
              input,
              relevance,
              _createPlainAttributeElement(
                  input, protocol.ElementKind.SETTER)));
        }
      }
      suggestions.add(_createInputSuggestion(input, DART_RELEVANCE_DEFAULT - 2,
          _createInputElement(input, protocol.ElementKind.SETTER)));
    }
  }

  suggestOutputs(
      List<DirectiveBinding> directives,
      List<CompletionSuggestion> suggestions,
      List<OutputElement> standardHtmlEvents,
      List<OutputBinding> boundStandardOutputs,
      {BoundAttributeInfo currentAttr}) {
    for (DirectiveBinding directive in directives) {
      Set<OutputElement> usedOutputs = new HashSet.from(directive.outputBindings
          .where((b) => b.attribute != currentAttr)
          .map((b) => b.boundOutput));
      for (OutputElement output in directive.boundDirective.outputs) {
        // don't recommend (close) (close) (close)
        if (usedOutputs.contains(output)) {
          continue;
        }
        suggestions.add(_createOutputSuggestion(output, DART_RELEVANCE_DEFAULT,
            _createOutputElement(output, protocol.ElementKind.GETTER)));
      }
    }

    Set<OutputElement> usedStdOutputs = new HashSet.from(boundStandardOutputs
        .where((b) => b.attribute != currentAttr)
        .map((b) => b.boundOutput));

    for (OutputElement output in standardHtmlEvents) {
      // don't recommend (click) (click) (click)
      if (usedStdOutputs.contains(output)) {
        continue;
      }
      suggestions.add(_createOutputSuggestion(
          output,
          DART_RELEVANCE_DEFAULT - 1, // just below regular relevance
          _createOutputElement(output, protocol.ElementKind.GETTER)));
    }
  }

  addLocalVariables(List<CompletionSuggestion> suggestions,
      Map<String, LocalVariable> localVars, OpType optype) {
    for (LocalVariable eachVar in localVars.values) {
      suggestions.add(_addLocalVariableSuggestion(
          eachVar,
          eachVar.dartVariable.type,
          protocol.ElementKind.LOCAL_VARIABLE,
          optype,
          relevance: DART_RELEVANCE_LOCAL_VARIABLE));
    }
  }

  CompletionSuggestion _addLocalVariableSuggestion(LocalVariable variable,
      DartType typeName, protocol.ElementKind elemKind, OpType optype,
      {int relevance: DART_RELEVANCE_DEFAULT}) {
    relevance = optype.returnValueSuggestionsFilter(
            variable.dartVariable.type, relevance) ??
        DART_RELEVANCE_DEFAULT;
    return _createLocalSuggestion(variable, relevance, typeName,
        _createLocalElement(variable, elemKind, typeName));
  }

  CompletionSuggestion _createLocalSuggestion(LocalVariable localVar,
      int defaultRelevance, DartType type, protocol.Element element) {
    String completion = localVar.name;
    return new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
        defaultRelevance, completion, completion.length, 0, false, false,
        returnType: type.toString(), element: element);
  }

  protocol.Element _createLocalElement(
      LocalVariable localVar, protocol.ElementKind kind, DartType type) {
    String name = localVar.name;
    Location location = new Location(localVar.source.fullName,
        localVar.nameOffset, localVar.nameLength, 0, 0);
    int flags = protocol.Element.makeFlags();
    return new protocol.Element(kind, name, flags,
        location: location, returnType: type.toString());
  }

  CompletionSuggestion _createHtmlTagSuggestion(
      String elementTagName, int defaultRelevance, protocol.Element element) {
    return new CompletionSuggestion(
        CompletionSuggestionKind.INVOCATION,
        defaultRelevance,
        elementTagName,
        elementTagName.length,
        0,
        false,
        false,
        element: element);
  }

  protocol.Element _createHtmlTagElement(String elementTagName,
      AbstractDirective directive, protocol.ElementKind kind) {
    ElementNameSelector selector = directive.elementTags.firstWhere(
        (currSelector) => currSelector.toString() == elementTagName);
    int offset = selector.nameElement.nameOffset;
    int length = selector.nameElement.nameLength;

    Location location =
        new Location(directive.source.fullName, offset, length, 0, 0);
    int flags = protocol.Element
        .makeFlags(isAbstract: false, isDeprecated: false, isPrivate: false);
    return new protocol.Element(kind, '<' + elementTagName, flags,
        location: location);
  }

  protocol.Element _createHtmlTagTransclusionElement(
      String elementTagName, protocol.ElementKind kind, Location location) {
    int flags = protocol.Element
        .makeFlags(isAbstract: false, isDeprecated: false, isPrivate: false);
    return new protocol.Element(kind, elementTagName, flags,
        location: location);
  }

  CompletionSuggestion _createInputSuggestion(InputElement inputElement,
      int defaultRelevance, protocol.Element element) {
    String completion = '[' + inputElement.name + ']';
    return new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
        defaultRelevance, completion, completion.length, 0, false, false,
        element: element);
  }

  protocol.Element _createInputElement(
      InputElement inputElement, protocol.ElementKind kind) {
    String name = '[' + inputElement.name + ']';
    Location location = new Location(inputElement.source.fullName,
        inputElement.nameOffset, inputElement.nameLength, 0, 0);
    int flags = protocol.Element
        .makeFlags(isAbstract: false, isDeprecated: false, isPrivate: false);
    return new protocol.Element(kind, name, flags, location: location);
  }

  CompletionSuggestion _createPlainAttributeSuggestions(
      InputElement inputElement,
      int defaultRelevance,
      protocol.Element element) {
    String completion = inputElement.name;
    return new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
        defaultRelevance, completion, completion.length, 0, false, false,
        element: element);
  }

  protocol.Element _createPlainAttributeElement(
      InputElement inputElement, protocol.ElementKind kind) {
    String name = inputElement.name;
    Location location = new Location(inputElement.source.fullName,
        inputElement.nameOffset, inputElement.nameLength, 0, 0);
    int flags = protocol.Element
        .makeFlags(isAbstract: false, isDeprecated: false, isPrivate: false);
    return new protocol.Element(kind, name, flags, location: location);
  }

  CompletionSuggestion _createOutputSuggestion(OutputElement outputElement,
      int defaultRelevance, protocol.Element element) {
    String completion = '(' + outputElement.name + ')';
    return new CompletionSuggestion(CompletionSuggestionKind.INVOCATION,
        defaultRelevance, completion, completion.length, 0, false, false,
        element: element, returnType: outputElement.eventType.toString());
  }

  protocol.Element _createOutputElement(
      OutputElement outputElement, protocol.ElementKind kind) {
    String name = '(' + outputElement.name + ')';
    Location location = new Location(outputElement.source.fullName,
        outputElement.nameOffset, outputElement.nameLength, 0, 0);
    int flags = protocol.Element.makeFlags();
    return new protocol.Element(kind, name, flags,
        location: location, returnType: outputElement.eventType.toString());
  }
}
