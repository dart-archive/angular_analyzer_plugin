import 'package:analysis_server/src/provisional/completion/completion_core.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_dart.dart';
import 'package:analyzer/src/dart/analysis/driver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer_plugin/src/utilities/completion/completion_target.dart';
import 'package:analyzer_plugin/src/utilities/completion/optype.dart';

import 'package:analyzer/dart/ast/ast.dart';

class EmbeddedDartCompletionRequest implements DartCompletionRequest {
  factory EmbeddedDartCompletionRequest.from(
      CompletionRequest request, AstNode dart) {
    request.checkAborted();

    Source libSource;
    libSource = request.source;

    return new EmbeddedDartCompletionRequest._(request.result,
        request.resourceProvider, libSource, request.source, request.offset)
      .._updateTargets(dart);
  }

  EmbeddedDartCompletionRequest._(this.result, this.resourceProvider,
      this.librarySource, this.source, this.offset);

  /// Update the completion [target] and [dotTarget] based on the given [dart] AST
  void _updateTargets(AstNode dart) {
    dotTarget = null;
    target = new CompletionTarget.forOffset(null, offset, entryPoint: dart);
    opType = new OpType.forCompletion(target, offset);

    // if the containing node IS the AST, it means the context decides what's
    // completable. In that case, that's in our court only.
    if (target.containingNode == dart) {
      opType
        ..includeReturnValueSuggestions = true
        ..includeTypeNameSuggestions = true
        // expressions always have nonvoid returns
        ..includeVoidReturnSuggestions = !(dart is Expression);
    }

    // NG Expressions (not statements) always must return something. We have to
    // force that ourselves here.
    if (dart is Expression) {
      opType.includeVoidReturnSuggestions = false;
    }

    // Below is copied from analysis_server.../completion_manager.dart.
    final node = target.containingNode;
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
  int offset;

  @override
  ResourceProvider resourceProvider;

  @override
  AnalysisResult result;

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

  @override
  LibraryElement coreLib;

  @override
  Expression dotTarget;

  @override
  bool get includeIdentifiers => opType.includeIdentifiers;

  /// We have to return non null or much code will view this as an isolated part
  /// file. We will use our template's libraryElement.
  @override
  LibraryElement libraryElement;

  /// We have to return non null or much code will view this as an isolated part
  /// file. We will use our template's libraryElement.
  @override
  Source librarySource;

  /// Answer the [DartType] for Object in dart:core
  @override
  DartType objectType;

  /// Return the [SourceFactory] of the request.
  @override
  SourceFactory sourceFactory;
}
