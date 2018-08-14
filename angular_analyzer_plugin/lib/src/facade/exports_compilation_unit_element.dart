import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/src/dart/element/wrapped.dart';
import 'package:angular_analyzer_plugin/src/model.dart';

/// A facade for a [CompilationUnitElement] which consists only of a component's
/// exports, and the component itself.
class ExportsLimitedCompilationUnitFacade
    extends WrappedCompilationUnitElement {
  final Component _component;
  LibraryElement libraryFacade;

  ExportsLimitedCompilationUnitFacade(
      CompilationUnitElement wrappedUnit, this._component,
      {this.libraryFacade})
      : super(wrappedUnit);

  @override
  List<PropertyAccessorElement> get accessors =>
      new List<PropertyAccessorElement>.from(_component.exports
          .where(_fromThisUnit)
          .map((export) => export.element)
          .where((element) => element is PropertyAccessorElement));

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
  bool get hasJS => false;

  @override
  bool get isJS => false;

  @override
  LibraryElement get library => libraryFacade;

  @override
  List<TopLevelVariableElement> get topLevelVariables => [];

  @override
  List<ClassElement> get types => new List<ClassElement>.from(_component.exports
      .where(_fromThisUnit)
      .map((export) => export.element)
      .where((element) => element is ClassElement))
    ..add(_component.classElement);

  @override
  ClassElement getEnum(String name) =>
      enums.firstWhere((_enum) => _enum.name == name, orElse: () => null);

  @override
  ClassElement getType(String className) =>
      types.firstWhere((type) => type.name == name, orElse: () => null);

  // CompilationUnitFacade's are not used for imports, which have prefixes
  bool _fromThisUnit(ExportedIdentifier export) => export.prefix == '';
}
