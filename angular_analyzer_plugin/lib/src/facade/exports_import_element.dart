import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/wrapped.dart';
import 'package:angular_analyzer_plugin/src/facade/exports_library_element.dart';
import 'package:angular_analyzer_plugin/src/model.dart';

/// A facade for a [ImportElement] which consists only of a component's
/// exports
class ExportsImportElementFacade extends WrappedImportElement {
  final Component _component;
  LibraryElement libraryFacade;

  ExportsImportElementFacade(ImportElement wrappedImport, this._component,
      {this.libraryFacade})
      : super(wrappedImport);

  @override
  LibraryElement get enclosingElement => libraryFacade;

  @override
  bool get hasJS => false;

  @override
  LibraryElement get importedLibrary => wrappedImport.importedLibrary == null
      ? null
      : new ExportsLibraryFacade(wrappedImport.importedLibrary, _component,
          prefix: prefix?.name);

  @override
  bool get isJS => false;

  @override
  LibraryElement get library => libraryFacade;
}
