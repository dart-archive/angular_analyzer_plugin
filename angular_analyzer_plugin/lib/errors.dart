import 'dart:collection';

import 'package:analyzer/error/error.dart';
import 'package:angular_ast/angular_ast.dart';

/// used by angularWarningCodeByUniqueName to create a map for fast lookup
const _angularWarningCodeValues = const <AngularWarningCode>[
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
  AngularWarningCode.FUNCTION_IS_NOT_A_DIRECTIVE,
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
  AngularWarningCode.CUSTOM_DIRECTIVE_MAY_REQUIRE_TEMPLATE,
  AngularWarningCode.TEMPLATE_ATTR_NOT_USED,
  AngularWarningCode.NO_DIRECTIVE_EXPORTED_BY_SPECIFIED_NAME,
  AngularWarningCode.CONTENT_NOT_TRANSCLUDED,
  AngularWarningCode.OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT,
  AngularWarningCode.DISALLOWED_EXPRESSION,
  AngularWarningCode.ATTRIBUTE_PARAMETER_MUST_BE_STRING,
  AngularWarningCode.STRING_STYLE_INPUT_BINDING_INVALID,
  AngularWarningCode.INVALID_TYPE_FOR_CHILD_QUERY,
  AngularWarningCode.UNKNOWN_CHILD_QUERY_TYPE,
  AngularWarningCode.CHILD_QUERY_TYPE_REQUIRES_READ,
  AngularWarningCode.CONTENT_OR_VIEW_CHILDREN_REQUIRES_QUERY_LIST,
  AngularWarningCode.CONTENT_OR_VIEW_CHILDREN_REQUIRES_LIST,
  AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
  AngularWarningCode.EXPORTS_MUST_BE_PLAIN_IDENTIFIERS,
  AngularWarningCode.DUPLICATE_EXPORT,
  AngularWarningCode.COMPONENTS_CANT_EXPORT_THEMSELVES,
  AngularWarningCode.PIPE_SINGLE_NAME_REQUIRED,
  AngularWarningCode.TYPE_IS_NOT_A_PIPE,
  AngularWarningCode.PIPE_CANNOT_BE_ABSTRACT,
  AngularWarningCode.PIPE_REQUIRES_PIPETRANSFORM,
  AngularWarningCode.PIPE_REQUIRES_TRANSFORM_METHOD,
  AngularWarningCode.PIPE_TRANSFORM_NO_NAMED_ARGS,
  AngularWarningCode.PIPE_TRANSFORM_REQ_ONE_ARG,
  AngularWarningCode.PIPE_NOT_FOUND,
  AngularWarningCode.UNSAFE_BINDING,
  AngularWarningCode.EVENT_REDUCTION_NOT_ALLOWED,
  AngularWarningCode.FUNCTIONAL_DIRECTIVES_CANT_BE_EXPORTED,
  AngularHintCode.OFFSETS_CANNOT_BE_CREATED,
];

/// The lazy initialized map from [AngularWarningCode.uniqueName] to the
/// [AngularWarningCode] instance.
HashMap<String, ErrorCode> _uniqueNameToCodeMap;

/// Return the [AngularWarningCode] with the given [uniqueName], or `null` if not
/// found.
ErrorCode angularWarningCodeByUniqueName(String uniqueName) {
  if (_uniqueNameToCodeMap == null) {
    _uniqueNameToCodeMap = new HashMap<String, ErrorCode>();
    for (final angularCode in _angularWarningCodeValues) {
      _uniqueNameToCodeMap[angularCode.uniqueName] = angularCode;
    }
    for (final angularAstCode in angularAstWarningCodes) {
      _uniqueNameToCodeMap[angularAstCode.uniqueName] = angularAstCode;
    }
  }
  return _uniqueNameToCodeMap[uniqueName];
}

class AngularHintCode extends AngularWarningCode {
  /// When a user does for instance `template: 'foo$bar$baz`, we cannot analyze
  /// the template because we cannot easily map errors to code offsets.
  static const OFFSETS_CANNOT_BE_CREATED = const AngularHintCode(
      'OFFSETS_CANNOT_BE_CREATED',
      'Errors cannot be tracked for the constant expression because it is too'
      ' complex for errors to be mapped to locations in the file');

