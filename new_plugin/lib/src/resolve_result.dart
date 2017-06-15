import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/ast/ast.dart' show CompilationUnit;
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';

class CompletionResolveResult extends NgResolveResult {
  final List<Template> templates;
  final StandardHtml standardHtml;

  // Don't need errors - pass in empty list.
  CompletionResolveResult(String path, this.templates, this.standardHtml)
      : super(path, const []);
}

class NgResolveResult implements ResolveResult {
  @override
  String get content => null;

  @override
  LibraryElement libraryElement;

  @override
  TypeProvider typeProvider;

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

  NgResolveResult(this.path, this.errors,
      {this.libraryElement, this.typeProvider});
}
