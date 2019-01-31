import 'package:analyzer/src/generated/source.dart' show Source;
import 'package:analyzer/src/generated/utilities_general.dart';

/// The base class for all Angular elements. Implementing this interface is
/// required to make something navigable.
abstract class AngularElement {
  /// Return the name of this element, not `null`.
  String get name;

  /// Return the length of the name of this element in the file that contains
  /// the declaration of this element.
  int get nameLength;

  /// Return the offset of the name of this element in the file that contains
  /// the declaration of this element.
  int get nameOffset;

  /// Return the [Source] of this element.
  Source get source;
}

/// The base class for concrete implementations of an [AngularElement].
class AngularElementImpl implements AngularElement {
  @override
  final String name;

  @override
  final int nameOffset;

  @override
  final int nameLength;

  @override
  final Source source;

  AngularElementImpl(this.name, this.nameOffset, this.nameLength, this.source);

  @override
  int get hashCode => JenkinsSmiHash.hash4(
      name.hashCode, nameOffset ?? -1, nameLength ?? -1, source.hashCode);

  @override
  bool operator ==(Object other) =>
      other is AngularElement &&
      other.runtimeType == runtimeType &&
      other.nameOffset == nameOffset &&
      other.nameLength == nameLength &&
      other.name == name &&
      other.source == source;

  @override
  String toString() => name;
}