  /// Initialize a newly created error code to have the given [name].
  /// The message associated with the error will be created from the given
  /// [message] template. The correction associated with the error will be
  /// created from the given [correction] template.
  const AngularHintCode(String name, String message, [String correction])
      : super(name, message, correction);

  @override
  ErrorSeverity get errorSeverity => ErrorSeverity.INFO;

  @override
  ErrorType get type => ErrorType.HINT;
}

/// The error codes used for Angular warnings. The convention for this
/// class is for the name of the error code to indicate the problem that caused
/// the error to be generated and for the error message to explain what is wrong
/// and, when appropriate, how the problem can be corrected.
class AngularWarningCode extends ErrorCode {
  /// An error code indicating that the annotation does not define the
  /// required "selector" argument.
  static const ARGUMENT_SELECTOR_MISSING = const AngularWarningCode(
      'ARGUMENT_SELECTOR_MISSING', 'Argument "selector" missing');

  /// An error code indicating that the provided selector cannot be parsed.
  static const CANNOT_PARSE_SELECTOR = const AngularWarningCode(
      'CANNOT_PARSE_SELECTOR', 'Cannot parse the given selector ({0})');

  /// An error code indicating that a template points to a missing html file
  static const REFERENCED_HTML_FILE_DOESNT_EXIST = const AngularWarningCode(
      'REFERENCED_HTML_FILE_DOESNT_EXIST',
      'The referenced HTML file doesn\'t exist');

  /// An error code indicating that the component has @View annotation,
  /// but not @Component annotation.
  static const COMPONENT_ANNOTATION_MISSING = const AngularWarningCode(
      'COMPONENT_ANNOTATION_MISSING',
      'Every @View requires exactly one @Component annotation');

  /// An error code indicating that a @View or @Component has both a
  /// template and a templateUrl defined at once (illegal)
  static const TEMPLATE_URL_AND_TEMPLATE_DEFINED = const AngularWarningCode(
      'TEMPLATE_URL_AND_TEMPLATE_DEFINED',
      'Cannot define both template and templateUrl. Remove one');

  /// An error code indicating that a @View or @Component does not have
  /// a template or a templateUrl
  static const NO_TEMPLATE_URL_OR_TEMPLATE_DEFINED = const AngularWarningCode(
      'NO_TEMPLATE_URL_OR_TEMPLATE_DEFINED',
      'Either a template or templateUrl is required');

  /// An error code indicating that an identifier was expected, but not found.
  static const EXPECTED_IDENTIFIER =
      const AngularWarningCode('EXPECTED_IDENTIFIER', 'Expected identifier');

  /// An error code indicating that an hash was unexpected in template.
  static const UNEXPECTED_HASH_IN_TEMPLATE = const AngularWarningCode(
      'UNEXPECTED_HASH_IN_TEMPLATE', "Did you mean 'let' instead?");

  /// An error code indicating that the value of an expression is not a string.
  static const STRING_VALUE_EXPECTED = const AngularWarningCode(
      'STRING_VALUE_EXPECTED', 'A string value expected');

  /// An error code indicating that the value of an expression is not a string.
  static const TYPE_LITERAL_EXPECTED = const AngularWarningCode(
      'TYPE_LITERAL_EXPECTED', 'A type literal expected');

  /// An error code indicating that the value of an expression is not a string.
  static const TYPE_IS_NOT_A_DIRECTIVE = const AngularWarningCode(
      'TYPE_IS_NOT_A_DIRECTIVE',
      'The type "{0}" is included in the directives list, but is not a'
      ' directive');

  /// An error code indicating that a function not annotated with @Directive was
  /// used as one.
  static const FUNCTION_IS_NOT_A_DIRECTIVE = const AngularWarningCode(
      'FUNCTION_IS_NOT_A_DIRECTIVE',
      'The function "{0}" is included in the directives list, but is not a'
      ' functional directive');

  /// An error code indicating that the value of type is not a Pipe.
  static const TYPE_IS_NOT_A_PIPE = const AngularWarningCode(
      'TYPE_IS_NOT_A_PIPE',
      'The type "{0}" is included in the pipes list, but is not a pipe');

  /// An error code indicating that the tag was not resolved.
  static const UNRESOLVED_TAG =
      const AngularWarningCode('UNRESOLVED_TAG', 'Unresolved tag "{0}"');

