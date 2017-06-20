import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/standard_ast_factory.dart';
import 'package:front_end/src/scanner/token.dart';

class NgExprParser extends Parser {
  NgExprParser(Source source, AnalysisErrorListener errorListener)
      : super(source, errorListener);

  Token get _currentToken => super.currentToken;

  /// Parse a bitwise or expression to be treated as a pipe.
  /// Return the resolved left-hand expression as a dynamic type.
  ///
  ///     bitwiseOrExpression ::=
  ///         bitwiseXorExpression ('|' pipeExpression)*
  @override
  Expression parseBitwiseOrExpression() {
    Expression expression;
    Token beforePipeToken;
    expression = parseBitwiseXorExpression();
    while (_currentToken.type == TokenType.BAR) {
      beforePipeToken ??= _currentToken.previous;
      getAndAdvance();
      parsePipeExpression();
    }
    if (beforePipeToken != null) {
      final asToken = new KeywordToken(Keyword.AS, 0);
      final dynamicIdToken =
          new StringToken(TokenType.IDENTIFIER, "dynamic", 0);

      beforePipeToken.setNext(asToken);
      asToken.setNext(dynamicIdToken);
      dynamicIdToken.setNext(_currentToken);

      final dynamicIdentifier = astFactory.simpleIdentifier(dynamicIdToken);

      expression = astFactory.asExpression(
          expression, asToken, astFactory.typeName(dynamicIdentifier, null));
    }
    return expression;
  }

  /// Parse a bitwise or expression to be treated as a pipe.
  /// Return the resolved left-hand expression as a dynamic type.
  ///
  ///     pipeExpression ::= identifier[':' expression]*
  void parsePipeExpression() {
    parseIdentifierList();
    while (_currentToken.type == TokenType.COLON) {
      getAndAdvance();
      parseExpression2();
    }
  }
}
