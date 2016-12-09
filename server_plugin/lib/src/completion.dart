import 'dart:async';

import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_dart.dart';
import 'package:analysis_server/src/services/completion/dart/type_member_contributor.dart';
import 'package:analysis_server/src/services/completion/dart/inherited_reference_contributor.dart';
import 'package:analyzer/task/dart.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/tasks.dart';

import 'package:analysis_server/src/protocol_server.dart'
    show CompletionSuggestion;

import 'embedded_dart_completion_request.dart';

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
      for (Expression expression in template.embeddedExpressions) {
        if (expression.offset <= request.offset &&
            expression.offset + expression.length >= request.offset) {
          EmbeddedDartCompletionRequest dartRequest =
              new EmbeddedDartCompletionRequest.from(request, expression);

          dartRequest.libraryElement = template.view.classElement.library;
          TypeMemberContributor memberContributor = new TypeMemberContributor();
          InheritedReferenceContributor inheritedContributor =
              new InheritedReferenceContributor();
          suggestions.addAll(inheritedContributor.computeSuggestionsForClass(
              template.view.classElement, dartRequest,
              skipChildClass: false));
          suggestions
              .addAll(await memberContributor.computeSuggestions(dartRequest));
        }
      }
    }

    return suggestions;
  }
}
