import 'package:analyzer/dart/ast/ast.dart' hide Directive;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisContext;
import 'package:analyzer/src/generated/java_engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/model.dart';

/// A facade for a [CompilationUnitElement] which consists only of a component's
/// exports, and the component itself.
class ExportsLimitedCompilationUnitFacade implements CompilationUnitElement {
  final Component _component;
  final CompilationUnitElement _wrappedUnit;
  LibraryElement libraryFacade;

  ExportsLimitedCompilationUnitFacade(this._wrappedUnit, this._component,
      {this.libraryFacade});

  @override
  List<PropertyAccessorElement> get accessors =>
      new List<PropertyAccessorElement>.from(_component.exports
          .where(_fromThisUnit)
          .map((export) => export.element)
          .where((element) => element is PropertyAccessorElement));

  @override
  AnalysisContext get context => _wrappedUnit.context;

  @override
  String get displayName => _wrappedUnit.displayName;

  @override
  String get documentationComment => _wrappedUnit.documentationComment;

  @override
  LibraryElement get enclosingElement => libraryFacade;

  @override
  List<ClassElement> get enums => new List<ClassElement>.from(_component.exports
      .where(_fromThisUnit)
      .map((export) => export.element)
      .where((element) => element is ClassElement && element.isEnum));

  @override
  List<FunctionElement> get functions =>
      new List<FunctionElement>.from(_component.exports
          .where(_fromThisUnit)
          .map((export) => export.element)
          .where((element) => element is FunctionElement));

  @override
  List<FunctionTypeAliasElement> get functionTypeAliases => [];

  @override
  bool get hasAlwaysThrows => _wrappedUnit.hasAlwaysThrows;

  @override
  bool get hasDeprecated => _wrappedUnit.hasDeprecated;

  @override
  bool get hasFactory => _wrappedUnit.hasFactory;

  @override
  bool get hasIsTest => _wrappedUnit.hasIsTest;

  @override
  bool get hasIsTestGroup => _wrappedUnit.hasIsTestGroup;

  @override
  bool get hasJS => false;

  @override
  bool get hasLoadLibraryFunction => _wrappedUnit.hasLoadLibraryFunction;

  @override
  bool get hasOverride => _wrappedUnit.hasOverride;

  @override
  bool get hasProtected => _wrappedUnit.hasProtected;

  @override
  bool get hasRequired => _wrappedUnit.hasRequired;

  @override
  bool get hasVisibleForTesting => _wrappedUnit.hasVisibleForTesting;

  @override
  int get id => _wrappedUnit.id;

  @override
  bool get isAlwaysThrows => hasAlwaysThrows;

  @override
  bool get isDeprecated => hasDeprecated;

  @override
  bool get isFactory => hasFactory;

  @override
  bool get isJS => false;

  @override
  bool get isOverride => hasOverride;

  @override
  bool get isPrivate => _wrappedUnit.isPrivate;

  @override
  bool get isProtected => hasProtected;

  @override
  bool get isPublic => _wrappedUnit.isPublic;

  @override
  bool get isRequired => hasRequired;

  @override
  bool get isSynthetic => _wrappedUnit.isSynthetic;

  @override
  bool get isVisibleForTesting => hasVisibleForTesting;

  @override
  ElementKind get kind => _wrappedUnit.kind;

  @override
  LibraryElement get library => libraryFacade;

  @override
  Source get librarySource => _wrappedUnit.librarySource;

  @override
  LineInfo get lineInfo => _wrappedUnit.lineInfo;

  @override
  ElementLocation get location => _wrappedUnit.location;

  @override
  List<ElementAnnotation> get metadata => _wrappedUnit.metadata;

  @override
  String get name => _wrappedUnit.name;

  @override
  int get nameLength =>
      _wrappedUnit.nameLength; // ignore: deprecated_member_use

  @override
  int get nameOffset => _wrappedUnit.nameOffset;

  @override
  Source get source => _wrappedUnit.source;

  @override
  List<TopLevelVariableElement> get topLevelVariables => [];

  @override
  List<ClassElement> get types => new List<ClassElement>.from(_component.exports
      .where(_fromThisUnit)
      .map((export) => export.element)
      .where((element) => element is ClassElement))
    ..add(_component.classElement);

  @override
  CompilationUnit get unit => _wrappedUnit.unit;

  @override
  String get uri => _wrappedUnit.uri;

  @override
  int get uriEnd => _wrappedUnit.uriEnd;

  @override
  int get uriOffset => _wrappedUnit.uriOffset;

  @override
  T accept<T>(ElementVisitor<T> visitor) => _wrappedUnit.accept(visitor);

  @override
  String computeDocumentationComment() =>
      _wrappedUnit.computeDocumentationComment();

  @override
  CompilationUnit computeNode() => _wrappedUnit.computeNode();

  @override
  E getAncestor<E extends Element>(Predicate<Element> predicate) =>
      _wrappedUnit.getAncestor(predicate); // currently never exported

  @override
  ClassElement getEnum(String name) =>
      enums.firstWhere((_enum) => _enum.name == name, orElse: () => null);

  @override
  String getExtendedDisplayName(String shortName) => _wrappedUnit
      .getExtendedDisplayName(shortName); // currently never exported

  @override
  ClassElement getType(String className) =>
      types.firstWhere((type) => type.name == name, orElse: () => null);

  @override
  bool isAccessibleIn(LibraryElement library) =>
      _wrappedUnit.isAccessibleIn(library);

  @override
  void visitChildren(ElementVisitor visitor) =>
      _wrappedUnit.visitChildren(visitor);

  // CompilationUnitFacade's are not used for imports, which have prefixes
  bool _fromThisUnit(ExportedIdentifier export) => export.prefix == '';
}
