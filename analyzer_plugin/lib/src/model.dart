library angular2.src.analysis.analyzer_plugin.src.model;

import 'package:analyzer/src/generated/element.dart' as dart;
import 'package:analyzer/src/generated/source.dart' show Source, SourceRange;
import 'package:analyzer/src/generated/utilities_general.dart';
import 'package:angular2_analyzer_plugin/src/selector.dart';
import 'package:html/dom.dart' show DocumentFragment;

/// An abstract model of an Angular directive.
abstract class AbstractDirective {
  static const List<AbstractDirective> EMPTY_LIST = const <AbstractDirective>[];

  /// The [ClassElement] this annotation is associated with.
  final dart.ClassElement classElement;

  final Selector selector;

  AbstractDirective(this.classElement, {this.selector});

  /// The source that contains this directive.
  Source get source => classElement.source;
}

/// The base class for all Angular elements.
abstract class AngularElement {
  /// Return the name of this element, not `null`.
  String get name;

  /// Return the offset of the name of this element in the file that contains
  /// the declaration of this element.
  int get nameOffset;

  /// Return the [Source] of this element.
  Source get source;
}

/// The base class for concrete implementations of an [AngularElement].
class AngularElementImpl implements AngularElement {
  final String name;
  final int nameOffset;
  final Source source;

  AngularElementImpl(this.name, this.nameOffset, this.source);

  int get hashCode {
    return JenkinsSmiHash.hash3(name.hashCode, nameOffset, source.hashCode);
  }

  bool operator ==(Object other) {
    return other is AngularElement &&
        other.runtimeType == runtimeType &&
        other.nameOffset == nameOffset &&
        other.name == name &&
        other.source == source;
  }
}

/// The model of an Angular component.
class Component extends AbstractDirective {
  Component(dart.ClassElement classElement, {Selector selector})
      : super(classElement, selector: selector);
}

/// An [AngularElement] representing a Dart [Element].
class DartElement extends AngularElementImpl {
  final dart.Element element;

  DartElement(dart.Element element)
      : super(element.name, element.nameOffset, element.source),
        element = element;
}

/// The model of an Angular directive.
class Directive extends AbstractDirective {
  Directive(dart.ClassElement classElement, {Selector selector})
      : super(classElement, selector: selector);
}

/// A pair of an [SourceRange] and the referenced [AngularElement].
class ResolvedRange {
  /// The [SourceRange] where [element] is referenced.
  final SourceRange range;

  /// The [AngularElement] referenced at [range].
  final AngularElement element;

  ResolvedRange(this.range, this.element);

  @override
  String toString() => '$range=$element';
}

/// An Angular template.
/// Templates can be embedded into Dart or be separate HTML files.
class Template {
  static const List<Template> EMPTY_LIST = const <Template>[];

  /// The [View] that describes the template.
  final View view;

  /// The [Document] of the template.
  final DocumentFragment document;

  /// The [ResolvedRange]s of the template.
  final List<ResolvedRange> ranges = <ResolvedRange>[];

  Template(this.view, this.document);

  /// Records that the given [element] is referenced at the given [range].
  void addRange(SourceRange range, AngularElement element) {
    ranges.add(new ResolvedRange(range, element));
  }
}

/// The model of an Angular view.
class View {
  static const List<View> EMPTY_LIST = const <View>[];

  /// The [ClassElement] this view is associated with.
  final dart.ClassElement classElement;

  final Component component;
  final List<AbstractDirective> directives;
  final String templateText;
  final int templateOffset;
  final String templateUrl;

  /// The [Template] of this view, `null` until built.
  Template template;

  View(this.classElement, this.component, this.directives,
      {this.templateText, this.templateOffset: 0, this.templateUrl});

  /// The source that contains this view.
  Source get source => classElement.source;
}
