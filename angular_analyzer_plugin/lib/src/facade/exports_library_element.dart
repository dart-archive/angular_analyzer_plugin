import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/wrapped.dart';
import 'package:analyzer/src/generated/resolver.dart';
import 'package:angular_analyzer_plugin/src/facade/exports_compilation_unit_element.dart';
import 'package:angular_analyzer_plugin/src/facade/exports_import_element.dart';
import 'package:angular_analyzer_plugin/src/model.dart';

/// A facade for a [Library] which consists only of a components' exports, and
/// the component itself.
class ExportsLibraryFacade extends WrappedLibraryElement {
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

  ExportsLibraryFacade._(LibraryElement wrappedLib, this._owningComponent)
      : _definingUnit = new ExportsLimitedCompilationUnitFacade(
            wrappedLib.definingCompilationUnit, _owningComponent),
        super(wrappedLib) {
    _definingUnit.libraryFacade = this;
  }

  @override
  CompilationUnitElement get definingCompilationUnit => _definingUnit;

  @override
  bool get hasJS => false;

  @override
  List<ImportElement> get imports => wrappedLib.imports
      .map((import) => new ExportsImportElementFacade(import, _owningComponent,
          libraryFacade: this))
      .toList();

  @override
  bool get isDartAsync => false;

  @override
  bool get isDartCore => false;

  @override
  bool get isInSdk => false;

  @override
  bool get isJS => false;

  @override
  LibraryElement get library => this;

  @override
  List<LibraryElement> get libraryCycle => wrappedLib.libraryCycle
      .map((lib) => new ExportsLibraryFacade(lib, _owningComponent))
      .toList();

  @override
  List<CompilationUnitElement> get parts => wrappedLib.parts
      .map((part) => new ExportsLimitedCompilationUnitFacade(
          part, _owningComponent,
          libraryFacade: this))
      .toList();

  @override
  List<PrefixElement> get prefixes => wrappedLib.prefixes
      .where((prefix) => _owningComponent.exports
          .any((export) => export.prefix == prefix.name))
      .toList();

  @override
  List<CompilationUnitElement> get units => wrappedLib.units
      .map((unit) => new ExportsLimitedCompilationUnitFacade(
          unit, _owningComponent,
          libraryFacade: this))
      .toList();

  @override
  List<ImportElement> getImportsWithPrefix(PrefixElement prefix) => wrappedLib
      .getImportsWithPrefix(prefix)
      .map((lib) => new ExportsImportElementFacade(lib, _owningComponent,
          libraryFacade: this))
      .toList();

  @override
  ClassElement getType(String className) => wrappedLib.getType(className);
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