  /// An error code indicating that the embedded expression is not terminated.
  static const UNTERMINATED_MUSTACHE = const AngularWarningCode(
      'UNTERMINATED_MUSTACHE', 'Unterminated mustache');

  /// An error code indicating that a mustache ending was found unopened
  static const UNOPENED_MUSTACHE = const AngularWarningCode(
      'UNOPENED_MUSTACHE', 'Mustache terminator with no opening');

  /// An error code indicating that a nonexist input was bound
  static const NONEXIST_INPUT_BOUND = const AngularWarningCode(
      'NONEXIST_INPUT_BOUND',
      'The bound input {0} does not exist on any directives or on the element');

  /// An error code indicating that a nonexist output was bound
  static const NONEXIST_OUTPUT_BOUND = const AngularWarningCode(
      'NONEXIST_OUTPUT_BOUND',
      'The bound output {0} does not exist on any directives or on the'
      ' element');

  /// An error code indicating that a nonexist output was bound
  static const EMPTY_BINDING = const AngularWarningCode(
      'EMPTY_BINDING', 'The binding {0} does not have a value specified');

  /// An error code indicating that a nonexist output was bound, perhaps
  /// because an input was two way bound. The nonexist bound output is
  /// an implementation detail, so give its own error.
  static const NONEXIST_TWO_WAY_OUTPUT_BOUND = const AngularWarningCode(
      'NONEXIST_TWO_WAY_OUTPUT_BOUND',
      'The two-way binding {0} requires a bindable output of name {1}');

  /// An error code indicating that the output event in a two-way binding
  /// doesn't match the input
  static const TWO_WAY_BINDING_OUTPUT_TYPE_ERROR = const AngularWarningCode(
      'TWO_WAY_BINDING_OUTPUT_TYPE_ERROR',
      'Output event in two-way binding (of type {0}) is not assignable to'
      ' component input (of type {1})');

  /// An error code indicating that an input was bound with a incorrectly
  /// typed expression
  static const INPUT_BINDING_TYPE_ERROR = const AngularWarningCode(
      'INPUT_BINDING_TYPE_ERROR',
      'Attribute value expression (of type {0}) is not assignable to component'
      ' input (of type {1})');

  /// An error code indicating that an expression did not correctly
  /// end with an EOF token.
  static const TRAILING_EXPRESSION = const AngularWarningCode(
      'TRAILING_EXPRESSION', 'Expressions must end with an EOF');

  /// An error code indicating that an @Output is not an EventEmitter
  static const OUTPUT_MUST_BE_STREAM = const AngularWarningCode(
      'OUTPUT_MUST_BE_STREAM', 'Output (of name {0}) must return a Stream');

  /// An error code indicating that a two-way binding expression was not
  /// a assignable (and therefore could only be one-way bound...)
  static const TWO_WAY_BINDING_NOT_ASSIGNABLE = const AngularWarningCode(
      'TWO_WAY_BINDING_NOT_ASSIGNABLE',
      'Only assignable expressions can be two-way bound');

  /// An error code indicating that an @Input annottaion was used in the wrong
  /// place
  static const INPUT_ANNOTATION_PLACEMENT_INVALID = const AngularWarningCode(
      'INPUT_ANNOTATION_PLACEMENT_INVALID',
      'The @Input() annotation can only be put on properties and setters');

  /// An error code indicating that an @Output annottaion was used in the wrong
  /// place
  static const OUTPUT_ANNOTATION_PLACEMENT_INVALID = const AngularWarningCode(
      'OUTPUT_ANNOTATION_PLACEMENT_INVALID',
      'The @Output() annotation can only be put on properties and getters');

  /// An error code indicating that a html classname was bound via
  /// [class.classname]="x" where classname is not a css identifier
  /// https://www.w3.org/TR/CSS21/syndata.html#value-def-identifier
  static const INVALID_HTML_CLASSNAME = const AngularWarningCode(
      'INVALID_HTML_CLASSNAME',
      'The html classname {0} is not a valid classname');

  /// An error code indicating that a html classname was bound via
  /// [class.classname]="x" where x was not a boolean
  static const CLASS_BINDING_NOT_BOOLEAN = const AngularWarningCode(
      'CLASS_BINDING_NOT_BOOLEAN', 'Binding to a classname requires a boolean');

