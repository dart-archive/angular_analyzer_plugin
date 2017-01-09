import 'dart:async';
import 'dart:collection';

import 'package:analysis_server/plugin/protocol/protocol.dart' as protocol
    show Element, ElementKind;
import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_dart.dart';
import 'package:analysis_server/src/services/completion/dart/optype.dart';
import 'package:analysis_server/src/services/completion/dart/type_member_contributor.dart';
import 'package:analysis_server/src/services/completion/dart/inherited_reference_contributor.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/task/model.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/tasks.dart';
import 'package:angular_analyzer_plugin/ast.dart';

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
    if (child is ElementInfo && child.openingSpan == null) {
      var target = findTarget(offset, child);
      if (!(target is ElementInfo && target.openingSpan == null)) {
        return target;
      }
    } else if (offsetContained(offset, child.offset, child.length)) {
      return findTarget(offset, child);
    }
  }
  return root;
}

AngularAstNode findTargetInExtraNodes(int offset, List<NodeInfo> extraNodes) {
  if (extraNodes != null && extraNodes.isNotEmpty) {
    for (NodeInfo node in extraNodes) {
      if (offsetContained(offset, node.offset, node.length)) {
        return node;
      }
    }
  }
  return null;
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

class AngularDartCompletionContributor extends DartCompletionContributor {
  /**
   * Return a [Future] that completes with a list of suggestions
   * for the given completion [request].
   */
  Future<List<CompletionSuggestion>> computeSuggestions(
      DartCompletionRequest request) async {
    List<Template> templates = request.context.computeResult(
        new LibrarySpecificUnit(request.librarySource, request.source),
        DART_TEMPLATES);
    List<OutputElement> standardHtmlEvents = request.context
        .computeResult(
            AnalysisContextTarget.request, STANDARD_HTML_ELEMENT_EVENTS)
        .values;

    return new TemplateCompleter()
        .computeSuggestions(request, templates, standardHtmlEvents);
  }
}

class AngularTemplateCompletionContributor extends CompletionContributor {
  /**
   * Return a [Future] that completes with a list of suggestions
   * for the given completion [request]. This will
   * throw [AbortCompletion] if the completion request has been aborted.
   */
  Future<List<CompletionSuggestion>> computeSuggestions(
      CompletionRequest request) async {
    if (request.source.shortName.endsWith('.html')) {
      List<Template> templates =
          request.context.computeResult(request.source, HTML_TEMPLATES);
      List<OutputElement> standardHtmlEvents = request.context
          .computeResult(
              AnalysisContextTarget.request, STANDARD_HTML_ELEMENT_EVENTS)
          .values;

      return new TemplateCompleter()
          .computeSuggestions(request, templates, standardHtmlEvents);
    }

    return [];
  }
}

class TemplateCompleter {
  Future<List<CompletionSuggestion>> computeSuggestions(
      CompletionRequest request,
      List<Template> templates,
      List<OutputElement> standardHtmlEvents) async {
    List<CompletionSuggestion> suggestions = <CompletionSuggestion>[];
    for (Template template in templates) {
      bool extraNodesUsed = false;
      AngularAstNode target;
      target = findTargetInExtraNodes(request.offset, template.extraNodes);
      if (target != null){
        extraNodesUsed = true;
      }else {
        target = findTarget(request.offset, template.ast);
      }
      DartSnippetExtractor extractor = new DartSnippetExtractor();
      extractor.offset = request.offset;
      target.accept(extractor);
      if (extractor.dartSnippet != null) {
        EmbeddedDartCompletionRequest dartRequest =
            new EmbeddedDartCompletionRequest.from(
                request, extractor.dartSnippet);

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
      } else if (target is ElementInfo && target.openingSpan == null &&
          target.localName == 'html' && target.childNodes.isNotEmpty &&
          target.childNodes.length == 2 && target.childNodes[1] is ElementInfo &&
          (target.childNodes[1] as ElementInfo).localName == 'body' &&
          (target.childNodes[1] as ElementInfo).childNodes.isEmpty){
        //On an empty document
        suggestHtmlTags(template,suggestions, addOpenBracket: true);
      } else if (target is ElementInfo &&
          target.openingSpan != null &&
          target.openingNameSpan != null &&
          offsetContained(request.offset, target.openingSpan.offset,
              target.openingSpan.length - '>'.length)) {
        if (!offsetContained(request.offset, target.openingNameSpan.offset,
            target.openingNameSpan.length)) {
          // TODO suggest these things if the target is ExpressionBoundInput with
          // boundType of input
          suggestInputs(target.boundDirectives, suggestions);
          suggestOutputs(target.boundDirectives, suggestions,
              standardHtmlEvents, target.boundStandardOutputs);
        } else {
          suggestHtmlTags(template, suggestions);
        }
      } else if (target is ElementInfo && target.openingSpan != null &&
          target.openingNameSpan != null && target.closingSpan != null &&
          target.closingNameSpan != null &&
          request.offset == (target.closingSpan.offset + target.closingSpan.length)){
        suggestHtmlTags(template, suggestions, addOpenBracket: true);
      }else if (target is ExpressionBoundAttribute &&
          target.bound == ExpressionBoundType.input &&
          offsetContained(request.offset, target.originalNameOffset,
              target.originalName.length)) {
        suggestInputs(target.parent.boundDirectives, suggestions,
            currentAttr: target);
      } else if (target is StatementsBoundAttribute) {
        suggestOutputs(target.parent.boundDirectives, suggestions,
            standardHtmlEvents, target.parent.boundStandardOutputs,
            currentAttr: target);
      } else if (target is TextInfo) {
        bool addOpenBracket = extraNodesUsed ? false :
            target.text[request.offset - target.offset - 1] != '<';
        suggestHtmlTags(template, suggestions, addOpenBracket: addOpenBracket);
      }
    }

    return suggestions;
  }

  suggestHtmlTags(Template template, List<CompletionSuggestion> suggestions,
      {bool addOpenBracket: false}) {
    Map<String, List<AbstractDirective>> elementTagMap =
        template.view.elementTagsInfo;
    String leftPad = addOpenBracket ? "<" : "";
    for (String elementTagName in elementTagMap.keys) {
      CompletionSuggestion currentSuggestion = _createHtmlTagSuggestion(
          leftPad + elementTagName,
          DART_RELEVANCE_DEFAULT,
          _createHtmlTagElement(
              elementTagName,
              leftPad,
              elementTagMap[elementTagName].first,
              protocol.ElementKind.CLASS_TYPE_ALIAS));
      if (currentSuggestion != null) {
        suggestions.add(currentSuggestion);
      }
    }
  }

  suggestInputs(
      List<DirectiveBinding> directives, List<CompletionSuggestion> suggestions,
      {ExpressionBoundAttribute currentAttr}) {
    for (DirectiveBinding directive in directives) {
      Set<InputElement> usedInputs = new HashSet.from(directive.inputBindings
          .where((b) => b.attribute != currentAttr)
          .map((b) => b.boundInput));
      for (InputElement input in directive.boundDirective.inputs) {
        // don't recommend [name] [name] [name]
        if (usedInputs.contains(input)) {
          continue;
        }
        suggestions.add(_createInputSuggestion(input, DART_RELEVANCE_DEFAULT,
            _createInputElement(input, protocol.ElementKind.SETTER)));
      }
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

  protocol.Element _createHtmlTagElement(String elementTagName, String leftPad,
      AbstractDirective directive, protocol.ElementKind kind) {
    ElementNameSelector selector = directive.elementTags.firstWhere(
        (currSelector) => currSelector.toString() == elementTagName);
    int offset = selector.nameElement.nameOffset;
    int length = selector.nameElement.nameLength;

    Location location =
        new Location(directive.source.fullName, offset, length, 0, 0);
    int flags = protocol.Element
        .makeFlags(isAbstract: false, isDeprecated: false, isPrivate: false);
    return new protocol.Element(kind, leftPad + elementTagName, flags,
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
