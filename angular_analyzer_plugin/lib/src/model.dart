library angular2.src.analysis.analyzer_plugin.src.model;

import 'dart:collection';

import 'package:analyzer/dart/ast/ast.dart' as dart;
import 'package:analyzer/dart/element/element.dart' as dart;
import 'package:analyzer/dart/element/type.dart' as dart;
import 'package:analyzer/error/listener.dart';
import 'package:analyzer/src/generated/constant.dart';
import 'package:analyzer/src/generated/source.dart' show Source, SourceRange;
import 'package:analyzer/src/generated/utilities_general.dart';
import 'package:angular_analyzer_plugin/ast.dart';
import 'package:angular_analyzer_plugin/errors.dart';
import 'package:angular_analyzer_plugin/src/selector.dart';
import 'package:angular_analyzer_plugin/src/standard_components.dart';

abstract class AbstractClassDirective extends AngularAnnotatedClass
    implements AbstractDirective {
  @override
  final Selector selector;

  @override
  final AngularElement exportAs;

  @override
  final List<ElementNameSelector> elementTags;

  AbstractClassDirective(dart.ClassElement classElement,
      {this.exportAs,
      List<InputElement> inputs,
      List<OutputElement> outputs,
      this.selector,
      this.elementTags,
      List<ContentChildField> contentChildFields,
      List<ContentChildField> contentChildrenFields})
      : super(classElement,
            inputs: inputs,
            outputs: outputs,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields);

  @override
  String get name => classElement.name;
}

abstract class AbstractDirective extends AngularTopLevel {
  List<ElementNameSelector> get elementTags;

  AngularElement get exportAs;

  String get name;

  Selector get selector;
}

abstract class AbstractQueriedChildType {
  bool match(ElementInfo element, StandardAngular angular,
      StandardHtml standardHtml, ErrorReporter reporter);
}

/// Might be a directive, or a component, or neither. It might simply have
/// annotated @Inputs, @Outputs() intended to be inherited.
class AngularAnnotatedClass extends AngularTopLevel {
  /// The [ClassElement] this annotation is associated with.
  final dart.ClassElement classElement;

  @override
  final contentChilds = <ContentChild>[];

  @override
  final contentChildren = <ContentChild>[];

  /// Which fields have been marked `@ContentChild`, and the range of the type
  /// argument. The element model contains the rest. This should be stored in the
  /// summary, so that at link time we can report errors discovered in the model
  /// against the range we saw it the AST.
  @override
  List<ContentChildField> contentChildrenFields;

  @override
  List<ContentChildField> contentChildFields;

  AngularAnnotatedClass(this.classElement,
      {List<InputElement> inputs,
      List<OutputElement> outputs,
      this.contentChildFields,
      this.contentChildrenFields})
      : super(inputs: inputs, outputs: outputs);

  @override
  int get hashCode => classElement.hashCode;

  // See [contentChildrenFields]. These are the linked versions.
  @override
  bool get isHtml => false;

  /// The source that contains this directive.
  @override
  Source get source => classElement.source;

  @override
  bool operator ==(Object other) =>
      other is AngularAnnotatedClass && other.classElement == classElement;
  @override
  String toString() => '$runtimeType(${classElement.displayName} '
      'inputs=$inputs '
      'outputs=$outputs '
      'attributes=$attributes)';
}

/// The base class for all Angular elements.
abstract class AngularElement {
  dart.CompilationUnitElement get compilationElement;

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
  dart.CompilationUnitElement get compilationElement => null;

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

/// An abstract model of an Angular top level construct.
///
/// This may be a functional directive, component, or normal directive...or even
/// an [AngularAnnotatedClass] which is a class that defines component/directive
/// behavior for the sake of being inherited.
abstract class AngularTopLevel {
  final attributes = <AngularElement>[];

  /// Its very hard to tell which directives are meant to be used with a *star.
  /// However, any directives which have a `TemplateRef` as a constructor
  /// parameter are almost certainly meant to be used with one. We use this for
  /// whatever validation we can, and autocomplete suggestions.
  bool looksLikeTemplate = false;
  final List<InputElement> inputs;

  final List<OutputElement> outputs;

  AngularTopLevel({
    this.inputs,
    this.outputs,
  });
  List<ContentChildField> get contentChildFields;

