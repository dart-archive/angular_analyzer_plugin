import 'package:analyzer/dart/ast/ast.dart' hide Directive;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/resolver/scope.dart';
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
  List<NamespaceCombinator> get combinators => _wrappedImport.combinators;

  @override
  AnalysisContext get context => _wrappedImport.context;

  @override
  String get displayName => _wrappedImport.displayName;

  @override
  String get documentationComment => _wrappedImport.documentationComment;

  @override
  LibraryElement get enclosingElement => libraryFacade;

  @override
  bool get hasAlwaysThrows => _wrappedImport.hasAlwaysThrows;

  @override
  bool get hasDeprecated => _wrappedImport.hasDeprecated;

  @override
  bool get hasFactory => _wrappedImport.hasFactory;

  @override
  bool get hasIsTest => _wrappedImport.hasIsTest;

  @override
  bool get hasIsTestGroup => _wrappedImport.hasIsTestGroup;

  @override
  bool get hasJS => false;

  @override
  bool get hasOverride => _wrappedImport.hasOverride;

  @override
  bool get hasProtected => _wrappedImport.hasProtected;

  @override
  bool get hasRequired => _wrappedImport.hasRequired;

  @override
  bool get hasVisibleForTesting => _wrappedImport.hasVisibleForTesting;

  @override
  int get id => _wrappedImport.id;

  @override
  LibraryElement get importedLibrary => _wrappedImport.importedLibrary == null
      ? null
      : new ExportsLibraryFacade(_wrappedImport.importedLibrary, _component,
          prefix: prefix?.name);

  @override
  bool get isAlwaysThrows => hasAlwaysThrows;

  @override
  bool get isDeferred => _wrappedImport.isDeferred;

  @override
  bool get isDeprecated => hasDeprecated;

  @override
  bool get isFactory => hasFactory;

  @override
  bool get isJS => false;

  @override
  bool get isOverride => hasOverride;

  @override
  bool get isPrivate => _wrappedImport.isPrivate;

  @override
  bool get isProtected => hasProtected;

  @override
  bool get isPublic => _wrappedImport.isPublic;

  @override
  bool get isRequired => hasRequired;

  @override
  bool get isSynthetic => _wrappedImport.isSynthetic;

  @override
  bool get isVisibleForTesting => hasVisibleForTesting;

  @override
  ElementKind get kind => _wrappedImport.kind;

  @override
  LibraryElement get library => libraryFacade;

  @override
  Source get librarySource => _wrappedImport.librarySource;

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
  Namespace get namespace => _wrappedImport.namespace;

  @override
  PrefixElement get prefix =>
      _wrappedImport.prefix; // ignore: deprecated_member_use

  @override
  int get prefixOffset => _wrappedImport.prefixOffset;

  @override
  Source get source => _wrappedImport.source;

  @override
  CompilationUnit get unit => _wrappedImport.unit;

  @override
  String get uri => _wrappedImport.uri;

  @override
  int get uriEnd => _wrappedImport.uriEnd;

  @override
  int get uriOffset => _wrappedImport.uriOffset;

  @override
  T accept<T>(ElementVisitor<T> visitor) => _wrappedImport.accept(visitor);

  @override
  String computeDocumentationComment() =>
      _wrappedImport.computeDocumentationComment();

  @override
  AstNode computeNode() => _wrappedImport.computeNode();

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
}
