import 'package:analyzer/dart/ast/ast.dart' hide Directive;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/generated/engine.dart' show AnalysisContext;
import 'package:analyzer/src/generated/java_engine.dart';
import 'package:analyzer/src/generated/source.dart';
import 'package:angular_analyzer_plugin/src/facade/exports_library_element.dart';
import 'package:angular_analyzer_plugin/src/model.dart';

/// A facade for a [ImportElement] which consists only of a component's
/// exports
class ExportsImportElementFacade implements ImportElement {
  final Component _component;
  final ImportElement _wrappedImport;
  LibraryElement libraryFacade;

  ExportsImportElementFacade(this._wrappedImport, this._component,
      {this.libraryFacade});

  @override
  String get uri => _wrappedImport.uri;

  @override
  int get uriEnd => _wrappedImport.uriEnd;

  @override
  int get uriOffset => _wrappedImport.uriOffset;

  @override
  Source get librarySource => _wrappedImport.librarySource;

  @override
  AnalysisContext get context => _wrappedImport.context;

  @override
  String get displayName => _wrappedImport.displayName;

  @override
  String get documentationComment => _wrappedImport.documentationComment;

  @override
  LibraryElement get enclosingElement => libraryFacade;

  @override
  int get id => _wrappedImport.id;

  @override
  bool get isDeprecated => _wrappedImport.isDeprecated;

  @override
  bool get isFactory => _wrappedImport.isFactory;

  @override
  bool get isJS => false;

  @override
  bool get isOverride => _wrappedImport.isOverride;

  @override
  bool get isPrivate => _wrappedImport.isPrivate;

  @override
  bool get isProtected => _wrappedImport.isProtected;

  @override
  bool get isPublic => _wrappedImport.isPublic;

  @override
  bool get isRequired => _wrappedImport.isRequired;

  @override
  bool get isSynthetic => _wrappedImport.isSynthetic;

  @override
  LibraryElement get library => libraryFacade;

  @override
  ElementLocation get location => _wrappedImport.location;

  @override
  List<ElementAnnotation> get metadata => _wrappedImport.metadata;

  @override
  String get name => _wrappedImport.name;

  @override
  int get nameLength => _wrappedImport.nameLength;

  @override
  int get nameOffset => _wrappedImport.nameOffset;

  @override
  Source get source => _wrappedImport.source;

  @override
  CompilationUnit get unit => _wrappedImport.unit;

  @override
  String computeDocumentationComment() => _wrappedImport
      .computeDocumentationComment(); // ignore: deprecated_member_use

  @override
  CompilationUnit computeNode() => _wrappedImport.computeNode();

  @override
  E getAncestor<E extends Element>(Predicate<Element> predicate) =>
      _wrappedImport.getAncestor(predicate);

  @override
  String getExtendedDisplayName(String shortName) =>
      _wrappedImport.getExtendedDisplayName(shortName);

  @override
  bool isAccessibleIn(LibraryElement library) =>
      _wrappedImport.isAccessibleIn(library);

  @override
  void visitChildren(ElementVisitor visitor) =>
      _wrappedImport.visitChildren(visitor);

  @override
  ElementKind get kind => _wrappedImport.kind;

  @override
  T accept<T>(ElementVisitor<T> visitor) => _wrappedImport.accept(visitor);

  @override
  List<NamespaceCombinator> get combinators => _wrappedImport.combinators;

  @override
  LibraryElement get importedLibrary => _wrappedImport.importedLibrary == null
      ? null
      : new ExportsLibraryFacade(_wrappedImport.importedLibrary, _component,
          prefix: prefix?.name);

  @override
  bool get isDeferred => _wrappedImport.isDeferred;

  @override
  PrefixElement get prefix => _wrappedImport.prefix;

  @override
  bool get isAlwaysThrows => _wrappedImport.isAlwaysThrows;

  @override
  bool get isVisibleForTesting => _wrappedImport.isVisibleForTesting;

  @override
  int get prefixOffset => _wrappedImport.prefixOffset;
}
