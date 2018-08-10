import 'package:analyzer/dart/ast/ast.dart' hide Directive;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/element.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisContext;
import 'package:analyzer/src/generated/java_engine.dart';
import 'package:analyzer/src/generated/resolver.dart';
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
  CompilationUnitElement get definingCompilationUnit => _definingUnit;

  @override
  String get displayName => _wrappedLib.displayName;

  @override
  String get documentationComment => _wrappedLib.documentationComment;

  @override
  Element get enclosingElement => _wrappedLib.enclosingElement;

  @override
  FunctionElement get entryPoint => _wrappedLib.entryPoint;

  @override
  List<LibraryElement> get exportedLibraries => _wrappedLib.exportedLibraries;

  @override
  Namespace get exportNamespace => _wrappedLib.exportNamespace;

  @override
  List<ExportElement> get exports => _wrappedLib.exports;

  @override
  bool get hasAlwaysThrows => _wrappedLib.hasAlwaysThrows;

  @override
  bool get hasDeprecated => _wrappedLib.hasDeprecated;

  @override
  bool get hasExtUri => _wrappedLib.hasExtUri;

  @override
  bool get hasFactory => _wrappedLib.hasFactory;

  @override
  bool get hasJS => false;

  @override
  bool get hasLoadLibraryFunction => _wrappedLib.hasLoadLibraryFunction;

  @override
  bool get hasOverride => _wrappedLib.hasOverride;

  @override
  bool get hasProtected => _wrappedLib.hasProtected;

  @override
  bool get hasRequired => _wrappedLib.hasRequired;

  @override
  bool get hasVisibleForTesting => _wrappedLib.hasVisibleForTesting;

  @override
  int get id => _wrappedLib.id;

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
  bool get isAlwaysThrows => hasAlwaysThrows;

  @override
  bool get isBrowserApplication => _wrappedLib.isBrowserApplication;

  @override
  bool get isDartAsync => false;

  @override
  bool get isDartCore => false;

  @override
  bool get isDeprecated => hasDeprecated;

  @override
  bool get isFactory => hasFactory;

  @override
  bool get isInSdk => false;

  @override
  bool get isJS => false;

  @override
  bool get isOverride => hasOverride;

  @override
  bool get isPrivate => _wrappedLib.isPrivate; // ignore: deprecated_member_use

  @override
  bool get isProtected => hasProtected;

  @override
  bool get isPublic => _wrappedLib.isPublic;

  @override
  bool get isRequired => hasRequired;

  @override
  bool get isSynthetic => _wrappedLib.isSynthetic;

  @override
  bool get isVisibleForTesting => hasVisibleForTesting;

  @override
  ElementKind get kind => _wrappedLib.kind;

  @override
  LibraryElement get library => this;

  @override
  List<LibraryElement> get libraryCycle => _wrappedLib.libraryCycle
      .map((lib) => new ExportsLibraryFacade(lib, _owningComponent))
      .toList();

  @override
  FunctionElement get loadLibraryFunction => _wrappedLib.loadLibraryFunction;

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
  List<CompilationUnitElement> get parts => _wrappedLib.parts
      .map((part) => new ExportsLimitedCompilationUnitFacade(
          part, _owningComponent,
          libraryFacade: this))
      .toList();

  @override
  List<PrefixElement> get prefixes => _wrappedLib.prefixes
      .where((prefix) => _owningComponent.exports
          .any((export) => export.prefix == prefix.name))
      .toList();

  @override
  Namespace get publicNamespace => _wrappedLib.publicNamespace;

  @override
  Source get source => _wrappedLib.source;

  @override
  CompilationUnit get unit => _wrappedLib.unit;

  @override
  List<CompilationUnitElement> get units => _wrappedLib.units
      .map((unit) => new ExportsLimitedCompilationUnitFacade(
          unit, _owningComponent,
          libraryFacade: this))
      .toList();

  @override
  T accept<T>(ElementVisitor<T> visitor) => _wrappedLib.accept(visitor);

  @override
  String computeDocumentationComment() =>
      _wrappedLib.computeDocumentationComment();

  @override
  AstNode computeNode() => _wrappedLib.computeNode();

  @override
  E getAncestor<E extends Element>(Predicate<Element> predicate) =>
      _wrappedLib.getAncestor(predicate);

  @override
  String getExtendedDisplayName(String shortName) =>
      _wrappedLib.getExtendedDisplayName(shortName);

  @override
  List<ImportElement> getImportsWithPrefix(PrefixElement prefix) => _wrappedLib
      .getImportsWithPrefix(prefix)
      .map((lib) => new ExportsImportElementFacade(lib, _owningComponent,
          libraryFacade: this))
      .toList();

  @override
  ClassElement getType(String className) => _wrappedLib.getType(className);

  // TODO should this be limited to the component exports with prefixes?
  @override
  bool isAccessibleIn(LibraryElement library) =>
      _wrappedLib.isAccessibleIn(library);

  // TODO Limit this to the component exports
  @override
  void visitChildren(ElementVisitor visitor) =>
      _wrappedLib.visitChildren(visitor);
}

class _PrefixedExportsLibraryFacade extends ExportsLibraryFacade {
  final String _prefix;
  _PrefixedExportsLibraryFacade(
      LibraryElement wrappedLib, Component owningComponent, this._prefix)
      : super._(wrappedLib, owningComponent);

  @override
  Namespace get exportNamespace {
    final map = <String, Element>{};
    _owningComponent.exports
        .where((export) => export.prefix == _prefix)
        .forEach((export) => map[export.identifier] = export.element);
    return new Namespace(map);
  }
}
