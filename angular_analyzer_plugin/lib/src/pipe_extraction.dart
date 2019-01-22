import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/ast/utilities.dart' as utils;
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/errors.dart';
import 'package:angular_analyzer_plugin/src/model.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';
import 'package:angular_analyzer_plugin/src/tasks.dart';

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
            pipes.add(loadTransformInformation(pipe));
          }
        }
      }
    }
    return pipes;
  }

  /// Looks for a 'transform' function, and if found, finds all the
  /// important type information needed for resolution of pipe.
  Pipe loadTransformInformation(Pipe pipe) {
    final classElement = pipe.classElement;
    if (classElement == null) {
      return pipe;
    }

    final transformMethod =
        classElement.lookUpMethod('transform', classElement.library);
    if (transformMethod == null) {
      errorReporter.reportErrorForElement(
          AngularWarningCode.PIPE_REQUIRES_TRANSFORM_METHOD, classElement);
      return pipe;
    }

    pipe.transformReturnType = transformMethod.returnType;
    final parameters = transformMethod.parameters;
    if (parameters == null || parameters.isEmpty) {
      errorReporter.reportErrorForElement(
          AngularWarningCode.PIPE_TRANSFORM_REQ_ONE_ARG, transformMethod);
    }
    for (final parameter in parameters) {
      // If named or positional
      if (parameter.isNamed) {
        errorReporter.reportErrorForElement(
            AngularWarningCode.PIPE_TRANSFORM_NO_NAMED_ARGS, parameter);
        continue;
      }
      if (parameters.first == parameter) {
        pipe.requiredArgumentType = parameter.type;
      } else {
        pipe.optionalArgumentTypes.add(parameter.type);
      }
    }
    return pipe;
  }

  /// Returns an Angular [Pipe] for the given [node].
  /// Returns `null` if not an Angular @Pipe annotation.
  Pipe _createPipe(ast.ClassDeclaration classDeclaration, ast.Annotation node) {
    _currentClassElement = classDeclaration.declaredElement;
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
            isPureExpression.accept(new utils.ConstantEvaluator());
        if (isPureValue != null && isPureValue is bool) {
          isPure = isPureValue;
        }
      }
      if (pipeName == null) {
        errorReporter.reportErrorForNode(
            AngularWarningCode.PIPE_SINGLE_NAME_REQUIRED, node);
      }

      // Check if 'extends PipeTransform' exists.
      var allSupertypes = _currentClassElement.allSupertypes ?? [];
      allSupertypes = allSupertypes
          .where((t) => _standardAngular.pipeTransform.type.isSupertypeOf(t))
          .toList();
      if (allSupertypes.isEmpty) {
        errorReporter.reportErrorForNode(
            AngularWarningCode.PIPE_REQUIRES_PIPETRANSFORM, node);
      }

      // Check if abstract
      if (_currentClassElement.isAbstract) {
        errorReporter.reportErrorForNode(
            AngularWarningCode.PIPE_CANNOT_BE_ABSTRACT, node);
      }

      return new Pipe(pipeName, pipeNameOffset, _currentClassElement,
          isPure: isPure);
    }
    return null;
  }
}
