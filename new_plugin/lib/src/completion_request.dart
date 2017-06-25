import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/ast/ast.dart' show CompilationUnit;
import 'package:analyzer/error/error.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:analyzer_plugin/utilities/completion/completion_core.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';

class AngularCompletionRequest extends CompletionRequest {
  final List<Template> templates;
  final StandardHtml standardHtml;
  final String path;

  @override
  final int offset;

  @override
  final ResourceProvider resourceProvider;

  AngularCompletionRequest(this.offset, this.path, this.resourceProvider,
      this.templates, this.standardHtml);

  /// Flag indicating if completion has been aborted.
  bool _aborted = false;

  /// Abort the current completion request.
  void abort() {
    _aborted = true;
  }

  @override
  void checkAborted() {
    if (_aborted) {
      // ignore: only_throw_errors
      throw new AbortCompletion();
    }
  }
}
