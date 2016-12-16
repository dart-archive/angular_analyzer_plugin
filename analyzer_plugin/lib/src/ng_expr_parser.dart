library angular2.src.analysis.analyzer_plugin.src.ng_expr_parser.dart;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/dart/ast/standard_ast_factory.dart';

class NgExprParser extends Parser {
  NgExprParser(
      Source source, AnalysisErrorListener errorListener, this.typeProvider)
      : super(source, errorListener);

  Token get _currentToken => super.currentToken;

  final TypeProvider typeProvider;

  @override

  /**
   * Parse a bitwise or expression to be treated as a pipe.
   * Return the resolved left-hand expression as a dynamic type.
   *
   *     bitwiseOrExpression ::=
   *         bitwiseXorExpression ('|' pipeExpression)*
   */
  @override
  Expression parseBitwiseOrExpression() {
    Expression expression;
    expression = parseBitwiseXorExpression();
    while (_currentToken.type == TokenType.BAR) {
      getAndAdvance();
      parsePipeExpression();
    }
    expression.propagatedType = typeProvider.dynamicType;
    return expression;
  }

  /**
   * Parse a bitwise or expression to be treated as a pipe.
   * Return the resolved left-hand expression as a dynamic type.
   *
   *     pipeExpression ::= assignableExpression[:param]*
   */
  Expression parsePipeExpression() {
    parseAssignableExpression(true);
    while (_currentToken.type == TokenType.COLON) {
      getAndAdvance();
      parseArgument();
    }
    return null;
  }
}
