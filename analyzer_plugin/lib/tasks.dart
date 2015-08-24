library angular2.src.analysis.analyzer_plugin.tasks;

import 'package:analyzer/src/generated/error.dart';
import 'package:analyzer/task/model.dart';

/// The analysis errors associated with a target.
/// The value combines errors represented by multiple other results.
final ListResultDescriptor<AnalysisError> HTML_ERRORS =
    new ListResultDescriptor<AnalysisError>(
        'ANGULAR_HTML_ERRORS', AnalysisError.NO_ERRORS);

/// The error codes used for Angular warnings. The convention for this
/// class is for the name of the error code to indicate the problem that caused
/// the error to be generated and for the error message to explain what is wrong
/// and, when appropriate, how the problem can be corrected.
class AngularWarningCode extends ErrorCode {
  /// An error code indicating that the annotation does not define the
  /// required "selector" argument.
  static const AngularWarningCode ARGUMENT_SELECTOR_MISSING =
      const AngularWarningCode(
          'ARGUMENT_SELECTOR_MISSING', 'Argument "selector" missing');

  /// An error code indicating that the provided selector cannot be parsed.
  static const AngularWarningCode CANNOT_PARSE_SELECTOR =
      const AngularWarningCode(
          'CANNOT_PARSE_SELECTOR', 'Cannot parse the given selector');

  /// An error code indicating that the component has @View annotation,
  /// but not @Component annotation.
  static const AngularWarningCode COMPONENT_ANNOTATION_MISSING =
      const AngularWarningCode('COMPONENT_ANNOTATION_MISSING',
          'Every @View requires exactly one @Component annotation');

  /// An error code indicating that the value of an expression is not a string.
  static const AngularWarningCode DIRECTIVE_TYPE_LITERAL_EXPECTED =
      const AngularWarningCode('DIRECTIVE_TYPE_LITERAL_EXPECTED',
          'A directive type literal expected');

  /// An error code indicating that the value of an expression is not a string.
  static const AngularWarningCode STRING_VALUE_EXPECTED =
      const AngularWarningCode(
          'STRING_VALUE_EXPECTED', 'A string value expected');

  /// An error code indicating that the value of an expression is not a string.
  static const AngularWarningCode TYPE_LITERAL_EXPECTED =
      const AngularWarningCode(
          'TYPE_LITERAL_EXPECTED', 'A type literal expected');

  /// An error code indicating that the tag was not resolved.
  static const AngularWarningCode UNRESOLVED_TAG =
      const AngularWarningCode('UNRESOLVED_TAG', 'Unresolved tag "{0}"');

  /// Initialize a newly created error code to have the given [name].
  /// The message associated with the error will be created from the given
  /// [message] template. The correction associated with the error will be
  /// created from the given [correction] template.
  const AngularWarningCode(String name, String message, [String correction])
      : super(name, message, correction);

  @override
  ErrorSeverity get errorSeverity => ErrorSeverity.WARNING;

  @override
  ErrorType get type => ErrorType.STATIC_WARNING;
}
