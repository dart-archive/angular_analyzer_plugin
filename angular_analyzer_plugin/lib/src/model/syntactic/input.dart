import 'package:analyzer/src/generated/source.dart' show Source, SourceRange;
import 'package:angular_analyzer_plugin/src/model/syntactic/element.dart';

/// The model for an Angular input.
///
/// ```dart
///   @Input('optionalName')
///   Type fieldName; // may be a setter only
/// ```
///
/// By tracking the name, we can resolve the type at link time. We track the
/// [SourceRange] (as well as [nameOffset] and [nameLength] to help expose
/// better errors at that time.
///
/// Extends [AngularElementImpl] because it is navigable.
class Input extends AngularElementImpl {
  final String setterName;

  /// The [SourceRange] where [setter] is referenced in the input declaration.
  /// May be the same as this element offset/length in shorthand variants where
  /// names of a input and the setter are the same.
  final SourceRange setterRange;

  /// A given input can have an alternative name, or more 'conventional' name
  /// that differs from the name provided by dart:html source.
  /// For example: the source may declare `className`, but angular itself may
  /// prefer `class`. In this case, [name] would be 'class' and [originalName]
  /// would be 'originalName'. This should be null if there is no alternative
  /// name.
  final String originalName;

  Input(String name, int nameOffset, int nameLength, Source source,
      this.setterName, this.setterRange,
      {this.originalName})
      : super(name, nameOffset, nameLength, source);

  @override
  String toString() => 'Input($name, $nameOffset, $nameLength, $setterName)';
}
