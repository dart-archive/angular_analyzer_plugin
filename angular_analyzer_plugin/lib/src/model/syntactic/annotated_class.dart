import 'package:analyzer/src/generated/source.dart' show Source;
import 'package:angular_analyzer_plugin/src/model/syntactic/content_child.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/input.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/output.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/top_level.dart';

/// Syntactic representation of a class annotated with angular annotations.
/// Might be a directive, or a component, or neither. It might simply have
/// annotated @Inputs, @Outputs() intended to be inherited.
class AnnotatedClass extends TopLevel {
  final String className;

  /// The source that contains this directive.
  @override
  final Source source;

  /// Which fields have been marked `@ContentChild`, and the range of the type
  /// argument. The element model contains the rest. This should be stored in the
  /// summary, so that at link time we can report errors discovered in the model
  /// against the range we saw in the AST.
  @override
  final List<ContentChild> contentChilds;

  @override
  final List<ContentChild> contentChildren;

  AnnotatedClass(this.className, this.source,
      {List<Input> inputs,
      List<Output> outputs,
      this.contentChilds,
      this.contentChildren})
      : super(inputs: inputs, outputs: outputs);

  @override
  int get hashCode => className.hashCode * 11 + source.hashCode;

  @override
  bool operator ==(Object other) =>
      other is AnnotatedClass &&
      other.className == className &&
      other.source == source;

  @override
  String toString() => '$runtimeType($className '
      'inputs=$inputs '
      'outputs=$outputs '
      'attributes=$attributes)';
}
