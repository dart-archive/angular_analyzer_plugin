import 'package:analyzer/src/generated/source.dart' show Source;
import 'package:angular_analyzer_plugin/src/model/syntactic/base_class_directive.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/content_child.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/element.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/input.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/output.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';

/// Syntactic model of an Angular directive. This excludes functional
/// directives, if you want to include functional directives then use
/// BaseDirective.
///
/// ```dart
/// @Directive(
///   selector: 'my-selector', // required
///   exportAs: 'foo', // optional
/// )
/// class MyDirective { // must be a class
///   @Input() input; // may have inputs
///   @Output() output; // may have outputs
///
///   // may have content child(ren).
///   @ContentChild(...) child;
///   @ContentChildren(...) children;
///
///   MyComponent(
///     @Attribute() String attr, // may have attributes
///   );
/// }
/// ```
class Directive extends BaseClassDirective {
  Directive(String className, Source source,
      {AngularElement exportAs,
      List<Input> inputs,
      List<Output> outputs,
      Selector selector,
      List<ElementNameSelector> elementTags,
      List<ContentChild> contentChilds,
      List<ContentChild> contentChildren})
      : super(className, source,
            exportAs: exportAs,
            inputs: inputs,
            outputs: outputs,
            selector: selector,
            elementTags: elementTags,
            contentChilds: contentChilds,
            contentChildren: contentChildren);
}