  List<ContentChild> get contentChildren;

  /// See [AngularAnnotatedClassMembers.contentChildrenFields]
  List<ContentChildField> get contentChildrenFields;

  /// See [AngularAnnotatedClassMembers.contentChildren]
  List<ContentChild> get contentChilds;
  bool get isHtml;

  Source get source;
}

class ArrayOfDirectiveReferencesStrategy implements DirectivesStrategy {
  final List<DirectiveReference> directiveReferences;

  ArrayOfDirectiveReferencesStrategy(this.directiveReferences);

  @override
  T resolve<T>(T Function(List<DirectiveReference>) arrayStrategyHandler,
          T Function(Null, Null) _) =>
      arrayStrategyHandler(directiveReferences);
}

/// The model of an Angular component.
class Component extends AbstractClassDirective {
  View view;
  @override
  final bool isHtml;

  /// List of <ng-content> selectors in this component's view
  final ngContents = <NgContent>[];

  Component(dart.ClassElement classElement,
      {AngularElement exportAs,
      List<InputElement> inputs,
      List<OutputElement> outputs,
      Selector selector,
      List<ElementNameSelector> elementTags,
      this.isHtml,
      List<NgContent> ngContents,
      List<Pipe> pipes,
      List<ContentChildField> contentChildFields,
      List<ContentChildField> contentChildrenFields})
      : super(classElement,
            exportAs: exportAs,
            inputs: inputs,
            outputs: outputs,
            selector: selector,
            elementTags: elementTags,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields) {
    this.ngContents.addAll(ngContents ?? []);
  }

  List<ExportedIdentifier> get exports => view?.exports ?? [];
}

// Represents both Element and HtmlElement, since the difference between them
// is SVG which we don't yet analyze. Also represent ElementRef which will soon
// be deprecated/removed.
class ContentChild {
  final ContentChildField field;
  final AbstractQueriedChildType query;

  /// Look up a symbol from the injector. We don't track the injector yet.
  final dart.DartType read;

  ContentChild(this.field, this.query, {this.read});
}

class ContentChildField {
  final String fieldName;
  final SourceRange nameRange;
  final SourceRange typeRange;

  ContentChildField(this.fieldName, {this.nameRange, this.typeRange});
}

/// An [AngularElement] representing a [dart.Element].
class DartElement extends AngularElementImpl {
  final dart.Element element;

  DartElement(dart.Element element)
      : element = element,
        super(element.name, element.nameOffset, element.nameLength,
            element.source);

  @override
  dart.CompilationUnitElement get compilationElement =>
      element.getAncestor((e) => e is dart.CompilationUnitElement);
}

/// The model of an Angular directive.
class Directive extends AbstractClassDirective {
  Directive(dart.ClassElement classElement,
      {AngularElement exportAs,
      List<InputElement> inputs,
      List<OutputElement> outputs,
      Selector selector,
      List<ElementNameSelector> elementTags,
      List<ContentChildField> contentChildFields,
      List<ContentChildField> contentChildrenFields})
      : super(classElement,
            exportAs: exportAs,
            inputs: inputs,
            outputs: outputs,
            selector: selector,
            elementTags: elementTags,
            contentChildFields: contentChildFields,
            contentChildrenFields: contentChildrenFields);

  @override
  bool get isHtml => false;
}

class DirectiveQueriedChildType extends AbstractQueriedChildType {
  final AbstractDirective directive;
  DirectiveQueriedChildType(this.directive);
  @override
  bool match(NodeInfo element, StandardAngular _, StandardHtml __,
          ErrorReporter ___) =>
      element is ElementInfo &&
      element.directives.any((boundDirective) => boundDirective == directive);
}

class DirectiveReference {
  String name;
  String prefix;
  SourceRange range;

  DirectiveReference(this.name, this.prefix, this.range);
}

abstract class DirectivesStrategy {
  // A low-level sort of visitor strategy.
  T resolve<T>(T Function(List<DirectiveReference>) arrayStrategyHandler,
      T Function(DartObject, SourceRange) constStrategyHandler);
}

class ElementQueriedChildType extends AbstractQueriedChildType {
  @override
  bool match(NodeInfo element, StandardAngular _, StandardHtml __,
          ErrorReporter ___) =>
      element is ElementInfo &&
      element.localName != 'template' &&
      !element.directives.any((boundDirective) =>
          boundDirective is Component && !boundDirective.isHtml);
}

class ExportedIdentifier {
  final String prefix;
  final String identifier;
  final SourceRange span;
  dart.Element element;