  /// An error code indicating that a css property with a unit was bound via
  /// [style.property.unit]="x" where x was not a number
  static const CSS_UNIT_BINDING_NOT_NUMBER = const AngularWarningCode(
      'CSS_UNIT_BINDING_NOT_NUMBER',
      'Binding to a css property with a unit requires a number');

  /// An error code indicating that a css property with a unit was bound via
  /// [style.property.unit]="x" where unit was not an identifier
  /// https://www.w3.org/TR/CSS21/syndata.html#value-def-identifier
  static const INVALID_CSS_UNIT_NAME = const AngularWarningCode(
      'INVALID_CSS_UNIT_NAME',
      'The css unit {0} is not a valid css identifier');

  /// An error code indicating that a css property bound via
  /// [style.property]="x" or [style.property.unit]="x" where property was not an
  /// identifier
  /// https://www.w3.org/TR/CSS21/syndata.html#value-def-identifier
  static const INVALID_CSS_PROPERTY_NAME = const AngularWarningCode(
      'INVALID_CSS_PROPERTY_NAME',
      'The css property {0} is not a valid css identifier');

  /// An error code indicating that a binding was not a * dart identifier, or
  /// [class.classname], or [attr.attrname], or [style.property], or
  /// [style.property.unit].
  static const INVALID_BINDING_NAME = const AngularWarningCode(
      'INVALID_BINDING_NAME',
      'The binding {} is not a valid dart identifer, attribute, style, or class'
      ' binding');

  /// An error code indicating that ngIf or ngFor were used without a template
  static const STRUCTURAL_DIRECTIVES_REQUIRE_TEMPLATE =
      const AngularWarningCode(
          'STRUCTURAL_DIRECTIVES_REQUIRE_TEMPLATE',
          'Structural directive {0} requires a template. Did you mean'
          ' *{0}="..." or template="{0} ..." or <template {0} ...>?');

  /// An error code indicating in #y="x", x was not an exported name
  static const NO_DIRECTIVE_EXPORTED_BY_SPECIFIED_NAME =
      const AngularWarningCode('NO_DIRECTIVE_EXPORTED_BY_SPECIFIED_NAME',
          'No directives matching this element are exported by the name {0}');

  /// An error code indicating in <div dir1 dir2 #y="x">, x is ambigious since
  /// both directives dir1 and dir2 have same exportAs name "x".
  static const DIRECTIVE_EXPORTED_BY_AMBIGIOUS = const AngularWarningCode(
      'DIRECTIVE_EXPORTED_BY_AMBIGIOUS',
      "More than one directive's exportAs value matches '{0}'.");

  /// An error code indicating that a custom component appears to require a star.
  static const AngularWarningCode CUSTOM_DIRECTIVE_MAY_REQUIRE_TEMPLATE =
      const AngularWarningCode(
          'CUSTOM_DIRECTIVE_MAY_REQUIRE_TEMPLATE',
          'The directive {0} accepts a TemplateRef in its constructor, so it'
          ' may require a *-style-attr to work correctly.');

  /// An error code indicating that a custom component appears to require a star.
  static const AngularWarningCode TEMPLATE_ATTR_NOT_USED =
      const AngularWarningCode(
          'TEMPLATE_ATTR_NOT_USED',
          'This template attr does not match any directives that use the'
          ' resulting hidden template. Check that all directives are being'
          ' imported and used correctly.');

  /// An error code indicating that an output-bound statement
  /// must be an [ExpressionStatement].
  static const OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT =
      const AngularWarningCode('OUTPUT_STATEMENT_REQUIRES_EXPRESSION_STATEMENT',
          "Syntax Error: unexpected {0}");

  /// An error code indicating that a mustache or other expression binding was an
  /// unsupported type such as an 'as' expression or a constructor
  static const DISALLOWED_EXPRESSION = const AngularWarningCode(
      'DISALLOWED_EXPRESSION', "{0} not allowed in angular templates");

  /// An error code indicating that dom inside a component won't be transcluded
  static const CONTENT_NOT_TRANSCLUDED = const AngularWarningCode(
      'CONTENT_NOT_TRANSCLUDED',
      'The content does not match any transclusion selectors of the surrounding'
      ' component');

