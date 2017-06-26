import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/src/generated/resolver.dart' show TypeProvider;
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'tasks.dart';

class PipeExtractor extends AnnotationProcessorMixin {
  final TypeProvider _typeProvider;
  final ast.CompilationUnit _unit;
  final Source _source;
  final AnalysisContext _context;

  /// The [ClassElement] being used to create the current component,
  /// stored here instead of passing around everywhere.
  ClassElement _currentClassElement;

  PipeExtractor(this._unit, this._typeProvider, this._source, this._context) {
    initAnnotationProcessor(_source);
  }

  List<Pipe> getPipes() {
    final pipes = <Pipe>[];
    for (final unitMember in _unit.declarations) {
      if (unitMember is ast.ClassDeclaration) {
        for (final annotationNode in unitMember.metadata) {
          final pipe = _createPipe(unitMember, annotationNode);
          if (pipe != null) {
            pipes.add(pipe);
          }
        }
      }
    }
    return pipes;
  }

  /// Returns an Angular [Pipe] for the given [node].
  /// Returns `null` if not an Angular @Pipe annotation.
  Pipe _createPipe(ast.ClassDeclaration classDeclaration, ast.Annotation node) {
    _currentClassElement = classDeclaration.element;
    if (isAngularAnnotation(node, 'Pipe')) {
      String pipeName;
      ast.Expression pipeNameExpression;
      var isPure = true;
      ast.Expression isPureExpression;

      if (node.arguments != null && node.arguments.arguments.isNotEmpty) {
        final arguments = node.arguments.arguments;
        if (arguments.first is! ast.NamedExpression) {
          pipeNameExpression = arguments.first;
        }
        isPureExpression = getNamedArgument(node, 'pure');
      }
      if (pipeNameExpression != null) {
        final constantEvaluation =
            calculateStringWithOffsets(pipeNameExpression);
        if (constantEvaluation != null && constantEvaluation.value is String) {
          pipeName = constantEvaluation.value;
        }
      }
      if (isPureExpression != null) {
        final constantEvaluation = calculateStringWithOffsets(isPureExpression);
        if (constantEvaluation != null && constantEvaluation.value is bool) {
          isPure = constantEvaluation.value;
        }
      }
      if (pipeName == null) {
        errorReporter.reportErrorForNode(
            AngularWarningCode.PIPE_SINGLE_NAME_REQUIRED, node);
      }
      return new Pipe(pipeName, _currentClassElement, isPure);
    }
    return null;
  }
}