  ExportedIdentifier(this.identifier, this.span,
      {this.element, this.prefix: ''});
}

/// A functional directive is applied when the directive is linked, but does
/// nothing later in the program. Thus it cannot have inputs, outputs, etc. But
/// for the sake of clean code, those methods are implemented to return null,
/// empty list, etc.
class FunctionalDirective implements AbstractDirective {
  final dart.FunctionElement functionElement;
  @override
  final Selector selector;
  @override
  final List<ElementNameSelector> elementTags;

  /// @See [AbstractSelectable.looksLikeTemplate]
  @override
  bool looksLikeTemplate = false;

  FunctionalDirective(this.functionElement, this.selector, this.elementTags);

  @override
  List<AngularElement> get attributes => const [];
  @override
  List<ContentChildField> get contentChildFields => const [];
  @override
  List<ContentChild> get contentChildren => const [];
  @override
  List<ContentChildField> get contentChildrenFields => const [];
  @override
  List<ContentChild> get contentChilds => const [];
  @override
  AngularElement get exportAs => null;
  @override
  int get hashCode => functionElement.hashCode;
  @override
  List<InputElement> get inputs => const [];
  @override
  bool get isHtml => false;

  @override
  String get name => functionElement.name;

  @override
  List<OutputElement> get outputs => const [];

  /// The source that contains this directive.
  @override
  Source get source => functionElement.source;

  @override
  bool operator ==(Object other) =>
      other is FunctionalDirective && other.functionElement == functionElement;

  @override
  String toString() => 'FunctionalDirective(${functionElement.displayName} '
      'selector=$selector ';
}

/// An Angular template in an HTML file.
class HtmlTemplate extends Template {
  /// The [Source] of the template.
  final Source source;

  HtmlTemplate(View view, this.source) : super(view);
}

/// The model for an Angular input.
class InputElement extends AngularElementImpl {
  final dart.PropertyAccessorElement setter;

  final dart.DartType setterType;

  /// The [SourceRange] where [setter] is referenced in the input declaration.
  /// May be the same as this element offset/length in shorthand variants where
  /// names of a input and the setter are the same.
  final SourceRange setterRange;

  /// A given input can have an alternative name, or more 'conventional' name
  /// that differs from the name provided by dart:html source.
  /// For example: source -> 'className', but prefer 'class'.
  /// In this case, name = 'class' and originalName = 'originalName'.
  /// This should be null if there is no alternative name.
  final String originalName;

  /// Native inputs vulnerable to XSS (such as a.href and *.innerHTML) may have
  /// a security context. The secure type of that context should be assignable
  /// to this input, and if the security context does not allow sanitization
  /// then it will always throw otherwise and thus should be treated as an
  /// assignment error.
  final SecurityContext securityContext;

  InputElement(String name, int nameOffset, int nameLength, Source source,
      this.setter, this.setterRange, this.setterType,
      {this.originalName, this.securityContext})
      : super(name, nameOffset, nameLength, source);

  @override
  String toString() => 'InputElement($name, $nameOffset, $nameLength, $setter)';
}

class LetBoundQueriedChildType extends AbstractQueriedChildType {
  final String letBoundName;
  final dart.DartType containerType;
  LetBoundQueriedChildType(this.letBoundName, this.containerType);
  @override
  bool match(NodeInfo element, StandardAngular angular,
          StandardHtml standardHtml, ErrorReporter errorReporter) =>
      element is ElementInfo &&
      element.attributes.any((attribute) {
        if (attribute is TextAttribute && attribute.name == '#$letBoundName') {
          _validateMatch(
              element, attribute, angular, standardHtml, errorReporter);
          return true;
        }
        return false;
      });