  /// An error code indicating that an <ng-content> tag had content, which is not
  /// allowed.
  static const NG_CONTENT_MUST_BE_EMPTY = const AngularWarningCode(
      'NG_CONTENT_MUST_BE_EMPTY',
      'Nothing is allowed inside an <ng-content> tag, as it will be replaced');

  /// An error code indicating that a constructor parameter was marked with
  /// @Attribute, but the argument wasn't of type string.
  static const ATTRIBUTE_PARAMETER_MUST_BE_STRING = const AngularWarningCode(
      'ATTRIBUTE_PARAMETER_MUST_BE_STRING',
      'Parameters marked with @Attribute must be of type String');

  /// An error code indicating that an input binding was used in string form, ie,
  /// `x="y"` rather than `[x]="y"`, where input x is not a string input.
  static const STRING_STYLE_INPUT_BINDING_INVALID = const AngularWarningCode(
      'STRING_STYLE_INPUT_BINDING_INVALID',
      'Input {0} is not a string input, but is not bound with [bracket] syntax.'
      ' This binds the String attribute value directly, resulting  in a type '
      'error.');

  /// An error code indicating that a @ContentChild or @ContentChildren field
  /// either mismatched types in the definition, or where it was used (ie
  /// `@ContentChild(TemplateRef) ElementRef foo`, or `@ContentChild('foo')
  /// TemplateRef foo` with `<div #foo>`).
  static const INVALID_TYPE_FOR_CHILD_QUERY = const AngularWarningCode(
      'INVALID_TYPE_FOR_CHILD_QUERY',
      'The field {0} marked with @{1} referencing type {2} expects a member'
      ' referencing type {2}, but got a {3}');

  /// An error code indicating that a @ContentChild or @ContentChildren field
  /// didn't have an expected value
  static const UNKNOWN_CHILD_QUERY_TYPE = const AngularWarningCode(
      'UNKNOWN_CHILD_QUERY_TYPE',
      'The field {0} marked with @{1} must reference a directive, a string'
      ' let-binding name, TemplateRef, or ElementRef');

  /// An error code indicating that a @ContentChild or @ContentChildren field
  /// didn't have an expected value
  static const CHILD_QUERY_TYPE_REQUIRES_READ = const AngularWarningCode(
      'CHILD_QUERY_TYPE_REQUIRES_READ',
      'The field {0} marked with @{1} cannot reference type {2} unless the @{1}'
      ' annotation includes `read: {2}`');

  /// An error code indicating that @ContentChildren or @ViewChildren was used
  /// but the property wasn't a `QueryList`.
  static const CONTENT_OR_VIEW_CHILDREN_REQUIRES_LIST =
      const AngularWarningCode(
          'CONTENT_OR_VIEW_CHILDREN_REQUIRES_LIST',
          'The field {0} marked with @{1} expects a member of type List,'
          ' but got {2}');

  /// Here for backwards compatibility. Should not be used. Use
  /// [CONTENT_OR_VIEW_CHILDREN_REQUIRES_LIST] instead. Note: we can remove this
  /// the next time we tick the salt in `lib/src/file_tracker.dart`.
  @deprecated
  static const CONTENT_OR_VIEW_CHILDREN_REQUIRES_QUERY_LIST =
      const AngularWarningCode(
          'CONTENT_OR_VIEW_CHILDREN_REQUIRES_QUERY_LIST',
          'The field {0} marked with @{1} expects a member of type QueryList,'
          ' but got {2}');

  /// An error code indicating that @ContentChild or @ViewChild with a string
  /// let-binding query was matched in a way that's not assignable to the
  /// annotated property.
  static const MATCHED_LET_BINDING_HAS_WRONG_TYPE = const AngularWarningCode(
      'MATCHED_LET_BINDING_HAS_WRONG_TYPE',
      'Marking this with #{0} here expects the element to be of type {1}, (but'
      ' is of type {2}) because an enclosing element marks {0} as a content'
      ' child field of type {1}.');

