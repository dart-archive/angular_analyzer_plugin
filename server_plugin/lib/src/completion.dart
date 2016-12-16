import 'dart:async';

import 'package:analysis_server/plugin/protocol/protocol.dart' as protocol
    show Element, ElementKind;
import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_dart.dart';
import 'package:analysis_server/src/services/completion/dart/optype.dart';
import 'package:analysis_server/src/services/completion/dart/type_member_contributor.dart';
import 'package:analysis_server/src/services/completion/dart/inherited_reference_contributor.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
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
      if (!(target is ElementInfo && child.openingSpan == null)) {
        return target;
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
    if (offsetContained(
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

    return new TemplateCompleter().computeSuggestions(request, templates);
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

      return new TemplateCompleter().computeSuggestions(request, templates);
    }

    return [];
  }
}

class TemplateCompleter {
  Future<List<CompletionSuggestion>> computeSuggestions(
      CompletionRequest request, List<Template> templates) async {
    List<CompletionSuggestion> suggestions = <CompletionSuggestion>[];
    for (Template template in templates) {
      AngularAstNode target = findTarget(request.offset, template.ast);
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
      }
    }

    return suggestions;
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
    int flags = protocol.Element
        .makeFlags(isAbstract: false, isDeprecated: false, isPrivate: false);
    return new protocol.Element(kind, name, flags,
        location: location, returnType: type.toString());
  }
}
