import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';
import 'package:angular_analyzer_plugin/tasks.dart';
import 'tasks.dart';

class PipeExtractor extends AnnotationProcessorMixin {
  final ast.CompilationUnit _unit;
  final Source _source;
  final StandardAngular _standardAngular;

  /// The [ClassElement] being used to create the current component,
  /// stored here instead of passing around everywhere.
  ClassElement _currentClassElement;

  PipeExtractor(this._unit, this._source, this._standardAngular) {
    initAnnotationProcessor(_source);
  }

  List<Pipe> getPipes() {
    final pipes = <Pipe>[];
    for (final unitMember in _unit.declarations) {
      if (unitMember is ast.ClassDeclaration) {
        for (final annotationNode in unitMember.metadata) {
          final pipe = _createPipe(unitMember, annotationNode);
          if (pipe != null) {
            pipe.loadTransformValue(errorReporter);
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
      int pipeNameOffset;
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
          pipeName = (constantEvaluation.value as String).trim();
          pipeNameOffset = pipeNameExpression.offset;
        }
      }
      if (isPureExpression != null) {
        final isPureValue =
            isPureExpression.accept(new OffsettingConstantEvaluator());
        if (isPureValue != null && isPureValue is bool) {
          isPure = isPureValue;
        }
      }
      if (pipeName == null) {
        errorReporter.reportErrorForNode(
            AngularWarningCode.PIPE_SINGLE_NAME_REQUIRED, node);
      }

      // Check if 'extends PipeTransform' exists.
      final superType = _currentClassElement.supertype;
      if (superType == null ||
          superType != _standardAngular.pipeTransform.type) {
        errorReporter.reportErrorForNode(
            AngularWarningCode.PIPE_REQUIRES_PIPETRANSFORM, node);
      }

      return new Pipe(pipeName, pipeNameOffset, _currentClassElement,
          isPure: isPure);
    }
    return null;
  }
}