  /// An error code indicating that @ContentChild or @ViewChild was matched
  /// multiple times.
  static const SINGULAR_CHILD_QUERY_MATCHED_MULTIPLE_TIMES =
      const AngularWarningCode(
          'SINGULAR_CHILD_QUERY_MATCHED_MULTIPLE_TIMES',
          'A containing {0} expects a single child matching {1}, but this is'
          ' not the first match. Use (Content or View)Children to allow'
          ' multiple matches.');

  /// An error code indicating that the exports array got a non-identifier
  static const EXPORTS_MUST_BE_PLAIN_IDENTIFIERS = const AngularWarningCode(
      'EXPORTS_MUST_BE_PLAIN_IDENTIFIERS', 'Exports must be plain identifiers');

  /// An error code indicating that an identifier was exported multiple times
  static const DUPLICATE_EXPORT = const AngularWarningCode(
      'DUPLICATE_EXPORT', 'Duplicate export of identifier {0}');

  /// An error code indicating component Foo exports Foo, which is unnecessary
  static const COMPONENTS_CANT_EXPORT_THEMSELVES = const AngularWarningCode(
      'COMPONENTS_CANT_EXPORT_THEMSELVES',
      'Components export their class by default, and therefore should not be'
      ' specified in the exports list');

  /// An error code indicating that the Pipe class cannot be abstract.
  static const PIPE_CANNOT_BE_ABSTRACT = const AngularWarningCode(
      'PIPE_CANNOT_BE_ABSTRACT', r'Pipe classes cannot be abstract');

  /// An error code indicating that the Pipe annotation does not define the
  /// required pipe name argument - and is the only non-named argument.
  static const PIPE_SINGLE_NAME_REQUIRED = const AngularWarningCode(
      'PIPE_NAME_MISSING',
      r'@Pipe declarations must contain exactly one'
      r' non-named argument of String type for pipe name');

  /// An error code indicating that a declared Pipe does not extend
  /// [PipeTransform] class.
  static const PIPE_REQUIRES_PIPETRANSFORM = const AngularWarningCode(
      'PIPE_REQUIRES_PIPETRANSFORM',
      "@Pipe declared classes need to extend 'PipeTransform'");

  /// An error code indicating that a declared Pipe does not have
  /// a 'transform' method.
  static const PIPE_REQUIRES_TRANSFORM_METHOD = const AngularWarningCode(
    'PIPE_REQUIRES_TRANSFORM_METHOD',
    "@Pipe declared classes must contain a 'transform' method",
  );

  /// An error indicating that the 'transform' method within a Pipe
  /// cannot have named arguments.
  static const PIPE_TRANSFORM_NO_NAMED_ARGS = const AngularWarningCode(
      'PIPE_TRANSFORM_NO_NAMED_ARGS',
      "'transform' method for pipe should not have named arguments");

  /// An error indicating that the 'transform' method within a Pipe
  /// requires at least one argument.
  static const PIPE_TRANSFORM_REQ_ONE_ARG = const AngularWarningCode(
      'PIPE_TRANSFORM_REQ_ONE_ARG',
      "'transform' method requires at least one argument");

  /// An error indicating that pipe syntax was used in an angular template, but
  /// the name of the pipe doesn't match one defined in the component
  static const PIPE_NOT_FOUND = const AngularWarningCode(
      'PIPE_NOT_FOUND',
      "Pipe by name of {0} not found. Did you reference it in your @Component"
      " configuration?");

  /// An error indicating that a security exception will be thrown by this input
  /// binding
  static const UNSAFE_BINDING = const AngularWarningCode(
      'UNSAFE_BINDING',
      'A security exception will be thrown by this binding. You must use the '
      ' security service to get an instance of {0} and bind that result.');

  /// An error indicating that an event other than `(keyup.x)` or `(keydown.+)`
  /// etc, had reduction suffixes in that style, which is not allowed.
  static const EVENT_REDUCTION_NOT_ALLOWED = const AngularWarningCode(
      'EVENT_REDUCTION_NOT_ALLOWED',
      'Event reductions are only allowed on keyup and keydown events');

  /// An error indicating that functional directve had exportAs specified, which
  /// is not allowed.
  static const FUNCTIONAL_DIRECTIVES_CANT_BE_EXPORTED =
      const AngularWarningCode(
          'FUNCTIONAL_DIRECTIVES_CANT_BE_EXPORTED',
          'Function directives cannot have an exportAs setting, because they'
          " can't be exported");

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
