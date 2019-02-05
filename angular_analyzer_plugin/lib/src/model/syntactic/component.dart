import 'package:analyzer/src/generated/source.dart' show Source;
import 'package:analyzer/src/generated/source.dart' show Source, SourceRange;
import 'package:angular_analyzer_plugin/src/model/syntactic/base_class_directive.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/component_with_contents.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/content_child.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/element.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/input.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/ng_content.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/output.dart';
import 'package:angular_analyzer_plugin/src/model/syntactic/reference.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';

/// Syntactic model of an Angular component. It is usable as a directive, must
/// be a class, and has "view" information.
///
/// ```dart
/// @Component(
///   selector: 'my-selector', // required
///   exportAs: 'foo', // optional
///   directives: [SubDirectiveA, SubDirectiveB], // optional
///   pipes: [PipeA, PipeB], // optional
///   exports: [foo, bar], // optional
///
///   // Template required. May be an inline body or a URI
///   template: '...', // or
///   templateUri: '...',
/// )
/// class MyComponent { // must be a class
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
class Component extends BaseClassDirective {
  /// Directives references. May be `directives: LIST_OF_DIRECTIVES`, or
  /// `directives: [DirectiveA, DirectiveB, ...]`.
  final ListOrReference directives;

  /// Pipe references. May be `pipes: LIST_OF_PIPES`, or
  /// `pipes: [PipeA, PipeB, ...]`.
  final ListOrReference pipes;

  /// Export references. May be `exports: LIST_OF_CONST_VALUES`, or
  /// `exports: [foo, bar, ...]`.
  final ListOrReference exports;

  final String templateText;
  final int templateOffset;
  final String templateUrl;
  final SourceRange templateUrlRange;

  Component(String className, Source source,
      {AngularElement exportAs,
      List<Input> inputs,
      List<Output> outputs,
      Selector selector,
      List<ElementNameSelector> elementTags,
      List<ContentChild> contentChildFields,
      List<ContentChild> contentChildrenFields,
      this.directives,
      this.pipes,
      this.exports,
      this.templateText,
      this.templateOffset: 0,
      this.templateUrl,
      this.templateUrlRange})
      : super(className, source,
            exportAs: exportAs,
            inputs: inputs,
            outputs: outputs,
            selector: selector,
            elementTags: elementTags,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields);

  int get end => templateOffset + templateText.length;

  ComponentWithNgContents withNgContents(List<NgContent> ngContents) =>
      ComponentWithNgContents(className, source,
          exportAs: exportAs,
          inputs: inputs,
          outputs: outputs,
          selector: selector,
          elementTags: elementTags,
          contentChildFields: contentChildFields,
          contentChildrenFields: contentChildrenFields,
          directives: directives,
          pipes: pipes,
          exports: exports,
          templateText: templateText,
          templateOffset: templateOffset,
          templateUrl: templateUrl,
          templateUrlRange: templateUrlRange,
          ngContents: ngContents);
}
