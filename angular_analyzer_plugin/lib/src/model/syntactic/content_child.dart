import 'package:analyzer/src/generated/source.dart' show SourceRange;

/// Syntactic model of `ContentChild`/`ContentChlidren`. This may appear as:
///
/// ```dart
///   @ContentChild(...) Type contentChildField;
/// // or
///   @ContentChildren(...) List<Type> contentChildrenField;
/// ```
///
/// By tracking the field name, we can resolve the getter along with the
/// computed constant value of the annotation at link time. We also track the
/// syntactic name and type locations for better error reporting at that stage.
class ContentChild {
  final String fieldName;
  final SourceRange nameRange;
  final SourceRange typeRange;

  ContentChild(this.fieldName, {this.nameRange, this.typeRange});
}
