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
  String get uri => _wrappedUnit.uri;

  @override
  int get uriEnd => _wrappedUnit.uriEnd;

  @override
  int get uriOffset => _wrappedUnit.uriOffset;

  @override
  Source get librarySource => _wrappedUnit.librarySource;

  @override
  AnalysisContext get context => _wrappedUnit.context;

  @override
  String get displayName => _wrappedUnit.displayName;

  @override
  String get documentationComment => _wrappedUnit.documentationComment;

  @override
  LibraryElement get enclosingElement => libraryFacade;

  @override
  int get id => _wrappedUnit.id;

  @override
  bool get isDeprecated => _wrappedUnit.isDeprecated;

  @override
  bool get isFactory => _wrappedUnit.isFactory;

  @override
  bool get isJS => false;

  @override
  bool get isOverride => _wrappedUnit.isOverride;

  @override
  bool get isPrivate => _wrappedUnit.isPrivate;

  @override
  bool get isProtected => _wrappedUnit.isProtected;

  @override
  bool get isPublic => _wrappedUnit.isPublic;

  @override
  bool get isRequired => _wrappedUnit.isRequired;

  @override
  bool get isSynthetic => _wrappedUnit.isSynthetic;

  @override
  LibraryElement get library => libraryFacade;

  @override
  ElementLocation get location => _wrappedUnit.location;

  @override
  List<ElementAnnotation> get metadata => _wrappedUnit.metadata;

  @override
  String get name => _wrappedUnit.name;

  @override
  int get nameLength => _wrappedUnit.nameLength;

  @override
  int get nameOffset => _wrappedUnit.nameOffset;

  @override
  Source get source => _wrappedUnit.source;

  @override
  CompilationUnit get unit => _wrappedUnit.unit;

  @override
  String computeDocumentationComment() => _wrappedUnit
      .computeDocumentationComment(); // ignore: deprecated_member_use

  @override
  CompilationUnit computeNode() => _wrappedUnit.computeNode();

  @override
  Element/*=E*/ getAncestor/*<E extends Element >*/(
          Predicate<Element> predicate) =>
      _wrappedUnit.getAncestor(predicate);

  @override
  String getExtendedDisplayName(String shortName) =>
      _wrappedUnit.getExtendedDisplayName(shortName);

  @override
  bool isAccessibleIn(LibraryElement library) =>
      _wrappedUnit.isAccessibleIn(library);

  @override
  void visitChildren(ElementVisitor visitor) =>
      _wrappedUnit.visitChildren(visitor);

  @override
  ElementKind get kind => _wrappedUnit.kind;

  @override
  /*=T*/ accept/*<T>*/(ElementVisitor<dynamic/*=T*/ > visitor) =>
      _wrappedUnit.accept(visitor);

  @override
  bool get hasLoadLibraryFunction => _wrappedUnit.hasLoadLibraryFunction;

  @override
  List<PropertyAccessorElement> get accessors =>
      new List<PropertyAccessorElement>.from((_component?.view?.exports ?? [])
          .where(_fromThisUnit)
          .map((export) => export.element)
          .where((element) => element is PropertyAccessorElement));

  @override
  List<ClassElement> get enums =>
      new List<ClassElement>.from((_component?.view?.exports ?? [])
          .where(_fromThisUnit)
          .map((export) => export.element)
          .where((element) => element is ClassElement));

  @override
  List<FunctionElement> get functions =>
      new List<FunctionElement>.from((_component?.view?.exports ?? [])
          .where(_fromThisUnit)
          .map((export) => export.element)
          .where((element) => element is FunctionElement));

  @override
  List<FunctionTypeAliasElement> get functionTypeAliases =>
      []; // currently never exported

  @override
  LineInfo get lineInfo => _wrappedUnit.lineInfo;

  @override
  List<TopLevelVariableElement> get topLevelVariables =>
      []; // currently never exported

  @override
  List<ClassElement> get types =>
      new List<ClassElement>.from((_component?.view?.exports ?? [])
          .where(_fromThisUnit)
          .map((export) => export.element)
          .where((element) => element is ClassElement))
        ..add(_component.classElement);

  @override
  Element getElementAt(int offset) => _wrappedUnit.getElementAt(offset);

  @override
  ClassElement getEnum(String name) =>
      enums.firstWhere((_enum) => _enum.name == name, orElse: () => null);

  @override
  ClassElement getType(String className) =>
      types.firstWhere((type) => type.name == name, orElse: () => null);

  // CompilationUnitFacade's are not used for imports, which have prefixes
  bool _fromThisUnit(ExportedIdentifier export) => export.prefix == '';
}
