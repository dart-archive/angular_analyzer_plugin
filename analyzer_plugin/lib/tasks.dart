library angular2.src.analysis.analyzer_plugin.tasks;

import 'package:analyzer/error/error.dart';

/**
 * The error codes used for Angular warnings. The convention for this
 * class is for the name of the error code to indicate the problem that caused
 * the error to be generated and for the error message to explain what is wrong
 * and, when appropriate, how the problem can be corrected.
 */
class AngularWarningCode extends ErrorCode {
  /**
   * An error code indicating that the annotation does not define the
   * required "selector" argument.
   */
  static const AngularWarningCode ARGUMENT_SELECTOR_MISSING =
      const AngularWarningCode(
          'ARGUMENT_SELECTOR_MISSING', 'Argument "selector" missing');

  /**
   * An error code indicating that the provided selector cannot be parsed.
   */
  static const AngularWarningCode CANNOT_PARSE_SELECTOR =
      const AngularWarningCode(
          'CANNOT_PARSE_SELECTOR', 'Cannot parse the given selector');

  /**
   * An error code indicating that a template points to a missing html file
   */
  static const AngularWarningCode REFERENCED_HTML_FILE_DOESNT_EXIST =
      const AngularWarningCode('REFERENCED_HTML_FILE_DOESNT_EXIST',
          'The referenced HTML file doesn\'t exist');

  /**
   * An error code indicating that the component has @View annotation,
   * but not @Component annotation.
   */
  static const AngularWarningCode COMPONENT_ANNOTATION_MISSING =
      const AngularWarningCode('COMPONENT_ANNOTATION_MISSING',
          'Every @View requires exactly one @Component annotation');

  /**
   * An error code indicating that a @View or @Component has both a
   * template and a templateUrl defined at once (illegal)
   */
  static const AngularWarningCode TEMPLATE_URL_AND_TEMPLATE_DEFINED =
      const AngularWarningCode('TEMPLATE_URL_AND_TEMPLATE_DEFINED',
          'Cannot define both template and templateUrl. Remove one');

  /**
   * An error code indicating that a @View or @Component does not have
   * a template or a templateUrl
   */
  static const AngularWarningCode NO_TEMPLATE_URL_OR_TEMPLATE_DEFINED =
      const AngularWarningCode('NO_TEMPLATE_URL_OR_TEMPLATE_DEFINED',
          'Either a template or templateUrl is required');

  /**
   * An error code indicating that the value of an expression is not a string.
   */
  static const AngularWarningCode DIRECTIVE_TYPE_LITERAL_EXPECTED =
      const AngularWarningCode('DIRECTIVE_TYPE_LITERAL_EXPECTED',
          'A directive type literal expected');

  /**
   * An error code indicating that an identifier was expected, but not found.
   */
  static const AngularWarningCode EXPECTED_IDENTIFIER =
      const AngularWarningCode('EXPECTED_IDENTIFIER', 'Expected identifier');

  /**
   * An error code indicating that the value of an expression is not a string.
   */
  static const AngularWarningCode STRING_VALUE_EXPECTED =
      const AngularWarningCode(
          'STRING_VALUE_EXPECTED', 'A string value expected');

  /**
   * An error code indicating that the value of an expression is not a string.
   */
  static const AngularWarningCode TYPE_LITERAL_EXPECTED =
      const AngularWarningCode(
          'TYPE_LITERAL_EXPECTED', 'A type literal expected');

  /**
   * An error code indicating that the tag was not resolved.
   */
  static const AngularWarningCode UNRESOLVED_TAG =
      const AngularWarningCode('UNRESOLVED_TAG', 'Unresolved tag "{0}"');

  /**
   * An error code indicating that the embedded expression is not terminated.
   */
  static const AngularWarningCode UNTERMINATED_MUSTACHE =
      const AngularWarningCode(
          'UNTERMINATED_MUSTACHE', 'Unterminated mustache');

  /**
   * An error code indicating that a mustache ending was found unopened
   */
  static const AngularWarningCode UNOPENED_MUSTACHE = const AngularWarningCode(
      'UNOPENED_MUSTACHE', 'Mustache terminator with no opening');

  /**
   * An error code indicating that a nonexist input was bound
   */
  static const AngularWarningCode NONEXIST_INPUT_BOUND =
      const AngularWarningCode('NONEXIST_INPUT_BOUND',
          'The bound input does not exist on any directives');

  /**
   * An error code indicating that a nonexist output was bound
   */
  static const AngularWarningCode NONEXIST_OUTPUT_BOUND =
      const AngularWarningCode('NONEXIST_OUTPUT_BOUND',
          'The bound output does not exist on any directives');

  /**
   * An error code indicating that a nonexist input was bound
   */
  static const AngularWarningCode INPUT_BINDING_TYPE_ERROR =
      const AngularWarningCode(
          'INPUT_BINDING_TYPE_ERROR',
          'Attribute value expression (of type {0}) ' +
              'is not assignable to component input (of type {1})');

  static const AngularWarningCode TRAILING_EXPRESSION =
    const AngularWarningCode(
          'TRAILING_EXPRESSION',
          'Expressions must end with an EOF');


  /**
   * Initialize a newly created error code to have the given [name].
   * The message associated with the error will be created from the given
   * [message] template. The correction associated with the error will be
   * created from the given [correction] template.
   */
  const AngularWarningCode(String name, String message, [String correction])
      : super(name, message, correction);

  @override
  ErrorSeverity get errorSeverity => ErrorSeverity.WARNING;

  @override
  ErrorType get type => ErrorType.STATIC_WARNING;
}
