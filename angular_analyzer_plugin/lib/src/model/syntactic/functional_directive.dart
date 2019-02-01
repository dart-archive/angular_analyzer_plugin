import 'package:analyzer/src/generated/source.dart' show Source;
import 'package:angular_analyzer_plugin/src/model/syntactic/base_directive.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/content_child.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/element.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/input.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/output.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';

/// The syntactic model of a functional directive declaration.
///
/// ```dart
/// @Directive(
///   selector: 'my-selector'
/// ),
/// void myDirective(...) {...}
/// ```
///
/// A functional directive is applied to an angular app at runtime when the
/// directive is linked, but does nothing later in the program. Thus it cannot
/// have inputs, outputs, etc. But for the sake of clean code, those methods are
/// implemented to return null, empty list, etc.
class FunctionalDirective implements BaseDirective {
  final String functionName;

  @override
  final Source source;

  @override
  final Selector selector;

  @override
  final List<ElementNameSelector> elementTags;

  FunctionalDirective(
      this.functionName, this.source, this.selector, this.elementTags);

  // TODO(mfairhurst): can functional directives have attributes?
  @override
  List<AngularElement> get attributes => const [];

  /// Functional directives cannot have contentChildren
  @override
  List<ContentChild> get contentChildren => const [];

  /// Functional directives cannot have contentChildren
  @override
  List<ContentChild> get contentChilds => const [];

  // Functional directives cannot be exported
  @override
  AngularElement get exportAs => null;

  @override
  int get hashCode => functionName.hashCode * 11 + source.hashCode;

  // Functional directives cannot have inputs
  @override
  List<Input> get inputs => const [];

  @override
  String get name => functionName;

  // Functional directives cannot have outputs
  @override
  List<Output> get outputs => const [];

  @override
  bool operator ==(Object other) =>
      other is FunctionalDirective &&
      other.functionName == functionName &&
      other.source == source;

  @override
  String toString() =>
      'FunctionalDirective($functionName ' 'selector=$selector ';
}
