import 'package:analyzer/src/generated/source.dart' show Source;
import 'package:angular_analyzer_plugin/src/model/syntactic/annotated_class.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/base_directive.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/content_child.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/element.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/input.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/output.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';

/// Core common behavior to class directives, components. Excludes functional
/// directives and non-directive concepts like pipes and annotated normal
/// classes.
abstract class BaseClassDirective extends AnnotatedClass
    implements BaseDirective {
  @override
  final Selector selector;

  @override
  final AngularElement exportAs;

  @override
  final List<ElementNameSelector> elementTags;

  BaseClassDirective(String className, Source source,
      {this.exportAs,
      List<Input> inputs,
      List<Output> outputs,
      this.selector,
      this.elementTags,
      List<ContentChild> contentChildFields,
      List<ContentChild> contentChildrenFields})
      : super(className, source,
            inputs: inputs,
            outputs: outputs,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields);

  @override
  String get name => className;
}
