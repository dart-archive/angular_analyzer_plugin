import 'package:analyzer/dart/ast/ast.dart' hide Directive;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisContext;
import 'package:analyzer/src/generated/java_engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/facade/exports_compilation_unit_element.dart';
import 'package:angular_analyzer_plugin/src/facade/exports_import_element.dart';
import 'package:angular_analyzer_plugin/src/model.dart';

/// A facade for a [Library] which consists only of a components' exports, and
/// the component itself.
class ExportsLibraryFacade extends ElementImpl implements LibraryElement {
  final LibraryElement _wrappedLib;
  final ExportsLimitedCompilationUnitFacade _definingUnit;
  final Component _owningComponent;

  factory ExportsLibraryFacade(
      LibraryElement wrappedLib, Component owningComponent,
      {String prefix}) {
    if (prefix != null) {
      return new _PrefixedExportsLibraryFacade(
          wrappedLib, owningComponent, prefix);
    }
    return new ExportsLibraryFacade._(wrappedLib, owningComponent);
  }

  ExportsLibraryFacade._(this._wrappedLib, this._owningComponent)
      : _definingUnit = new ExportsLimitedCompilationUnitFacade(
            _wrappedLib.definingCompilationUnit, _owningComponent),
        super(_wrappedLib.name, _wrappedLib.nameOffset) {
    _definingUnit.libraryFacade = this;
  }

  @override
  AnalysisContext get context => _wrappedLib.context;

  @override
  String get displayName => _wrappedLib.displayName;

  @override
  String get documentationComment => _wrappedLib.documentationComment;

  @override
  Element get enclosingElement => _wrappedLib.enclosingElement;

  @override
  int get id => _wrappedLib.id;

  @override
  bool get isDeprecated => _wrappedLib.isDeprecated;

  @override
  bool get isFactory => _wrappedLib.isFactory;

  @override
  bool get isJS => false;

  @override
  bool get isOverride => _wrappedLib.isOverride;

  @override
  bool get isPrivate => _wrappedLib.isPrivate;

  @override
  bool get isProtected => _wrappedLib.isProtected;

  @override
  bool get isPublic => _wrappedLib.isPublic;

  @override
  bool get isRequired => _wrappedLib.isRequired;

  @override
  bool get isSynthetic => _wrappedLib.isSynthetic;

  @override
  LibraryElement get library => this;

  @override
  ElementLocation get location => _wrappedLib.location;

  @override
  List<ElementAnnotation> get metadata => _wrappedLib.metadata;

  @override
  String get name => _wrappedLib.name;

  @override
  int get nameLength => _wrappedLib.nameLength;

  @override
  int get nameOffset => _wrappedLib.nameOffset;

  @override
  Source get source => _wrappedLib.source;

  @override
  CompilationUnit get unit => _wrappedLib.unit;

  @override
  String computeDocumentationComment() => _wrappedLib
      .computeDocumentationComment(); // ignore: deprecated_member_use

  @override
  AstNode computeNode() => _wrappedLib.computeNode();

  @override
  Element/*=E*/ getAncestor/*<E extends Element >*/(
          Predicate<Element> predicate) =>
      _wrappedLib.getAncestor(predicate);

  @override
  String getExtendedDisplayName(String shortName) =>
      _wrappedLib.getExtendedDisplayName(shortName);

  @override
  bool isAccessibleIn(LibraryElement library) =>
      _wrappedLib.isAccessibleIn(library);

  @override
  void visitChildren(ElementVisitor visitor) =>
      _wrappedLib.visitChildren(visitor);

  @override
  ElementKind get kind => _wrappedLib.kind;

  @override
  /*=T*/ accept/*<T>*/(ElementVisitor<dynamic/*=T*/ > visitor) =>
      _wrappedLib.accept(visitor);

  @override
  CompilationUnitElement get definingCompilationUnit => _definingUnit;

  @override
  FunctionElement get entryPoint => _wrappedLib.entryPoint;

  @override
  List<LibraryElement> get exportedLibraries => _wrappedLib.exportedLibraries;

  @override
  Namespace get exportNamespace => _wrappedLib.exportNamespace;

  @override
  List<ExportElement> get exports => _wrappedLib.exports;

  @override
  bool get hasExtUri => _wrappedLib.hasExtUri;

  @override
  bool get hasLoadLibraryFunction => _wrappedLib.hasLoadLibraryFunction;

  @override
  String get identifier => _wrappedLib.identifier;

  @override
  List<LibraryElement> get importedLibraries => _wrappedLib.importedLibraries;

  @override
  List<ImportElement> get imports => _wrappedLib.imports
      .map((import) => new ExportsImportElementFacade(import, _owningComponent,
          libraryFacade: this))
      .toList();

  @override
  bool get isBrowserApplication => _wrappedLib.isBrowserApplication;

  @override
  bool get isDartAsync => false;

  @override
  bool get isDartCore => false;

  @override
  bool get isInSdk => false;

  @override
  List<LibraryElement> get libraryCycle => _wrappedLib.libraryCycle
      .map((lib) => new ExportsLibraryFacade(lib, _owningComponent))
      .toList();

  @override
  FunctionElement get loadLibraryFunction => _wrappedLib.loadLibraryFunction;

  @override
  List<CompilationUnitElement> get parts => _wrappedLib.parts
      .map((part) => new ExportsLimitedCompilationUnitFacade(
          part, _owningComponent,
          libraryFacade: this))
      .toList();

  @override
  List<PrefixElement> get prefixes => _wrappedLib.prefixes
      .where((prefix) =>
          _owningComponent?.view?.exports
              ?.any((export) => export.prefix == prefix.name) ??
          false)
      .toList();

  @override
  Namespace get publicNamespace => _wrappedLib.publicNamespace;

  @override
  List<CompilationUnitElement> get units => _wrappedLib.units
      .map((unit) => new ExportsLimitedCompilationUnitFacade(
          unit, _owningComponent,
          libraryFacade: this))
      .toList();

  // TODO should this be limited to the component exports with prefixes?
  @override
  List<ImportElement> getImportsWithPrefix(PrefixElement prefix) => _wrappedLib
      .getImportsWithPrefix(prefix)
      .map((lib) => new ExportsImportElementFacade(lib, _owningComponent,
          libraryFacade: this))
      .toList();

  // TODO Limit this to the component exports
  @override
  ClassElement getType(String className) => _wrappedLib.getType(className);
}

class _PrefixedExportsLibraryFacade extends ExportsLibraryFacade {
  final String _prefix;
  _PrefixedExportsLibraryFacade(
      LibraryElement wrappedLib, Component owningComponent, this._prefix)
      : super._(wrappedLib, owningComponent);

  @override
  Namespace get exportNamespace {
    final map = <String, Element>{};
    _owningComponent?.view?.exports
        ?.where((export) => export.prefix == _prefix)
        ?.forEach((export) => map[export.identifier] = export.element);
    return new Namespace(map);
  }
}
