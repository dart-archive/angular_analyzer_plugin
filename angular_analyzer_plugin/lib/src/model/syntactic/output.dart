import 'package:analyzer/src/generated/source.dart' show Source, SourceRange;
import 'package:angular_analyzer_plugin/src/model/syntactic/element.dart';

/// The model for an Angular output.
///
/// ```dart
///   @Output('optionalName')
///   Type fieldName; // may be a getter only
/// ```
///
/// By tracking the name, we can resolve the type at link time. We track the
/// [SourceRange] (as well as [nameOffset] and [nameLength] to help expose
/// better errors at that time.
///
/// Extends [AngularElementImpl] because it is navigable.
class Output extends AngularElementImpl {
  final String getterName;

  /// The [SourceRange] where [getter] is referenced in the input declaration.
  /// May be the same as this element offset/length in shorthand variants where
  /// names of a input and the getter are the same.
  final SourceRange getterRange;

  Output(String name, int nameOffset, int nameLength, Source source,
      this.getterName, this.getterRange)
      : super(name, nameOffset, nameLength, source);

  @override
  String toString() => 'Output($name, $nameOffset, $nameLength, $getterName)';
}
