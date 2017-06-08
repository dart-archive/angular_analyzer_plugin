import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/ast/ast.dart' show CompilationUnit;
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:analyzer/dart/analysis/results.dart';

class CompletionResolveResult extends NgResolveResult {
  final List<Template> templates;
  final List<OutputElement> standardHtmlEvents;
  final Set<InputElement> standardHtmlAttributes;

  // Don't need errors - pass in empty list.
  CompletionResolveResult(
    String path,
    this.templates,
    this.standardHtmlEvents,
    this.standardHtmlAttributes,
  )
      : super(path, []);
}

class NgResolveResult implements ResolveResult {
  @override
  String get content => null;

  @override
  LibraryElement get libraryElement => null;

  @override
  TypeProvider get typeProvider => null;

  @override
  CompilationUnit get unit => null;

  @override
  final List<AnalysisError> errors;

  @override
  LineInfo get lineInfo => null;

  @override
  final String path;

  @override
  ResultState get state => null;

  @override
  Uri get uri => null;

  NgResolveResult(this.path, this.errors);
}
