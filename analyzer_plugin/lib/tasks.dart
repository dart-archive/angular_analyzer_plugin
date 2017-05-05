library angular2.src.analysis.analyzer_plugin.tasks;

import 'dart:collection';
import 'package:analyzer/error/error.dart';

// used by angularWarningCodeByUniqueName to create a map for fast lookup
const List<AngularWarningCode> _angularWarningCodeValues = const [
  AngularWarningCode.ARGUMENT_SELECTOR_MISSING,
  AngularWarningCode.CANNOT_PARSE_SELECTOR,
  AngularWarningCode.REFERENCED_HTML_FILE_DOESNT_EXIST,
  AngularWarningCode.COMPONENT_ANNOTATION_MISSING,
  AngularWarningCode.TEMPLATE_URL_AND_TEMPLATE_DEFINED,
  AngularWarningCode.NO_TEMPLATE_URL_OR_TEMPLATE_DEFINED,
  AngularWarningCode.EXPECTED_IDENTIFIER,
  AngularWarningCode.UNEXPECTED_HASH_IN_TEMPLATE,
  AngularWarningCode.STRING_VALUE_EXPECTED,
  AngularWarningCode.TYPE_LITERAL_EXPECTED,
  AngularWarningCode.TYPE_IS_NOT_A_DIRECTIVE,
  AngularWarningCode.UNRESOLVED_TAG,
  AngularWarningCode.UNTERMINATED_MUSTACHE,
  AngularWarningCode.UNOPENED_MUSTACHE,
  AngularWarningCode.NONEXIST_INPUT_BOUND,
  AngularWarningCode.NONEXIST_OUTPUT_BOUND,
  AngularWarningCode.EMPTY_BINDING,
  AngularWarningCode.NONEXIST_TWO_WAY_OUTPUT_BOUND,
  AngularWarningCode.TWO_WAY_BINDING_OUTPUT_TYPE_ERROR,
  AngularWarningCode.INPUT_BINDING_TYPE_ERROR,
  AngularWarningCode.TRAILING_EXPRESSION,
  AngularWarningCode.OUTPUT_MUST_BE_STREAM,
  AngularWarningCode.TWO_WAY_BINDING_NOT_ASSIGNABLE,
  AngularWarningCode.INPUT_ANNOTATION_PLACEMENT_INVALID,
  AngularWarningCode.OUTPUT_ANNOTATION_PLACEMENT_INVALID,
  AngularWarningCode.INVALID_HTML_CLASSNAME,
  AngularWarningCode.CLASS_BINDING_NOT_BOOLEAN,
  AngularWarningCode.CSS_UNIT_BINDING_NOT_NUMBER,
  AngularWarningCode.INVALID_CSS_UNIT_NAME,
  AngularWarningCode.INVALID_CSS_PROPERTY_NAME,
  AngularWarningCode.INVALID_BINDING_NAME,
  AngularWarningCode.STRUCTURAL_DIRECTIVES_REQUIRE_TEMPLATE,
  AngularWarningCode.NO_DIRECTIVE_EXPORTED_BY_SPECIFIED_NAME,
  AngularWarningCode.OFFSETS_CANNOT_BE_CREATED,
  AngularWarningCode.CONTENT_NOT_TRANSCLUDED,
  AngularWarningCode.NG_CONTENT_MUST_BE_EMPTY,
  AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
  AngularWarningCode.DISALLOWED_EXPRESSION,
  AngularWarningCode.ATTRIBUTE_PARAMETER_MUST_BE_STRING,
  AngularWarningCode.STRING_STYLE_INPUT_BINDING_INVALID,
  AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
  AngularWarningCode.UNKNOWN_CHILD_QUERY_TYPE,
  AngularWarningCode.CONTENT_OR_VIEW_CHILDREN_REQUIRES_QUERY_LIST,
  AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE
];

/**
 * The lazy initialized map from [AngularWarningCode.uniqueName] to the
 * [AngularWarningCode] instance.
 */
HashMap<String, AngularWarningCode> _uniqueNameToCodeMap;

/**
 * Return the [AngularWarningCode] with the given [uniqueName], or `null` if not
 * found.
 */