  /// Validate against a matching [TextAttribute] on a matching [ElementInfo],
  /// for assignability to [containerType] errors.
  void _validateMatch(
      ElementInfo element,
      TextAttribute attr,
      StandardAngular angular,
      StandardHtml standardHtml,
      ErrorReporter errorReporter) {
    // For Html, the possible match types is plural. So use a list in all cases
    // instead of a single value for most and then have some exceptional code.
    final matchTypes = <dart.DartType>[];

    if (attr.value != "" && attr.value != null) {
      final possibleDirectives = new List<AbstractClassDirective>.from(
          element.directives.where((d) =>
              d.exportAs.name == attr.value &&
              d is AbstractClassDirective)); // No functional directives
      if (possibleDirectives.isEmpty || possibleDirectives.length > 1) {
        // Don't validate based on an invalid state (that's reported as such).
        return;
      }
      // TODO instantiate this type to bounds
      matchTypes.add(possibleDirectives.first.classElement.type);
    } else if (element.localName == 'template') {
      matchTypes.add(angular.templateRef.type);
    } else {
      final possibleComponents = new List<Component>.from(
          element.directives.where((d) => d is Component && !d.isHtml));
      if (possibleComponents.length > 1) {
        // Don't validate based on an invalid state (that's reported as such).
        return;
      }

      if (possibleComponents.isEmpty) {
        // TODO differentiate between SVG (Element) and HTML (HtmlElement)
        matchTypes
          ..add(angular.elementRef.type)
          ..add(standardHtml.elementClass.type)
          ..add(standardHtml.htmlElementClass.type);
      } else {
        // TODO instantiate this type to bounds
        matchTypes.add(possibleComponents.first.classElement.type);
      }
    }

    // Don't do isAssignable. Because we KNOW downcasting makes no sense here.
    if (!matchTypes.any(containerType.isSupertypeOf)) {
      errorReporter.reportErrorForOffset(
          AngularWarningCode.MATCHED_LET_BINDING_HAS_WRONG_TYPE,
          element.offset,
          element.length,
          [letBoundName, containerType, matchTypes]);
    }
  }
}

class NgContent {
  final int offset;
  final int length;

  /// NOTE: May contain Null. Null in this case means no selector (all content).
  final Selector selector;
  final int selectorOffset;
  final int selectorLength;

  NgContent(this.offset, this.length)
      : selector = null,
        selectorOffset = null,
        selectorLength = null;

  NgContent.withSelector(this.offset, this.length, this.selector,
      this.selectorOffset, this.selectorLength);

  bool get matchesAll => selector == null;
}

/// The model for an Angular output.
class OutputElement extends AngularElementImpl {
  final dart.PropertyAccessorElement getter;

  final dart.DartType eventType;

  /// The [SourceRange] where [getter] is referenced in the input declaration.
  /// May be the same as this element offset/length in shorthand variants where
  /// names of a input and the getter are the same.
  final SourceRange getterRange;

  OutputElement(String name, int nameOffset, int nameLength, Source source,
      this.getter, this.getterRange, this.eventType)
      : super(name, nameOffset, nameLength, source);

  @override
  String toString() =>
      'OutputElement($name, $nameOffset, $nameLength, $getter)';
}

class Pipe {
  final String pipeName;
  final int pipeNameOffset;
  final dart.ClassElement classElement;
  final bool isPure;

  dart.DartType requiredArgumentType;
  dart.DartType transformReturnType;
  List<dart.DartType> optionalArgumentTypes = <dart.DartType>[];

  Pipe(this.pipeName, this.pipeNameOffset, this.classElement,
      {this.isPure: true});
}

class PipeReference {
  final String prefix;
  final String identifier;
  final SourceRange span;

  PipeReference(this.identifier, this.span, {this.prefix: ''});
}

/// A pair of an [SourceRange] and the referenced [AngularElement].
class ResolvedRange {
  /// The [SourceRange] where [element] is referenced.
  final SourceRange range;

  /// The [AngularElement] referenced at [range].
  final AngularElement element;

  ResolvedRange(this.range, this.element);

  @override
  String toString() => '$range=[$element, '
      'nameOffset=${element.nameOffset}, '
      'nameLength=${element.nameLength}, '
      'source=${element.source}]';
}

/// An Angular template.
/// Templates can be embedded into Dart.
class Template {
  /// The [View] that describes the template.
  final View view;

  /// The [ResolvedRange]s of the template.
  final ranges = <ResolvedRange>[];

  /// The [ElementInfo] that begins the AST of the resolved template
  ElementInfo _ast;

