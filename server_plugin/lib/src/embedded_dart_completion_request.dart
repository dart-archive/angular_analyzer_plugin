import 'dart:async';

import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_dart.dart';
import 'package:analysis_server/src/services/completion/dart/optype.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_target.dart';
import 'package:analysis_server/src/services/search/search_engine.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisContext;
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/file_system.dart';

import 'package:analyzer/dart/ast/ast.dart';

class EmbeddedDartCompletionRequest implements DartCompletionRequest {
  factory EmbeddedDartCompletionRequest.from(
      CompletionRequest request, AstNode dart) {
    request.checkAborted();

    Source libSource;
    if (request.context != null) {
      Source source = request.source;
      libSource = source;
    }

    var dartRequest = new EmbeddedDartCompletionRequest._(
        request.result,
        request.context,
        request.resourceProvider,
        request.searchEngine,
        libSource,
        request.source,
        request.offset);

    dartRequest._updateTargets(dart);
    return dartRequest;
  }

  EmbeddedDartCompletionRequest._(
      this.result,
      this.context,
      this.resourceProvider,
      this.searchEngine,
      this.librarySource,
      this.source,
      this.offset) {}

  /**
   * Update the completion [target] and [dotTarget] based on the given [dart] AST
   */
  void _updateTargets(AstNode dart) {
    dotTarget = null;
    target = new CompletionTarget.forOffset(null, offset, entryPoint: dart);
    opType = new OpType.forCompletion(target, offset);

    // if the containing node IS the AST, it means the context decides what's
    // completable. In that case, that's in our court only.
    if (target.containingNode == dart) {
      opType.includeReturnValueSuggestions = true;
      opType.includeTypeNameSuggestions = true;
      // only embedded statements should return void
      opType.includeVoidReturnSuggestions = !(dart is Expression);
    }

    AstNode node = target.containingNode;
    if (node is MethodInvocation) {
      if (identical(node.methodName, target.entity)) {
        dotTarget = node.realTarget;
      } else if (node.isCascaded && node.operator.offset + 1 == target.offset) {
        dotTarget = node.realTarget;
      }
    }
    if (node is PropertyAccess) {
      if (identical(node.propertyName, target.entity)) {
        dotTarget = node.realTarget;
      } else if (node.isCascaded && node.operator.offset + 1 == target.offset) {
        dotTarget = node.realTarget;
      }
    }
    if (node is PrefixedIdentifier) {
      if (identical(node.identifier, target.entity)) {
        dotTarget = node.prefix;
      }
    }
  }

  @override
  AnalysisContext context;

  @override
  int offset;

  @override
  ResourceProvider resourceProvider;

  @override
  AnalysisResult result;

  @override
  SearchEngine searchEngine;

  @override
  Source source;

  @override
  String sourceContents;

  @override
  void checkAborted() {}

  @override
  OpType opType;

  @override
  CompletionTarget target;

  /**
   * Do nothing here, our expressions are already resolved.
   */
  @override
  Future resolveContainingExpression(AstNode node) async {}

  /**
   * Do nothing here, our statements are already resolved.
   */
  @override
  Future resolveContainingStatement(AstNode node) async {}

  /**
   * We don't use completions which rely on this
   */
  @override
  Future<List<ImportElement>> resolveImports() async {
    return [];
  }

  /**
   * We don't use completions which rely on this
   */
  @override
  Future<List<CompilationUnitElement>> resolveUnits() async {
    return [];
  }

  @override
  LibraryElement coreLib;

  @override
  Expression dotTarget;

  @override
  bool get includeIdentifiers {
    return opType.includeIdentifiers;
  }

  /**
   * We have to return non null or much code will view this as an isolated part
   * file. We will use our template's libraryElement.
   */
  @override
  LibraryElement libraryElement;

  /**
   * We have to return non null or much code will view this as an isolated part
   * file. We will use our template's libraryElement.
   */
  @override
  Source librarySource;

  /**
   * Answer the [DartType] for Object in dart:core
   */
  @override
  DartType objectType;

  /**
   * Return the [SourceFactory] of the request.
   */
  @override
  SourceFactory sourceFactory;
}
