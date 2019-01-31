import 'package:analyzer/src/generated/source.dart' show Source;
import 'package:angular_analyzer_plugin/src/model/syntactic/content_child.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/element.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/input.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/output.dart';

/// An abstract model of an Angular top level construct.
///
/// This may be a functional directive, component, or normal directive...or even
/// an [AngularAnnotatedClass] which is a class that defines component/directive
/// behavior for the sake of being inherited.
abstract class TopLevel {
  final attributes = <AngularElement>[];

  final List<Input> inputs;

  final List<Output> outputs;

  TopLevel({
    this.inputs,
    this.outputs,
  });

  List<ContentChild> get contentChildren;

  List<ContentChild> get contentChilds;

  Source get source;
}
