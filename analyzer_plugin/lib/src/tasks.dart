library angular2.src.analysis.analyzer_plugin.src.tasks;

import 'package:analyzer/dart/ast/ast.dart' as ast;
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/ast/utilities.dart' as utils;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/tasks.dart';

class OffsettingConstantEvaluator extends utils.ConstantEvaluator {
  bool offsetsAreValid = true;
  Object value;
  ast.AstNode lastUnoffsettableNode;

  @override
  Object visitAdjacentStrings(ast.AdjacentStrings node) {
    StringBuffer buffer = new StringBuffer();
    int lastEndingOffset = null;
    for (ast.StringLiteral string in node.strings) {
      Object value = string.accept(this);
      if (identical(value, utils.ConstantEvaluator.NOT_A_CONSTANT)) {
        return value;
      }
      // preserve offsets across the split by padding
      if (lastEndingOffset != null) {
        buffer.write(' ' * (string.offset - lastEndingOffset));
      }
      lastEndingOffset = string.offset + string.length;
      buffer.write(value);
    }
    return buffer.toString();
  }

  @override
  Object visitBinaryExpression(ast.BinaryExpression node) {
    if (node.operator.type == TokenType.PLUS) {
      Object leftOperand = node.leftOperand.accept(this);
      if (identical(leftOperand, utils.ConstantEvaluator.NOT_A_CONSTANT)) {
        return leftOperand;
      }
      Object rightOperand = node.rightOperand.accept(this);
      if (identical(rightOperand, utils.ConstantEvaluator.NOT_A_CONSTANT)) {
        return rightOperand;
      }
      // numeric or {@code null}
      if (leftOperand is String && rightOperand is String) {
        int gap = node.rightOperand.offset -
            node.leftOperand.offset -
            node.leftOperand.length;
        return leftOperand + (' ' * gap) + rightOperand;
      }
    }

    return super.visitBinaryExpression(node);
  }

  @override
  Object visitStringInterpolation(ast.StringInterpolation node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    return super.visitStringInterpolation(node);
  }

  @override
  Object visitMethodInvocation(ast.MethodInvocation node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    return super.visitMethodInvocation(node);
  }

  @override
  Object visitParenthesizedExpression(ast.ParenthesizedExpression node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    int preGap = node.expression.offset - node.offset;
    int postGap = node.offset +
        node.length -
        node.expression.offset -
        node.expression.length;
    Object value = super.visitParenthesizedExpression(node);
    if (value is String) {
      return ' ' * preGap + value + ' ' * postGap;
    }

    return value;
  }

  @override
  Object visitSimpleStringLiteral(ast.SimpleStringLiteral node) {
    int gap = node.contentsOffset - node.offset;
    lastUnoffsettableNode = node;
    return ' ' * gap + node.value + ' ';
  }

  @override
  Object visitPrefixedIdentifier(ast.PrefixedIdentifier node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    return super.visitPrefixedIdentifier(node);
  }

  @override
  Object visitPropertyAccess(ast.PropertyAccess node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    return super.visitPropertyAccess(node);
  }

  @override
  Object visitSimpleIdentifier(ast.SimpleIdentifier node) {
    offsetsAreValid = false;
    lastUnoffsettableNode = node;
    return super.visitSimpleIdentifier(node);
  }
}

/**
 * Helper for processing Angular annotations.
 */
class AnnotationProcessorMixin {
  RecordingErrorListener errorListener = new RecordingErrorListener();
  ErrorReporter errorReporter;

  /**
   * The evaluator of constant values, such as annotation arguments.
   */
  final utils.ConstantEvaluator _constantEvaluator =
      new utils.ConstantEvaluator();

  /**
   * Initialize the processor working in the given [target].
   */
  void initAnnotationProcessor(Source source) {
    assert(errorReporter == null);
    errorReporter = new ErrorReporter(errorListener, source);
  }

  /**
   * Returns the [String] value of the given [expression].
   * If [expression] does not have a [String] value, reports an error
   * and returns `null`.
   */
  String getExpressionString(ast.Expression expression) {
    if (expression != null) {
      Object value = expression.accept(_constantEvaluator);
      if (value is String) {
        return value;
      }
      errorReporter.reportErrorForNode(
          AngularWarningCode.STRING_VALUE_EXPECTED, expression);
    }
    return null;
  }

  /**
   * Returns the [String] value of the given [expression].
   * If [expression] does not have a [String] value, reports an error
   * and returns `null`.
   */
  OffsettingConstantEvaluator calculateStringWithOffsets(
      ast.Expression expression) {
    if (expression != null) {
      OffsettingConstantEvaluator evaluator = new OffsettingConstantEvaluator();
      evaluator.value = expression.accept(evaluator);

      if (evaluator.value is String) {
        if (!evaluator.offsetsAreValid) {
          errorReporter.reportErrorForNode(
              AngularWarningCode.OFFSETS_CANNOT_BE_CREATED,
              evaluator.lastUnoffsettableNode);
        }
        return evaluator;
      }
      errorReporter.reportErrorForNode(
          AngularWarningCode.STRING_VALUE_EXPECTED, expression);
    }
    return null;
  }

  /**
   * Returns the value of the argument with the given [name].
   * Returns `null` if not found.
   */
  ast.Expression getNamedArgument(ast.Annotation node, String name) {
    if (node.arguments != null) {
      List<ast.Expression> arguments = node.arguments.arguments;
      for (ast.Expression argument in arguments) {
        if (argument is ast.NamedExpression &&
            argument.name != null &&
            argument.name.label != null &&
            argument.name.label.name == name) {
          return argument.expression;
        }
      }
    }
    return null;
  }

  /**
   * Returns `true` is the given [node] is resolved to a creation of an Angular
   * annotation class with the given [name].
   */
  bool isAngularAnnotation(ast.Annotation node, String name) {
    if (node.element is ConstructorElement) {
      ClassElement clazz = node.element.enclosingElement;
      return clazz.library.source.uri.path
              .endsWith('angular2/src/core/metadata.dart') &&
          clazz.name == name;
    }
    return false;
  }
}