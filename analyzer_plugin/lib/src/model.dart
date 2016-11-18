library angular2.src.analysis.analyzer_plugin.src.model;

import 'package:analyzer/dart/element/element.dart' as dart;
import 'package:analyzer/src/generated/source.dart' show Source, SourceRange;
import 'package:analyzer/src/generated/utilities_general.dart';
import 'package:analyzer/task/model.dart' show AnalysisTarget;
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:html/dom.dart' as html;

/**
 * An abstract model of an Angular directive.
 */
abstract class AbstractDirective {
  static const List<AbstractDirective> EMPTY_LIST = const <AbstractDirective>[];

  /**
   * The [ClassElement] this annotation is associated with.
   */
  final dart.ClassElement classElement;

  final AngularElement exportAs;
  final List<InputElement> inputs;
  final Selector selector;

  AbstractDirective(this.classElement,
      {this.exportAs, this.inputs, this.selector});

  /**
   * The source that contains this directive.
   */
  Source get source => classElement.source;

  @override
  String toString() {
    return '$runtimeType(${classElement.displayName} '
        'selector=$selector '
        'inputs=$inputs)';
  }
}

/**
 * The base class for all Angular elements.
 */
abstract class AngularElement {
  /**
   * Return the name of this element, not `null`.
   */
  String get name;

  /**
   * Return the length of the name of this element in the file that contains
   * the declaration of this element.
   */
  int get nameLength;

  /**
   * Return the offset of the name of this element in the file that contains
   * the declaration of this element.
   */
  int get nameOffset;

  /**
   * Return the [Source] of this element.
   */
  Source get source;
}

/**
 * The base class for concrete implementations of an [AngularElement].
 */
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
  int get hashCode {
    return JenkinsSmiHash.hash4(
        name.hashCode, nameOffset, nameLength, source.hashCode);
  }

  bool operator ==(Object other) {
    return other is AngularElement &&
        other.runtimeType == runtimeType &&
        other.nameOffset == nameOffset &&
        other.nameLength == nameLength &&
        other.name == name &&
        other.source == source;
  }

  @override
  String toString() => name;
}

/**
 * The model of an Angular component.
 */
class Component extends AbstractDirective {
  Component(dart.ClassElement classElement,
      {AngularElement exportAs, List<InputElement> inputs, Selector selector})
      : super(classElement,
            exportAs: exportAs, inputs: inputs, selector: selector);
}

/**
 * An [AngularElement] representing a [dart.Element].
 */
class DartElement extends AngularElementImpl {
  final dart.Element element;

  DartElement(dart.Element element)
      : super(element.name, element.nameOffset, element.nameLength,
            element.source),
        element = element;
}

/**
 * The model of an Angular directive.
 */
class Directive extends AbstractDirective {
  Directive(dart.ClassElement classElement,
      {AngularElement exportAs, List<InputElement> inputs, Selector selector})
      : super(classElement,
            exportAs: exportAs, inputs: inputs, selector: selector);
}

/**
 * An Angular template in an HTML file.
 */
class HtmlTemplate extends Template {
  static const List<HtmlTemplate> EMPTY_LIST = const <HtmlTemplate>[];

  /**
   * The [Source] of the template.
   */
  final Source source;

  HtmlTemplate(View view, html.Element element, this.source)
      : super(view, element);
}

/**
 * The model for an Angular input.
 */
class InputElement extends AngularElementImpl {
  static const List<InputElement> EMPTY_LIST = const <InputElement>[];

  final dart.PropertyAccessorElement setter;

  /**
   * The [SourceRange] where [setter] is referenced in the input declaration.
   * May be the same as this element offset/length in shorthand variants where
   * names of a input and the setter are the same.
   */
  final SourceRange setterRange;

  InputElement(String name, int nameOffset, int nameLength, Source source,
      this.setter, this.setterRange)
      : super(name, nameOffset, nameLength, source);

  @override
  String toString() {
    return 'InputElement($name, $nameOffset, $nameLength, $setter)';
  }
}

/**
 * A pair of an [SourceRange] and the referenced [AngularElement].
 */
class ResolvedRange {
  /**
   * The [SourceRange] where [element] is referenced.
   */
  final SourceRange range;

  /**
   * The [AngularElement] referenced at [range].
   */
  final AngularElement element;

  ResolvedRange(this.range, this.element);

  @override
  String toString() {
    return '$range=[$element, '
        'nameOffset=${element.nameOffset}, '
        'nameLength=${element.nameLength}, '
        'source=${element.source}]';
  }
}

/**
 * An Angular template.
 * Templates can be embedded into Dart.
 */
class Template {
  static const List<Template> EMPTY_LIST = const <Template>[];

  /**
   * The [View] that describes the template.
   */
  final View view;

  /**
   * The [html.Element] of the template.
   */
  final html.Element element;

  /**
   * The [ResolvedRange]s of the template.
   */
  final List<ResolvedRange> ranges = <ResolvedRange>[];

  Template(this.view, this.element);

  /**
   * Records that the given [element] is referenced at the given [range].
   */
  void addRange(SourceRange range, AngularElement element) {
    assert(range != null);
    assert(range.offset != null);
    assert(range.offset >= 0);
    ranges.add(new ResolvedRange(range, element));
  }

  @override
  String toString() {
    return 'Template(ranges=$ranges)';
  }
}

/**
 * The model of an Angular view.
 */
class View implements AnalysisTarget {
  static const List<View> EMPTY_LIST = const <View>[];

  /**
   * The [ClassElement] this view is associated with.
   */
  final dart.ClassElement classElement;

  final Component component;
  final List<AbstractDirective> directives;
  final String templateText;
  final int templateOffset;
  final Source templateUriSource;
  final SourceRange templateUrlRange;

  /**
   * The [Template] of this view, `null` until built.
   */
  Template template;

  View(this.classElement, this.component, this.directives,
      {this.templateText,
      this.templateOffset: 0,
      this.templateUriSource,
      this.templateUrlRange});

  /**
   * The source that contains this view.
   */
  Source get source => classElement.source;

  /**
   * The source that contains this template, [source] or [templateUriSource].
   */
  Source get templateSource => templateUriSource ?? source;

  @override
  Source get librarySource => null;

  @override
  String toString() => 'View('
      'classElement=$classElement, '
      'component=$component, '
      'directives=$directives)';
}