AngularWarningCode angularWarningCodeByUniqueName(String uniqueName) {
  if (_uniqueNameToCodeMap == null) {
    _uniqueNameToCodeMap = new HashMap<String, AngularWarningCode>();
    for (AngularWarningCode angularCode in _angularWarningCodeValues) {
      _uniqueNameToCodeMap[angularCode.uniqueName] = angularCode;
    }
  }
  return _uniqueNameToCodeMap[uniqueName];
}

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
          'CANNOT_PARSE_SELECTOR', 'Cannot parse the given selector ({0})');

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
   * An error code indicating that an identifier was expected, but not found.
   */
  static const AngularWarningCode EXPECTED_IDENTIFIER =
      const AngularWarningCode('EXPECTED_IDENTIFIER', 'Expected identifier');

  /**
   * An error code indicating that an hash was unexpected in template.
   */
  static const AngularWarningCode UNEXPECTED_HASH_IN_TEMPLATE =
      const AngularWarningCode(
          'UNEXPECTED_HASH_IN_TEMPLATE', "Did you mean 'let' instead?");

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
   * An error code indicating that the value of an expression is not a string.
   */
  static const AngularWarningCode TYPE_IS_NOT_A_DIRECTIVE =
      const AngularWarningCode(
          'TYPE_IS_NOT_A_DIRECTIVE',
          'The type "{0}" is included in the directives list, but is not a' +
              ' directive');

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
      const AngularWarningCode(
          'NONEXIST_INPUT_BOUND',
          'The bound input {0} does not exist on any directives or ' +
              'on the element');

  /**
   * An error code indicating that a nonexist output was bound
   */
  static const AngularWarningCode NONEXIST_OUTPUT_BOUND =
      const AngularWarningCode(
          'NONEXIST_OUTPUT_BOUND',
          'The bound output {0} does not exist on any directives or ' +
              'on the element');

  /**
   * An error code indicating that a nonexist output was bound
   */
  static const AngularWarningCode EMPTY_BINDING = const AngularWarningCode(
      'EMPTY_BINDING', 'The binding {0} does not have a value specified');

  /**
   * An error code indicating that a nonexist output was bound, perhaps
   * because an input was two way bound. The nonexist bound output is
   * an implementation detail, so give its own error.
   */
  static const AngularWarningCode NONEXIST_TWO_WAY_OUTPUT_BOUND =
      const AngularWarningCode('NONEXIST_TWO_WAY_OUTPUT_BOUND',
          'The two-way binding {0} requires a bindable output of name {1}');

  /**
   * An error code indicating that the output event in a two-way binding
   * doesn't match the input
   */
  static const AngularWarningCode TWO_WAY_BINDING_OUTPUT_TYPE_ERROR =
      const AngularWarningCode(
          'TWO_WAY_BINDING_OUTPUT_TYPE_ERROR',
          'Output event in two-way binding (of type {0}) ' +
              'is not assignable to component input (of type {1})');

  /**
   * An error code indicating that an input was bound with a incorrectly
   * typed expression
   */
  static const AngularWarningCode INPUT_BINDING_TYPE_ERROR =
      const AngularWarningCode(
          'INPUT_BINDING_TYPE_ERROR',
          'Attribute value expression (of type {0}) ' +
              'is not assignable to component input (of type {1})');

  /**
   * An error code indicating that an expression did not correctly
   * end with an EOF token.
   */
  static const AngularWarningCode TRAILING_EXPRESSION =
      const AngularWarningCode(
          'TRAILING_EXPRESSION', 'Expressions must end with an EOF');

  /**
   * An error code indicating that an @Output is not an EventEmitter
   */
  static const AngularWarningCode OUTPUT_MUST_BE_STREAM =
      const AngularWarningCode(
          'OUTPUT_MUST_BE_STREAM', 'Output (of name {0}) must return a Stream');

  /**
   * An error code indicating that a two-way binding expression was not
   * a assignable (and therefore could only be one-way bound...)
   */
  static const AngularWarningCode TWO_WAY_BINDING_NOT_ASSIGNABLE =
      const AngularWarningCode('TWO_WAY_BINDING_NOT_ASSIGNABLE',
          'Only assignable expressions can be two-way bound');

  /**
   * An error code indicating that an @Input annottaion was used in the wrong
   * place
   */
  static const AngularWarningCode INPUT_ANNOTATION_PLACEMENT_INVALID =
      const AngularWarningCode('INPUT_ANNOTATION_PLACEMENT_INVALID',
          'The @Input() annotation can only be put on properties and setters');

  /**
   * An error code indicating that an @Output annottaion was used in the wrong
   * place
   */
  static const AngularWarningCode OUTPUT_ANNOTATION_PLACEMENT_INVALID =
      const AngularWarningCode('OUTPUT_ANNOTATION_PLACEMENT_INVALID',
          'The @Output() annotation can only be put on properties and getters');

  /**
   * An error code indicating that a html classname was bound via
   * [class.classname]="x" where classname is not a css identifier
   * https://www.w3.org/TR/CSS21/syndata.html#value-def-identifier
   */
  static const AngularWarningCode INVALID_HTML_CLASSNAME =
      const AngularWarningCode('INVALID_HTML_CLASSNAME',
          'The html classname {0} is not a valid classname');

  /**
   * An error code indicating that a html classname was bound via
   * [class.classname]="x" where x was not a boolean
   */
  static const AngularWarningCode CLASS_BINDING_NOT_BOOLEAN =
      const AngularWarningCode('CLASS_BINDING_NOT_BOOLEAN',
          'Binding to a classname requires a boolean');

  /**
   * An error code indicating that a css property with a unit was bound via
   * [style.property.unit]="x" where x was not a number
   */
  static const AngularWarningCode CSS_UNIT_BINDING_NOT_NUMBER =
      const AngularWarningCode('CSS_UNIT_BINDING_NOT_NUMBER',
          'Binding to a css property with a unit requires a number');

  /**
   * An error code indicating that a css property with a unit was bound via
   * [style.property.unit]="x" where unit was not an identifier
   * https://www.w3.org/TR/CSS21/syndata.html#value-def-identifier
   */
  static const AngularWarningCode INVALID_CSS_UNIT_NAME =
      const AngularWarningCode('INVALID_CSS_UNIT_NAME',
          'The css unit {0} is not a valid css identifier');

  /**
   * An error code indicating that a css property bound via
   * [style.property]="x" or [style.property.unit]="x" where property was not an
   * identifier
   * https://www.w3.org/TR/CSS21/syndata.html#value-def-identifier
   */
  static const AngularWarningCode INVALID_CSS_PROPERTY_NAME =
      const AngularWarningCode('INVALID_CSS_PROPERTY_NAME',
          'The css property {0} is not a valid css identifier');

  /**
   * An error code indicating that a binding was not a * dart identifier, or
   * [class.classname], or [attr.attrname], or [style.property], or
   * [style.property.unit].
   */
  static const AngularWarningCode INVALID_BINDING_NAME =
      const AngularWarningCode(
          'INVALID_BINDING_NAME',
          'The binding {} is not a valid dart identifer, attribute, style, ' +
              'or class binding');

  /**
   * An error code indicating that ngIf or ngFor were used without a template
   */
  static const AngularWarningCode STRUCTURAL_DIRECTIVES_REQUIRE_TEMPLATE =
      const AngularWarningCode(
          'STRUCTURAL_DIRECTIVES_REQUIRE_TEMPLATE',
          'Structural directive {0} requires a template. Did you mean ' +
              '*{0}="..." or template="{0} ..." or <template {0} ...>?');

  /**
   * An error code indicating in #y="x", x was not an exported name
   */
  static const AngularWarningCode NO_DIRECTIVE_EXPORTED_BY_SPECIFIED_NAME =
      const AngularWarningCode('NO_DIRECTIVE_EXPORTED_BY_SPECIFIED_NAME',
          'No directives matching this element are exported by the name {0}');

  /**
   * An error code indicating that an output-bound statement
   * must be an [ExpressionStatement].
   */
  static const AngularWarningCode
      OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT = const AngularWarningCode(
          'OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT',
          "Syntax Error: unexpected {0}");

  /**
   * An error code indicating that a mustache or other expression binding was an
   * unsupported type such as an 'as' expression or a constructor
   */
  static const AngularWarningCode DISALLOWED_EXPRESSION =
      const AngularWarningCode(
          'DISALLOWED_EXPRESSION', "{0} not allowed in angular templates");

  /**
   * An error code indicating that an output-bound statement
   * must be an [ExpressionStatement].
   */
  static const AngularWarningCode OFFSETS_CANNOT_BE_CREATED =
      const AngularWarningCode(
          'OFFSETS_CANNOT_BE_CREATED',
          "Errors cannot be tracked for the constant expression because it is" +
              " too complex for errors to be mapped to locations in the file");

  /**
   * An error code indicating that dom inside a component won't be transcluded
   */
  static const AngularWarningCode CONTENT_NOT_TRANSCLUDED =
      const AngularWarningCode(
          'CONTENT_NOT_TRANSCLUDED',
          "The content does not match any transclusion selectors of the" +
              " surrounding component");

  /**
   * An error code indicating that an <ng-content> tag had content, which is not
   * allowed.
   */
  static const AngularWarningCode NG_CONTENT_MUST_BE_EMPTY =
      const AngularWarningCode(
          'NG_CONTENT_MUST_BE_EMPTY',
          "Nothing is allowed inside an <ng-content> tag, as it will be" +
              " replaced");

  /**
   * An error code indicating that a constructor parameter was marked with
   * @Attribute, but the argument wasn't of type string.
   */
  static const AngularWarningCode ATTRIBUTE_PARAMETER_MUST_BE_STRING =
      const AngularWarningCode('ATTRIBUTE_PARAMETER_MUST_BE_STRING',
          "Parameters marked with @Attribute must be of type String");

  /**
   * An error code indicating that an input binding was used in string form, ie,
   * `x="y"` rather than `[x]="y"`, where input x is not a string input.
   */
  static const AngularWarningCode STRING_STYLE_INPUT_BINDING_INVALID =
      const AngularWarningCode(
          'STRING_STYLE_INPUT_BINDING_INVALID',
          "Input {0} is not a string input, but is not bound with [bracket] "
          "syntax. This binds the String attribute value directly, resulting "
          "in a type error.");
  /**
   * An error code indicating that a @ContentChild or @ContentChildren field
   * either mismatched types in the definition, or where it was used (ie
   * `@ContentChild(TemplateRef) ElementRef foo`, or `@ContentChild('foo')
   * TemplateRef foo` with `<div #foo>`).
   */
  static const AngularWarningCode INVALID_TYPE_FOR_CHILD_QUERY =
      const AngularWarningCode(
          'INVALID_TYPE_FOR_CHILD_QUERY',
          "The field {0} marked with @{1} referencing type {2} expects a member"
          " referencing type {2}, but got a {3}");

  /**
   * An error code indicating that a @ContentChild or @ContentChildren field
   * didn't have an expected value
   */
  static const AngularWarningCode UNKNOWN_CHILD_QUERY_TYPE =
      const AngularWarningCode(
          'UNKNOWN_CHILD_QUERY_TYPE',
          "The field {0} marked with @{1} must reference a directive, a string"
          " let-binding name, TemplateRef, or ElementRef");

  /**
   * An error code indicating that @ContentChildren or @ViewChildren was used
   * but the property wasn't a `QueryList`.
   */
  static const AngularWarningCode CONTENT_OR_VIEW_CHILDREN_REQUIRES_QUERY_LIST =
      const AngularWarningCode(
          'CONTENT_OR_VIEW_CHILDREN_REQUIRES_QUERY_LIST',
          "The field {0} marked with @{1} expects a member of type QueryList,"
          " but got {2}");

  /**
   * An error code indicating that @ContentChild or @ViewChild with a string
   * let-binding query was matched in a way that's not assignable to the
   * annotated property.
   */
  static const AngularWarningCode MATCHED_LET_BINDING_HAS_WRONG_TYPE =
      const AngularWarningCode(
          'MATCHED_LET_BINDING_HAS_WRONG_TYPE',
          "Marking this with #{0} here expects the element to be of type {1},"
          " (but is of type {2}) because an enclosing element marks {0} as a"
          " content child field of type {1}.");

  /**
   * An error code indicating that @ContentChild or @ViewChild was matched
   * multiple times.
   */
  static const AngularWarningCode SINGULAR_CHILD_QUERY_MATCHED_MULTIPLE_TIMES =
      const AngularWarningCode(
          'SINGULAR_CHILD_QUERY_MATCHED_MULTIPLE_TIMES',
          "A containing {0} expects a single child matching {1}, but this is"
          " not the first match. Use (Content or View)Children to allow"
          " multiple matches.");

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
