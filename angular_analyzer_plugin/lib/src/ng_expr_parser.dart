import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/standard_ast_factory.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/dart/ast/token.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/tuple.dart';

class NgExprParser extends Parser {
  NgExprParser(Source source, AnalysisErrorListener errorListener)
      : super.withoutFasta(source, errorListener);

  Token get _currentToken => super.currentToken;

  /// Override the bitwise or operator to parse pipes instead
  @override
  Expression parseBitwiseOrExpression() => parsePipeExpression();

  /// Parse pipe expression. Return the result as a cast expression `as dynamic`
  /// with _ng_pipeXXX properties to be resolved specially later.
  ///
  ///     bitwiseOrExpression ::=
  ///         bitwiseXorExpression ('|' pipeName [: arg]*)*
  Expression parsePipeExpression() {
    Expression expression;
    Token beforePipeToken;
    expression = parseBitwiseXorExpression();
    while (_currentToken.type == TokenType.BAR) {
      beforePipeToken ??= _currentToken.previous;
      getAndAdvance();
      final pipeEntities = parsePipeExpressionEntities();
      final asToken = new KeywordToken(Keyword.AS, 0);
      final dynamicIdToken = new SyntheticStringToken(TokenType.IDENTIFIER,
          "dynamic", _currentToken.offset - "dynamic".length);

      beforePipeToken.setNext(asToken);
      asToken.setNext(dynamicIdToken);
      dynamicIdToken.setNext(_currentToken);

      final dynamicIdentifier = astFactory.simpleIdentifier(dynamicIdToken);

      // TODO(mfairhurst) Now that we are resolving pipes, probably should store
      // the result in a different expression type -- a function call, most
      // likely. This will be required so that the pipeArgs become part of the
      // tree, but it may create secondary fallout inside the analyzer
      // resolution code if done wrong.
      expression = astFactory.asExpression(
          expression, asToken, astFactory.typeName(dynamicIdentifier, null))
        ..setProperty('_ng_pipeName', pipeEntities.name)
        ..setProperty('_ng_pipeArgs', pipeEntities.arguments);
    }
    return expression;
  }

  /// Parse a bitwise or expression to be treated as a pipe.
  /// Return the resolved left-hand expression as a dynamic type.
  ///
  ///     pipeExpression ::= identifier[':' expression]*
  _PipeEntities parsePipeExpressionEntities() {
    final identifier = parseSimpleIdentifier();
    final expressions = <Expression>[];
    while (_currentToken.type == TokenType.COLON) {
      getAndAdvance();
      expressions.add(parseExpression2());
    }

    return _PipeEntities(identifier, expressions);
  }
}

class _PipeEntities {
  final SimpleIdentifier name;
  final List<Expression> arguments;

  _PipeEntities(this.name, this.arguments);
}