  /// The errors that are ignored in this template
  final ignoredErrors = new HashSet<String>();

  Template(this.view);

  ElementInfo get ast => _ast;

  set ast(ElementInfo ast) {
    if (_ast != null) {
      throw new StateError("AST is already set, shouldn't be set again");
    }

    _ast = ast;
  }

  /// Records that the given [element] is referenced at the given [range].
  void addRange(SourceRange range, AngularElement element) {
    assert(range != null);
    assert(range.offset != null);
    assert(range.offset >= 0);
    ranges.add(new ResolvedRange(range, element));
  }

  @override
  String toString() => 'Template(ranges=$ranges)';
}

class TemplateRefQueriedChildType extends AbstractQueriedChildType {
  @override
  bool match(NodeInfo element, StandardAngular _, StandardHtml __,
          ErrorReporter ___) =>
      element is ElementInfo && element.localName == 'template';
}

class UseConstValueStrategy implements DirectivesStrategy {
  final dart.ClassElement annotatedObject;
  final StandardAngular standardAngular;
  final SourceRange sourceRange;

  UseConstValueStrategy(
      this.annotatedObject, this.standardAngular, this.sourceRange) {
    assert(standardAngular != null);
  }

  @override
  T resolve<T>(T Function(Null) _,
          T Function(DartObject, SourceRange) constStrategyHandler) =>
      constStrategyHandler(
          annotatedObject.metadata
              .where((m) => _isComponent(m.element?.enclosingElement))
              .map((m) => _getDirectives(m.computeConstantValue()))
              // TODO(mfairhurst): report error for double definition
              .firstWhere((directives) => !(directives?.isNull ?? true),
                  orElse: () => null),
          sourceRange);

  /// Traverse the inheritance hierarchy in the constant value, looking for the
  /// 'directives' field at the highest level it occurs.
  DartObject _getDirectives(DartObject value) {
    do {
      final directives = value.getField('directives');
      if (directives != null) {
        return directives;
      }
      // ignore: parameter_assignments
      value = value.getField('(super)');
    } while (value != null);

    return null;
  }

  /// Check if an element is a Component
  bool _isComponent(dart.Element element) =>
      element is dart.ClassElement &&
      element.type.isSubtypeOf(standardAngular.component.type);
}

/// The model of an Angular view.
class View {
  /// The [ClassElement] this view is associated with.
  final dart.ClassElement classElement;

  final Component component;
  final List<AbstractDirective> directives;
  final List<Pipe> pipes;
  final DirectivesStrategy directivesStrategy;
  final List<PipeReference> pipeReferences;
  final String templateText;
  final int templateOffset;
  final Source templateUriSource;
  final SourceRange templateUrlRange;
  final dart.Annotation annotation;

  final List<ExportedIdentifier> exports;

  Map<String, List<AbstractDirective>> _elementTagsInfo;

  /// The [Template] of this view, `null` until built.
  Template template;

  View(this.classElement, this.component, this.directives, this.pipes,
      {this.templateText,
      this.templateOffset: 0,
      this.templateUriSource,
      this.templateUrlRange,
      this.annotation,
      this.directivesStrategy,
      this.exports,
      this.pipeReferences}) {
    // stability/error-recovery: @Component can be missing
    component?.view = this;
  }

  Map<String, List<AbstractDirective>> get elementTagsInfo {
    if (_elementTagsInfo == null) {
      _elementTagsInfo = <String, List<AbstractDirective>>{};
      for (final directive in directives) {
        if (directive.elementTags != null && directive.elementTags.isNotEmpty) {
          for (final elementTag in directive.elementTags) {
            final tagName = elementTag.toString();
            _elementTagsInfo.putIfAbsent(tagName, () => <AbstractDirective>[]);
            _elementTagsInfo[tagName].add(directive);
          }
        }
      }
    }
    return _elementTagsInfo;
  }

  int get end => templateOffset + templateText.length;

  /// The source that contains this view.
  Source get source => classElement.source;

  /// The source that contains this template, [source] or [templateUriSource].
  Source get templateSource => templateUriSource ?? source;

  @override
  String toString() => 'View('
      'classElement=$classElement, '
      'component=$component, '
      'directives=$directives)';
}
