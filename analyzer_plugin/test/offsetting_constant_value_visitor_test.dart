import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/src/dart/ast/utilities.dart' as utils;
import 'package:analyzer/src/dart/scanner/reader.dart';
import 'package:analyzer/src/dart/scanner/scanner.dart';
import 'package:analyzer/src/generated/parser.dart';
import 'package:angular_analyzer_plugin/src/tasks.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:unittest/unittest.dart';

main() {
  groupSep = ' | ';
  defineReflectiveTests(OffsettingConstantValueVisitorTest);
}

@reflectiveTest
class OffsettingConstantValueVisitorTest {
  void test_simpleString() {
    assertCaretOffsetIsPreserved("'my template^'");
    assertCaretOffsetIsPreserved("r'my template^'");
    assertCaretOffsetIsPreserved('"my template^"');
    assertCaretOffsetIsPreserved('r"my template^"');
    assertCaretOffsetIsPreserved("'''my template^'''");
    assertCaretOffsetIsPreserved("r'''my template^'''");
  }

  void test_parenthesizedString() {
    assertCaretOffsetIsPreserved("('my template^')");
    assertCaretOffsetIsPreserved("( 'my template^')");
    assertCaretOffsetIsPreserved("(  'my template^')");
    assertCaretOffsetIsPreserved("(\n'my template^')");
  }

  void test_adjacentStrings() {
    assertCaretOffsetIsPreserved("'my template^' 'which continues'");
    assertCaretOffsetIsPreserved("'my template' 'which continues ^'");
    assertCaretOffsetIsPreserved("r'my template'    r'which continues ^'");
    assertCaretOffsetIsPreserved("'my template'\n       'which continues ^'");
    assertCaretOffsetIsPreserved("'no gap''then continue ^'");
    assertCaretOffsetIsPreserved("'' 'after empty string ^'");
    assertCaretOffsetIsPreserved(
        "'my template'\n\n       'which continues' ' and continues ^'");
  }

  void test_concatenatedStrings() {
    assertCaretOffsetIsPreserved("'my template^' + 'which continues'");
    assertCaretOffsetIsPreserved("'my template' + 'which continues ^'");
    assertCaretOffsetIsPreserved("r'my template' +    r'which continues ^'");
    assertCaretOffsetIsPreserved("'my template' +\n       'which continues ^'");
    assertCaretOffsetIsPreserved("'no gap'+'then continue ^'");
    assertCaretOffsetIsPreserved("'' + 'after empty string ^'");
    assertCaretOffsetIsPreserved(
        "'my template' +\n\n       'which continues' + ' and continues ^'");
  }

  void test_concatenatedAfterParenthesis() {
    assertCaretOffsetIsPreserved("('my template^') + 'which continues'");
    assertCaretOffsetIsPreserved("('my template') + 'which continues^'");
    assertCaretOffsetIsPreserved("('my template'  ) + 'which continues^'");
    assertCaretOffsetIsPreserved("('my template'\n) + 'which continues^'");
  }

  void test_computedStringsLookRight() {
    Expression expression =
        _parseDartExpression("('my template'\n) + 'which continues^'");
    Object value = expression.accept(new OffsettingConstantEvaluator());
    expect(value, equals("  my template       which continues^ "));
  }

  void test_notStringComputation() {
    Expression expression = _parseDartExpression("1 + 2");
    Object value = expression.accept(new OffsettingConstantEvaluator());
    expect(value, equals(3));
  }

  void test_error() {
    Expression expression = _parseDartExpression("1 + 'hello'");
    Object value = expression.accept(new OffsettingConstantEvaluator());
    expect(value, equals(utils.ConstantEvaluator.NOT_A_CONSTANT));
  }

  void test_notOffsettableInterp() {
    assertNotOffsettable(r"'hello $world'", at: 'world');
  }

  void test_notOffsettableInterpExpr() {
    assertNotOffsettable(r"'hello ${world}'", at: 'world');
  }

  void test_notOffsettableGetter() {
    assertNotOffsettable(r"'hello' + world ", at: 'world');
  }

  void test_notOffsettableMethod() {
    assertNotOffsettable(r"'hello' + method() ", at: 'method()');
  }

  void test_notOffsettablePrefixedIdent() {
    assertNotOffsettable(r"'hello' + prefixed.identifier ",
        at: 'prefixed.identifier');
  }

  void assertNotOffsettable(String code, {String at}) {
    Expression expression = _parseDartExpression(code);
    int pos = code.indexOf(at);
    int length = at.length;
    expect(pos, greaterThan(-1),
        reason: "```$code```` doesn't contain ```$at```");

    OffsettingConstantEvaluator evaluator = new OffsettingConstantEvaluator();
    expression.accept(evaluator);
    expect(evaluator.offsetsAreValid, isFalse);
    expect(evaluator.lastUnoffsettableNode, isNotNull);
    expect(evaluator.lastUnoffsettableNode.offset, equals(pos),
        reason: "The snippet didn't match the suspect node");
    expect(evaluator.lastUnoffsettableNode.length, equals(length),
        reason: "The snippet didn't match the suspect node");
  }

  void assertCaretOffsetIsPreserved(String code) {
    int pos = code.indexOf('^');
    expect(pos, greaterThan(-1), reason: 'the code should contain a caret');

    Expression expression = _parseDartExpression(code);

    OffsettingConstantEvaluator evaluator = new OffsettingConstantEvaluator();
    Object value = expression.accept(evaluator);

    if (value is String) {
      expect(value.indexOf('^'), equals(pos),
          reason: "```$value``` moved the caret");
    } else {
      fail("Expected string, got $value");
    }
  }

  Token _scanDartCode(String code) {
    CharSequenceReader reader = new CharSequenceReader(code);
    Scanner scanner = new Scanner(null, reader, null);
    return scanner.tokenize();
  }

  Expression _parseDartExpression(String code) {
    Token token = _scanDartCode(code);
    Parser parser = new Parser(null, null);
    return parser.parseExpression(token);
  }
}
